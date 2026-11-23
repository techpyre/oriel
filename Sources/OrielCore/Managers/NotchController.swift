import Foundation
import AppKit
import SwiftUI
import Combine

@MainActor
public final class NotchController: ObservableObject {
    public static let shared = NotchController()

    @Published public var metrics: NotchMetrics
    @Published public var liveActivity: LiveActivity = .none
    @Published public var notification: NotchNotification = .none
    @Published public var quickPeek: QuickPeekContent = .none
    @Published public var expandedActivity: ExpandedActivity = .nowPlaying
    @Published public var isExpanded: Bool = false
    @Published public var isHovered: Bool = false
    @Published public var isHidden: Bool = false
    @Published public var dismissedCurrentLiveActivity: Bool = false

    // Gesture feedback offsets & elastic HUD impulse
    @Published public var swipeOffsetX: CGFloat = 0
    @Published public var swipeOffsetY: CGFloat = 0
    @Published public var hudElasticStretch: CGFloat = 0
    @Published public var hudPulseToken: Int = 0

    /// Invoked synchronously right before growing into an overlay/expanded state so AppKit panels
    /// can enlarge their backing NSWindow frame before SwiftUI renders the expanded animation.
    public var onBeforeExpandOrOverlay: (() -> Void)?

    private var notificationWorkItem: DispatchWorkItem?
    private var quickPeekWorkItem: DispatchWorkItem?
    private var hoverWorkItem: DispatchWorkItem?
    private var elasticResetWorkItem: DispatchWorkItem?
    private var cancellables: Set<AnyCancellable> = []

    public var currentWidth: CGFloat {
        let wingExtra = CGFloat(AppSettings.shared.notchWingPadding) * 2
        if isExpanded {
            switch expandedActivity {
            case .duo:
                return 596
            case .calendar:
                return 460
            case .nowPlaying, .fileTray:
                return 448
            }
        }
        if quickPeek != .none {
            return max(metrics.notchWidth + 216 + wingExtra, 404)
        }
        if notification != .none {
            switch notification {
            case .didChangeVolume, .didChangeBrightness:
                return metrics.notchWidth + 260 + wingExtra
            case .didConnectAirPods, .isLowAirPodsBattery, .timeToLeave:
                return metrics.notchWidth + 292 + wingExtra
            case .isCharging, .isLowBattery, .isLowPowerMode, .isFocus:
                return metrics.notchWidth + 248 + wingExtra
            case .none:
                break
            }
        }
        if liveActivity != .none && !isHidden {
            return metrics.notchWidth + 118 + wingExtra
        }
        return metrics.notchWidth
    }

    public var currentHeight: CGFloat {
        if isExpanded {
            switch expandedActivity {
            case .duo:
                return 170
            case .calendar:
                return 164
            case .nowPlaying:
                return 160
            case .fileTray:
                return 154
            }
        }
        if quickPeek != .none {
            return metrics.notchHeight + 46
        }
        if notification != .none {
            return metrics.notchHeight + 6
        }
        return metrics.notchHeight
    }

    private init() {
        let initialScreen = NSScreen.main ?? NSScreen.screens.first
        let settings = AppSettings.shared
        if let screen = initialScreen {
            self.metrics = NotchMetrics.forScreen(
                screen,
                adjustedWidth: settings.notchAdjustedWidth,
                adjustedHeight: settings.notchAdjustedHeight,
                forceSimulated: settings.forceSimulatedNotch
            )
        } else {
            self.metrics = NotchMetrics.compute(
                screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
                safeAreaTop: 32,
                auxLeft: CGRect(x: 0, y: 924, width: 645.5, height: 32),
                auxRight: CGRect(x: 824.5, y: 924, width: 645.5, height: 32),
                adjustedWidth: 0,
                adjustedHeight: 0,
                forceSimulated: false
            )
        }

        wireCallbacks()
        observeState()
        recomputeLiveActivity()
    }

    public func updateMetrics(for screen: NSScreen?) {
        guard let screen else { return }
        let s = AppSettings.shared
        metrics = NotchMetrics.forScreen(
            screen,
            adjustedWidth: s.notchAdjustedWidth,
            adjustedHeight: s.notchAdjustedHeight,
            forceSimulated: s.forceSimulatedNotch
        )
    }

    private func wireCallbacks() {
        VolumeManager.shared.onVolumeChanged = { [weak self] level, muted, devName, devSymbol in
            guard let self else { return }
            let s = AppSettings.shared
            guard s.enableVolume else { return }
            if FocusManager.shared.isFocusActive && !s.allowVolumeWhenFocused { return }
            if LockManager.shared.isLocked && !s.allowVolumeWhenLocked { return }
            self.showNotification(.didChangeVolume(level: level, isMuted: muted, deviceName: devName, deviceSymbol: devSymbol), duration: s.volumeDuration)
        }

        BrightnessManager.shared.onBrightnessChanged = { [weak self] level, isExternal in
            guard let self else { return }
            let s = AppSettings.shared
            guard s.enableBrightness else { return }
            if FocusManager.shared.isFocusActive && !s.allowBrightnessWhenFocused { return }
            if LockManager.shared.isLocked && !s.allowBrightnessWhenLocked { return }
            self.showNotification(.didChangeBrightness(level: level, isExternal: isExternal), duration: s.brightnessDuration)
        }

        BatteryManager.shared.onChargingConnected = { [weak self] level in
            guard let self else { return }
            let s = AppSettings.shared
            guard s.enableBattery else { return }
            if FocusManager.shared.isFocusActive && !s.allowBatteryWhenFocused { return }
            if LockManager.shared.isLocked && !s.allowBatteryWhenLocked { return }
            self.showNotification(.isCharging(level: level), duration: s.batteryDuration)
        }

        BatteryManager.shared.onLowBattery = { [weak self] level in
            guard let self else { return }
            let s = AppSettings.shared
            guard s.enableBattery else { return }
            self.showNotification(.isLowBattery(level: level), duration: s.batteryDuration)
        }

        BatteryManager.shared.onLowPowerModeActivated = { [weak self] in
            guard let self else { return }
            let s = AppSettings.shared
            guard s.enableBattery else { return }
            self.showNotification(.isLowPowerMode, duration: s.batteryDuration)
        }

        ConnectivityManager.shared.onDeviceConnected = { [weak self] device in
            guard let self else { return }
            let s = AppSettings.shared
            guard s.enableConnectivity else { return }
            if FocusManager.shared.isFocusActive && !s.allowConnectivityWhenFocused { return }
            if LockManager.shared.isLocked && !s.allowConnectivityWhenLocked { return }
            self.showNotification(.didConnectAirPods(name: device.name, symbol: device.symbolName, battery: device.effectiveBattery), duration: s.connectivityDuration)
        }

        ConnectivityManager.shared.onLowDeviceBattery = { [weak self] device, bat in
            guard let self else { return }
            let s = AppSettings.shared
            guard s.enableConnectivity else { return }
            self.showNotification(.isLowAirPodsBattery(name: device.name, symbol: device.symbolName, battery: bat), duration: s.connectivityDuration)
        }

        FocusManager.shared.onFocusChanged = { [weak self] mode, active in
            guard let self else { return }
            let s = AppSettings.shared
            guard s.enableFocus, let mode else { return }
            if LockManager.shared.isLocked && !s.allowFocusWhenLocked { return }
            self.showNotification(.isFocus(mode: mode, active: active), duration: s.focusDuration)
        }

        MediaManager.shared.onTrackChanged = { [weak self] track in
            guard let self else { return }
            self.dismissedCurrentLiveActivity = false
            self.recomputeLiveActivity()
            let s = AppSettings.shared
            if s.enableNowPlaying && s.enableQuickPeek && s.whenSongChanges && !self.isExpanded && !self.isHidden {
                self.showQuickPeek(.track(title: track.title, artist: track.artist, artworkData: track.artworkData), duration: s.peekDuration)
            }
        }

        CalendarManager.shared.onEventQuickPeek = { [weak self] ev in
            guard let self else { return }
            let s = AppSettings.shared
            guard s.enableCalendar, s.enableCalendarQuickPeek, !self.isExpanded else { return }
            self.showQuickPeek(.calendarEvent(title: ev.title, startDate: ev.startDate, colorHex: ev.colorHex, meetingURL: ev.meetingURL), duration: s.calendarPeekDuration)
        }

        CalendarManager.shared.onTimeToLeave = { [weak self] ev, mins in
            guard let self else { return }
            let s = AppSettings.shared
            guard s.enableCalendar, s.notifyWhenTimeToLeave else { return }
            self.showNotification(.timeToLeave(title: ev.title, minutes: mins, transport: s.defaultTransportType), duration: s.timeToLeaveDuration)
        }
    }

    private func observeState() {
        let s = AppSettings.shared

        Publishers.CombineLatest4(
            MediaManager.shared.$track,
            MediaManager.shared.$isHiddenIdle,
            MediaManager.shared.$isSourceAppActive,
            CalendarManager.shared.$nextRelevantEvent
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.recomputeLiveActivity()
        }
        .store(in: &cancellables)

        Publishers.CombineLatest3(
            ScreenManager.shared.$isFullscreen,
            GameManager.shared.$isGaming,
            FocusManager.shared.$isFocusActive
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.recomputeVisibility()
            self?.recomputeLiveActivity()
        }
        .store(in: &cancellables)

        s.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateMetrics(for: ScreenManager.shared.targetScreens(for: AppSettings.shared).first)
                    self?.recomputeVisibility()
                    self?.recomputeLiveActivity()
                }
            }
            .store(in: &cancellables)
    }

    public func recomputeVisibility() {
        let s = AppSettings.shared
        let hideFS = s.hideWhileInFullscreen && ScreenManager.shared.isFullscreen
        let hideGaming = s.hideWhileGaming && GameManager.shared.isGaming
        let hideSource = s.hideWhileSourceIsActive && MediaManager.shared.isSourceAppActive && !isExpanded
        isHidden = hideFS || hideGaming || hideSource
    }

    public func recomputeLiveActivity() {
        let s = AppSettings.shared
        if dismissedCurrentLiveActivity {
            liveActivity = .none
            return
        }
        if LockManager.shared.isLocked {
            liveActivity = .isLocked
            return
        }
        if s.enableNowPlaying && MediaManager.shared.track.hasTrack && (!MediaManager.shared.isHiddenIdle || MediaManager.shared.track.isPlaying || s.forceEnableActivity) {
            liveActivity = .isPlaying
            return
        }
        if s.enableCalendar && CalendarManager.shared.nextRelevantEvent != nil {
            liveActivity = .isCalendar
            return
        }
        if s.forceEnableActivity {
            switch s.idleActivity {
            case .nowPlaying: liveActivity = .isPlaying
            case .calendar: liveActivity = .isCalendar
            case .duo: liveActivity = .isPlaying
            case .none: liveActivity = .none
            }
            return
        }
        liveActivity = .none
    }

    // MARK: - Notifications & Quick Peek

    private func springAnimation(for speed: HUDSpeed) -> Animation? {
        switch speed {
        case .instant:
            return .spring(duration: 0.16, bounce: 0.06)
        case .fast:
            return .spring(duration: 0.28, bounce: 0.14)
        case .smooth:
            return .spring(duration: 0.36, bounce: 0.12)
        }
    }

    private func triggerElasticStretch(_ amount: CGFloat) {
        elasticResetWorkItem?.cancel()
        withAnimation(.spring(duration: 0.15, bounce: 0.20)) {
            hudElasticStretch = amount
        }
        let reset = DispatchWorkItem { [weak self] in
            withAnimation(.spring(duration: 0.24, bounce: 0.14)) {
                self?.hudElasticStretch = 0
            }
        }
        elasticResetWorkItem = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09, execute: reset)
    }

    public func updateSwipeGesturePreview(deltaX: CGFloat, deltaY: CGFloat) {
        let dampedX = deltaX * 0.20
        let dampedY = deltaY * 0.16
        swipeOffsetX = max(-14, min(14, dampedX))
        swipeOffsetY = max(-8, min(12, dampedY))
    }

    public func resetSwipeGesturePreview() {
        guard swipeOffsetX != 0 || swipeOffsetY != 0 else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            swipeOffsetX = 0
            swipeOffsetY = 0
        }
    }

    private func isSameHUDCategory(_ a: NotchNotification, _ b: NotchNotification) -> Bool {
        switch (a, b) {
        case (.didChangeVolume, .didChangeVolume),
             (.didChangeBrightness, .didChangeBrightness):
            return true
        default:
            return false
        }
    }

    public func showNotification(_ newNotification: NotchNotification, duration: TimeInterval) {
        notificationWorkItem?.cancel()
        onBeforeExpandOrOverlay?()

        let speed: HUDSpeed
        switch newNotification {
        case .didChangeVolume:
            speed = AppSettings.shared.volumeSpeed
        case .didChangeBrightness:
            speed = AppSettings.shared.brightnessSpeed
        default:
            speed = AppSettings.shared.animationSpeed
        }

        let updatingExistingSlider = isSameHUDCategory(notification, newNotification)
        let anim = updatingExistingSlider
            ? .spring(response: 0.14, dampingFraction: 0.86)
            : springAnimation(for: speed)
        withAnimation(anim) {
            notification = newNotification
            hudPulseToken &+= 1
            if quickPeek != .none {
                quickPeek = .none
            }
        }

        // Subtle Apple-style elastic end-stop recoil at 0% / 100%
        switch newNotification {
        case .didChangeVolume(let level, let muted, _, _):
            if muted || level <= 0.005 {
                triggerElasticStretch(-7)
            } else if level >= 0.995 {
                triggerElasticStretch(8)
            }
        case .didChangeBrightness(let level, _):
            if level <= 0.005 {
                triggerElasticStretch(-7)
            } else if level >= 0.995 {
                triggerElasticStretch(8)
            }
        default:
            break
        }

        let closeAnim = springAnimation(for: speed)
        let work = DispatchWorkItem { [weak self] in
            withAnimation(closeAnim) {
                self?.notification = .none
                self?.hudElasticStretch = 0
            }
        }
        notificationWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.5, duration), execute: work)
    }

    public func showQuickPeek(_ content: QuickPeekContent, duration: TimeInterval) {
        quickPeekWorkItem?.cancel()
        onBeforeExpandOrOverlay?()
        let anim = springAnimation(for: AppSettings.shared.animationSpeed)
        withAnimation(anim) {
            quickPeek = content
        }
        let work = DispatchWorkItem { [weak self] in
            withAnimation(anim) {
                self?.quickPeek = .none
            }
        }
        quickPeekWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.8, duration), execute: work)
    }

    // MARK: - Expansion & Gestures

    public func setExpanded(_ expand: Bool, activity: ExpandedActivity? = nil) {
        if expand {
            onBeforeExpandOrOverlay?()
            quickPeekWorkItem?.cancel()
            quickPeek = .none
            notificationWorkItem?.cancel()
            notification = .none

            if let activity {
                expandedActivity = activity
            } else {
                switch AppSettings.shared.idleActivity {
                case .calendar: expandedActivity = .calendar
                case .duo: expandedActivity = .duo
                case .nowPlaying, .none:
                    if AppSettings.shared.mostRecentActivity && CalendarManager.shared.nextRelevantEvent != nil && !MediaManager.shared.track.isPlaying {
                        expandedActivity = .calendar
                    } else if AppSettings.shared.enableCalendar && AppSettings.shared.enableNowPlaying && AppSettings.shared.idleActivity == .duo {
                        expandedActivity = .duo
                    } else {
                        expandedActivity = .nowPlaying
                    }
                }
            }
        }

        if expand != isExpanded {
            HapticFeedback.shared.perform(.alignment)
        }

        let anim = springAnimation(for: AppSettings.shared.animationSpeed)
        withAnimation(anim) {
            isExpanded = expand
            swipeOffsetX = 0
            swipeOffsetY = 0
        }
    }

    public func toggleExpanded() {
        setExpanded(!isExpanded)
    }

    public func cycleExpandedActivity() {
        let options: [ExpandedActivity] = AppSettings.shared.enableFileTray
            ? [.nowPlaying, .calendar, .duo, .fileTray]
            : [.nowPlaying, .calendar, .duo]
        guard let idx = options.firstIndex(of: expandedActivity) else {
            expandedActivity = .nowPlaying
            return
        }
        HapticFeedback.shared.perform(.alignment)
        let anim = springAnimation(for: AppSettings.shared.animationSpeed)
        withAnimation(anim) {
            expandedActivity = options[(idx + 1) % options.count]
        }
    }

    public func handleHoverChanged(_ hovering: Bool) {
        guard hovering != isHovered else { return }
        if hovering && !isExpanded {
            onBeforeExpandOrOverlay?()
        }
        withAnimation(.spring(duration: 0.20, bounce: 0.12)) {
            isHovered = hovering
        }
        hoverWorkItem?.cancel()
        guard AppSettings.shared.expandNotchOnHover else { return }

        if hovering && !isExpanded {
            let delay = max(0.02, AppSettings.shared.hoverDuration)
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.isHovered else { return }
                self.setExpanded(true)
            }
            hoverWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        } else if !hovering && isExpanded {
            let work = DispatchWorkItem { [weak self] in
                guard let self, !self.isHovered else { return }
                self.setExpanded(false)
            }
            hoverWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14, execute: work)
        }
    }

    public func handleVerticalSwipe(deltaY: CGFloat) {
        let s = AppSettings.shared
        let dirY = s.naturalMovement ? deltaY : -deltaY
        if dirY > 18 {
            // Swipe down
            if isExpanded && s.swipeToCycleActivity {
                cycleExpandedActivity()
            } else if !isExpanded && s.swipeToToggle {
                setExpanded(true)
            }
        } else if dirY < -18 {
            // Swipe up
            if isExpanded && s.swipeToToggle {
                setExpanded(false)
            } else if !isExpanded && s.swipeToDismiss {
                HapticFeedback.shared.perform(.alignment)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    dismissedCurrentLiveActivity = true
                    quickPeek = .none
                    recomputeLiveActivity()
                }
            }
        }
    }

    public func handleHorizontalSwipe(deltaX: CGFloat) {
        let s = AppSettings.shared
        guard s.swipeToSkip, s.enableNowPlaying else { return }
        let dirX = s.naturalMovement ? deltaX : -deltaX
        if dirX > 22 {
            MediaManager.shared.nextTrack()
        } else if dirX < -22 {
            MediaManager.shared.previousTrack()
        }
    }
}
