import AppKit
import Foundation
import SwiftUI
import Testing
@testable import OrielCore

@Suite("Oriel Core Suite")
@MainActor
struct OrielTests {
    @Test("Physical and simulated notch geometry metrics")
    func notchMetricsPhysicalAndSimulated() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1470, height: 956)
        let auxLeft = CGRect(x: 0, y: 924, width: 645.5, height: 32)
        let auxRight = CGRect(x: 824.5, y: 924, width: 645.5, height: 32)

        let physical = NotchMetrics.compute(
            screenFrame: screenFrame,
            safeAreaTop: 32,
            auxLeft: auxLeft,
            auxRight: auxRight,
            adjustedWidth: 0,
            adjustedHeight: 0,
            forceSimulated: false
        )
        #expect(physical.hasPhysicalNotch == true)
        #expect(physical.isSimulated == false)
        #expect(abs(physical.notchWidth - 179.0) < 0.1)
        #expect(abs(physical.notchHeight - 32.0) < 0.1)

        let external = NotchMetrics.compute(
            screenFrame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            safeAreaTop: 0,
            auxLeft: nil,
            auxRight: nil,
            adjustedWidth: 10,
            adjustedHeight: 4,
            forceSimulated: true
        )
        #expect(external.hasPhysicalNotch == false)
        #expect(external.isSimulated == true)
        #expect(abs(external.notchWidth - 190.0) < 0.1)
        #expect(abs(external.notchHeight - 36.0) < 0.1)
    }

    @Test("Focus manager log parser")
    func focusLogLineParsing() {
        let line = "Assertion updated: activeModeIdentifier=com.apple.focus.work, symbolImageName: person.lanyardcard.fill, tintColorName: systemTealColor"
        let parsed = FocusManager.parseLogLine(line)
        #expect(parsed != nil)
        #expect(parsed?.identifier == "com.apple.focus.work")
        #expect(parsed?.symbol == "person.lanyardcard.fill")
        #expect(parsed?.tintColorName == "systemTealColor")

        let clearedLine = "activeModeIdentifier: (null)"
        let cleared = FocusManager.parseLogLine(clearedLine)
        #expect(cleared != nil)
        #expect(cleared?.identifier == nil)
    }

    @Test("Connectivity OutputContext log and AirPods symbol matching")
    func connectivityParsers() {
        let log = """
        [OutputContext] OutputDevice name = "Riccardo's AirPods Pro"; configuredClusterSize = 2; model = AudioAccessory5,1;
        """
        let parsed = ConnectivityManager.parseOutputContextLog(log)
        #expect(parsed != nil)
        #expect(parsed?.name == "Riccardo's AirPods Pro")
        #expect(parsed?.clusterSize == 2)

        let pro = ConnectivityManager.symbolForDevice(name: "AirPods Pro 2")
        #expect(pro.symbol == "airpodspro")
        #expect(pro.isAirPods == true)

        let max = ConnectivityManager.symbolForDevice(name: "AirPods Max")
        #expect(max.symbol == "airpodsmax")
        #expect(max.isAirPods == true)

        let generic = ConnectivityManager.symbolForDevice(name: "Sony WH-1000XM5")
        #expect(generic.symbol == "headphones")
        #expect(generic.isAirPods == false)
    }

    @Test("Calendar meeting provider extraction")
    func calendarMeetingLinkExtraction() {
        let zoom = CalendarManager.extractMeetingInfo(fromText: "Join us here: https://us06web.zoom.us/j/123456789?pwd=abc")
        #expect(zoom.provider == "Zoom")
        #expect(zoom.url?.host == "us06web.zoom.us")

        let meet = CalendarManager.extractMeetingInfo(fromText: "Video call: https://meet.google.com/abc-defg-hij")
        #expect(meet.provider == "Google Meet")

        let teams = CalendarManager.extractMeetingInfo(fromText: "https://teams.microsoft.com/l/meetup-join/xyz")
        #expect(teams.provider == "Microsoft Teams")

        let none = CalendarManager.extractMeetingInfo(fromText: "Conference Room B")
        #expect(none.url == nil)
        #expect(none.provider == nil)
    }

    @Test("Weather WMO code mapping")
    func weatherWMOCodeMapping() {
        let clearDay = WeatherManager.mapWMOCode(0, isDay: true)
        #expect(clearDay.description == "Clear")
        #expect(clearDay.symbol == "sun.max.fill")

        let clearNight = WeatherManager.mapWMOCode(0, isDay: false)
        #expect(clearNight.symbol == "moon.stars.fill")

        let rain = WeatherManager.mapWMOCode(63, isDay: true)
        #expect(rain.description == "Rain")
        #expect(rain.symbol == "cloud.sun.rain.fill")
    }

    @Test("Volume decibel formatting")
    func volumeDecibelFormatting() {
        #expect(VolumeManager.decibelString(for: 0.0) == "-∞ dB")
        #expect(VolumeManager.decibelString(for: 1.0) == "0.0 dB")
    }

    @Test("Spotify URI to web share URL")
    func spotifyShareURLConversion() {
        let url = MediaManager.spotifyShareURL(from: "spotify:track:4uLU6hMCjMI75M1A2tKUQC")
        #expect(url?.absoluteString == "https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC")

        let plain = MediaManager.spotifyShareURL(from: "https://music.apple.com/album/123")
        #expect(plain?.absoluteString == "https://music.apple.com/album/123")
    }

    @Test("Dominant artwork color extraction")
    func dominantColorExtractionOnSolidImage() {
        let size = NSSize(width: 40, height: 40)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor(calibratedRed: 0.18, green: 0.83, blue: 0.75, alpha: 1.0).setFill()
        NSRect(origin: .zero, size: size).fill()
        img.unlockFocus()

        let colors = DominantColorExtractor.extractColors(from: img, count: 2)
        #expect(!colors.isEmpty)
    }

    @Test("AppSettings persistence round-trip")
    func appSettingsPersistence() {
        let suiteName = "com.oriel.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let s1 = AppSettings(defaults: defaults)
        s1.enableHaptics = false
        s1.volumeProgressStyle = .decibel
        s1.notchAdjustedWidth = 24
        s1.excludedCalendars = ["cal-1", "cal-2"]

        let s2 = AppSettings(defaults: defaults)
        #expect(s2.enableHaptics == false)
        #expect(s2.volumeProgressStyle == .decibel)
        #expect(s2.notchAdjustedWidth == 24)
        #expect(s2.excludedCalendars == ["cal-1", "cal-2"])
    }

    @Test("NotchController expansion and activity cycling")
    func notchControllerExpansionAndCycling() {
        let controller = NotchController.shared
        let prevTray = AppSettings.shared.enableFileTray
        AppSettings.shared.enableFileTray = true
        defer {
            controller.setExpanded(false)
            AppSettings.shared.enableFileTray = prevTray
        }

        controller.setExpanded(true, activity: .nowPlaying)
        #expect(controller.isExpanded == true)
        #expect(controller.expandedActivity == .nowPlaying)
        #expect(controller.currentWidth == 448)

        controller.cycleExpandedActivity()
        #expect(controller.expandedActivity == .calendar)
        #expect(controller.currentWidth == 460)

        controller.cycleExpandedActivity()
        #expect(controller.expandedActivity == .duo)
        #expect(controller.currentWidth == 596)

        controller.cycleExpandedActivity()
        #expect(controller.expandedActivity == .fileTray)

        controller.setExpanded(false)
        #expect(controller.isExpanded == false)
    }

    @Test("Top bezel cursor containment includes exact sf.maxY")
    func topBezelEdgeContainsCursor() {
        let sf = CGRect(x: 0, y: 0, width: 1470, height: 956)
        let hoverRect = NSRect(x: sf.midX - 130, y: sf.maxY - 50, width: 260, height: 50 + 14)
        #expect(hoverRect.contains(NSPoint(x: sf.midX, y: sf.maxY)) == true)
        #expect(hoverRect.contains(NSPoint(x: sf.midX, y: sf.maxY - 1)) == true)
        #expect(hoverRect.contains(NSPoint(x: sf.midX, y: sf.maxY - 120)) == false)
    }

    @Test("Spotify and Apple Music distributed notification payload parsing")
    func distributedMediaNotificationParsing() {
        let spotifyPayload: [AnyHashable: Any] = [
            "Player State": "Playing",
            "Name": "Nocturnal",
            "Artist": "Gemello",
            "Album": "Niagara",
            "Duration": 205.0,
            "Playback Position": 42.5,
            "Track ID": "spotify:track:4uLU6hMCjMI75M1A2tKUQC"
        ]
        let sp = MediaManager.parseSpotifyNotificationPayload(spotifyPayload)
        #expect(sp?.title == "Nocturnal")
        #expect(sp?.artist == "Gemello")
        #expect(sp?.duration == 205.0)
        #expect(sp?.elapsed == 42.5)
        #expect(sp?.isPlaying == true)
        #expect(sp?.shareURL?.absoluteString == "https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC")

        let musicPayload: [AnyHashable: Any] = [
            "Player State": "Paused",
            "Name": "Midnight",
            "Artist": "Artist",
            "Album": "Album",
            "Total Time": 180000.0
        ]
        let am = MediaManager.parseAppleMusicNotificationPayload(musicPayload)
        #expect(am?.title == "Midnight")
        #expect(am?.duration == 180.0)
        #expect(am?.isPlaying == false)
    }

    @Test("Spotify oEmbed and iTunes Search artwork URL parsing")
    func publicArtworkURLParsing() {
        let oembedJSON = #"{"thumbnail_url":"https://image-cdn-fa.spotifycdn.com/image/abc123"}"#.data(using: .utf8)!
        #expect(MediaManager.parseSpotifyOEmbedThumbnailURL(from: oembedJSON)?.absoluteString == "https://image-cdn-fa.spotifycdn.com/image/abc123")

        let itunesJSON = #"{"results":[{"artworkUrl100":"https://is1-ssl.mzstatic.com/image/thumb/x/100x100bb.jpg"}]}"#.data(using: .utf8)!
        #expect(MediaManager.parseITunesArtworkURL(from: itunesJSON)?.absoluteString == "https://is1-ssl.mzstatic.com/image/thumb/x/600x600bb.jpg")
    }

    @Test("Signing identity classification distinguishes persistent certificate from ad-hoc")
    func signingIdentityClassification() {
        #expect(MediaKeyManager.classifySigningIdentity(hasCertificates: true, teamIdentifier: "287NUTSP69") == "Developer ID (287NUTSP69)")
        #expect(MediaKeyManager.classifySigningIdentity(hasCertificates: true, teamIdentifier: nil) == "Certificato Locale (Stabile)")
        #expect(MediaKeyManager.classifySigningIdentity(hasCertificates: false, teamIdentifier: nil) == "Ad-Hoc (Temporanea)")
    }

    @Test("NotchController rubber-band swipe preview clamping and reset")
    func notchControllerMotionInputs() {
        let controller = NotchController.shared
        defer {
            controller.resetSwipeGesturePreview()
        }

        controller.updateSwipeGesturePreview(deltaX: 200, deltaY: -200)
        #expect(controller.swipeOffsetX == 14.0)
        #expect(controller.swipeOffsetY == -8.0)

        controller.resetSwipeGesturePreview()
        #expect(controller.swipeOffsetX == 0.0)
        #expect(controller.swipeOffsetY == 0.0)
    }
}
