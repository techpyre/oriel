import Foundation
import EventKit
import MapKit
import AppKit
import Combine

@MainActor
public final class CalendarManager: ObservableObject {
    public static let shared = CalendarManager()

    @Published public var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published public var calendars: [EKCalendar] = []
    @Published public var todayEvents: [CalendarEventItem] = []
    @Published public var tomorrowEvents: [CalendarEventItem] = []
    @Published public var monthEventDays: Set<Int> = []
    @Published public var selectedDate: Date = Date()
    @Published public var nextRelevantEvent: CalendarEventItem?
    @Published public var dismissedEventIDs: Set<String> = []

    public var onEventQuickPeek: ((CalendarEventItem) -> Void)?
    public var onTimeToLeave: ((CalendarEventItem, Int) -> Void)?

    private let eventStore = EKEventStore()
    private var refreshTimer: Timer?
    private var hourlyTimer: Timer?
    private var eventStoreObserver: NSObjectProtocol?
    private var peekedEventSignatures: Set<String> = []
    private var ttlNotifiedSignatures: Set<String> = []

    private init() {
        refreshPermissionStatus()
        if authorizationStatus == .fullAccess || authorizationStatus == .authorized {
            reloadCalendarsAndEvents()
        }
        setupObservers()
    }

    public func refreshPermissionStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    public func requestAccess() {
        eventStore.requestFullAccessToEvents { [weak self] granted, _ in
            Task { @MainActor in
                self?.refreshPermissionStatus()
                if granted {
                    self?.reloadCalendarsAndEvents()
                }
            }
        }
    }

    private func setupObservers() {
        eventStoreObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reloadCalendarsAndEvents()
            }
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.reloadCalendarsAndEvents()
                self?.checkHourlyChime()
            }
        }
    }

    public func reloadCalendarsAndEvents() {
        refreshPermissionStatus()
        guard authorizationStatus == .fullAccess || authorizationStatus == .authorized else {
            calendars = []
            todayEvents = []
            tomorrowEvents = []
            nextRelevantEvent = nil
            return
        }

        let allCals = eventStore.calendars(for: .event)
        calendars = allCals.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        let excluded = Set(AppSettings.shared.excludedCalendars)
        let activeCals = allCals.filter { !excluded.contains($0.calendarIdentifier) }
        guard !activeCals.isEmpty else {
            todayEvents = []
            tomorrowEvents = []
            nextRelevantEvent = nil
            return
        }

        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        let endOfTomorrow = cal.date(byAdding: .day, value: 2, to: startOfToday) ?? now.addingTimeInterval(172800)

        let predicate = eventStore.predicateForEvents(withStart: startOfToday, end: endOfTomorrow, calendars: activeCals)
        let rawEvents = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }

        let mapped = rawEvents.map { ev -> CalendarEventItem in
            let hex = OrielColors.hexString(from: ev.calendar.color ?? .systemBlue)
            let meeting = Self.extractMeetingInfo(from: ev)
            return CalendarEventItem(
                id: ev.eventIdentifier ?? UUID().uuidString,
                title: ev.title ?? "Untitled Event",
                startDate: ev.startDate,
                endDate: ev.endDate,
                isAllDay: ev.isAllDay,
                calendarID: ev.calendar.calendarIdentifier,
                calendarTitle: ev.calendar.title,
                colorHex: hex,
                location: ev.location,
                meetingURL: meeting.url,
                meetingProvider: meeting.provider
            )
        }

        let startOfTomorrow = cal.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        todayEvents = mapped.filter {
            !dismissedEventIDs.contains($0.id) &&
            $0.startDate < startOfTomorrow &&
            $0.endDate > now
        }
        tomorrowEvents = mapped.filter {
            !dismissedEventIDs.contains($0.id) &&
            $0.startDate >= startOfTomorrow
        }

        // Month event indicator dots
        if let monthInterval = cal.dateInterval(of: .month, for: selectedDate) {
            let monthPred = eventStore.predicateForEvents(withStart: monthInterval.start, end: monthInterval.end, calendars: activeCals)
            let monthEvents = eventStore.events(matching: monthPred)
            monthEventDays = Set(monthEvents.map { cal.component(.day, from: $0.startDate) })
        }

        evaluateUpcomingTriggers(now: now)
    }

    private func evaluateUpcomingTriggers(now: Date) {
        let threshold = AppSettings.shared.timeBeforeEvent
        let upcoming = todayEvents.first { !$0.isAllDay && $0.endDate > now }
        if let ev = upcoming, ev.startDate.timeIntervalSince(now) <= threshold {
            nextRelevantEvent = ev
        } else {
            nextRelevantEvent = nil
        }

        if AppSettings.shared.enableCalendarQuickPeek, let ev = upcoming {
            let secondsUntil = ev.startDate.timeIntervalSince(now)
            let preSig = "pre-\(ev.id)-\(Int(ev.startDate.timeIntervalSince1970))"
            let startSig = "start-\(ev.id)-\(Int(ev.startDate.timeIntervalSince1970))"

            if AppSettings.shared.beforeEventStarts && secondsUntil > 30 && secondsUntil <= 300 && !peekedEventSignatures.contains(preSig) {
                peekedEventSignatures.insert(preSig)
                onEventQuickPeek?(ev)
            } else if AppSettings.shared.whenEventIsStarting && secondsUntil <= 30 && secondsUntil >= -30 && !peekedEventSignatures.contains(startSig) {
                peekedEventSignatures.insert(startSig)
                if AppSettings.shared.playSoundOnCalendarEvent {
                    SoundManager.shared.play(.event)
                }
                onEventQuickPeek?(ev)
            }
        }

        if AppSettings.shared.notifyWhenTimeToLeave, let ev = upcoming, let location = ev.location, !location.isEmpty {
            let sig = "ttl-\(ev.id)"
            if !ttlNotifiedSignatures.contains(sig) {
                evaluateTimeToLeave(for: ev, locationString: location, signature: sig)
            }
        }
    }

    private func evaluateTimeToLeave(for event: CalendarEventItem, locationString: String, signature: String) {
        let transportType = AppSettings.shared.defaultTransportType
        let buffer = AppSettings.shared.timeToLeaveBuffer
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(locationString) { [weak self] placemarks, _ in
            guard let destCoord = placemarks?.first?.location?.coordinate else { return }
            let req = MKDirections.Request()
            req.source = MKMapItem.forCurrentLocation()
            req.destination = MKMapItem(placemark: MKPlacemark(coordinate: destCoord))
            switch transportType {
            case .drive: req.transportType = .automobile
            case .transit: req.transportType = .transit
            case .walk: req.transportType = .walking
            }
            MKDirections(request: req).calculateETA { response, _ in
                guard let eta = response else { return }
                let minutes = Int(ceil(eta.expectedTravelTime / 60.0))
                let leaveDate = event.startDate.addingTimeInterval(-(eta.expectedTravelTime + buffer))
                if Date() >= leaveDate && Date() < event.startDate {
                    Task { @MainActor in
                        guard let self, !self.ttlNotifiedSignatures.contains(signature) else { return }
                        self.ttlNotifiedSignatures.insert(signature)
                        if AppSettings.shared.playSoundOnTimeToLeave {
                            SoundManager.shared.play(.directions)
                        }
                        self.onTimeToLeave?(event, minutes)
                    }
                }
            }
        }
    }

    private func checkHourlyChime() {
        guard AppSettings.shared.playHourlyChime else { return }
        let comps = Calendar.current.dateComponents([.minute, .second], from: Date())
        if comps.minute == 0 && (comps.second ?? 60) < 30 {
            SoundManager.shared.play(.chime)
        }
    }

    public func dismissEvent(_ event: CalendarEventItem) {
        dismissedEventIDs.insert(event.id)
        reloadCalendarsAndEvents()
    }

    public func openInCalendar(event: CalendarEventItem? = nil) {
        let fantURL = URL(string: "x-fantastical3://show/calendar")
        if let fantURL, NSWorkspace.shared.urlForApplication(toOpen: fantURL) != nil {
            if let ev = event {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
                fmt.timeZone = TimeZone(secondsFromGMT: 0)
                if let dateURL = URL(string: "x-fantastical3://show?date=\(fmt.string(from: ev.startDate))") {
                    NSWorkspace.shared.open(dateURL)
                    return
                }
            }
            NSWorkspace.shared.open(fantURL)
            return
        }
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    public static func extractMeetingInfo(from event: EKEvent) -> (url: URL?, provider: String?) {
        let candidates = [event.url?.absoluteString, event.location, event.notes].compactMap { $0 }
        let combined = candidates.joined(separator: "\n")
        return extractMeetingInfo(fromText: combined)
    }

    public static func extractMeetingInfo(fromText text: String) -> (url: URL?, provider: String?) {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return (nil, nil)
        }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for m in matches {
            guard let url = m.url else { continue }
            let host = (url.host ?? "").lowercased()
            if host.contains("facetime.apple.com") { return (url, "FaceTime") }
            if host.contains("zoom.us") { return (url, "Zoom") }
            if host.contains("meet.google.com") { return (url, "Google Meet") }
            if host.contains("teams.microsoft.com") || host.contains("teams.live.com") { return (url, "Microsoft Teams") }
            if host.contains("webex.com") { return (url, "Webex") }
        }
        return (nil, nil)
    }
}
