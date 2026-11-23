import Foundation
import AppKit
import ApplicationServices
import Security
import Combine

@MainActor
public final class MediaKeyManager: ObservableObject {
    public static let shared = MediaKeyManager()
    public static let reopenSettingsDefaultsKey = "oriel.reopenSettingsAfterRelaunch"

    @Published public var isAccessibilityAuthorized: Bool = false
    @Published public var axTrusted: Bool = false
    @Published public var isMonitoring: Bool = false
    @Published public var activeTapMode: String = "Inattivo"
    @Published public var signingSummary: String = "Verifica firma…"

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionCheckTimer: Timer?
    private var betterDisplayObservers: [NSObjectProtocol] = []
    private var isBetterDisplayRunning = false

    // Standard step = 1/16, Fine step (Option+Shift) = 1/64
    private let normalStep: Float = 1.0 / 16.0
    private let fineStep: Float = 1.0 / 64.0

    private init() {
        signingSummary = Self.inspectBundleSigningSummary()
        refreshAccessibilityStatus()
        observeBetterDisplay()
        observeAccessibilityChanges()
    }

    public func refreshAccessibilityStatus() {
        let trusted = AXIsProcessTrusted()
        axTrusted = trusted
        if !trusted && eventTap != nil {
            stopEventTap()
        }
        isAccessibilityAuthorized = trusted || (eventTap != nil)
        if eventTap == nil {
            activeTapMode = "Inattivo"
        }
    }

    public func promptAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        axTrusted = trusted
        if trusted && eventTap == nil {
            installEventTapIfNeeded()
        }
        refreshAccessibilityStatus()
    }

    public func relaunchApplication(reopenSettings: Bool = true) {
        if reopenSettings {
            UserDefaults.standard.set(true, forKey: Self.reopenSettingsDefaultsKey)
            UserDefaults.standard.synchronize()
        }
        let appPath = Bundle.main.bundleURL.resolvingSymlinksInPath().path
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", "sleep 0.45; /usr/bin/open \"$1\"", "_", appPath]
        try? proc.run()
        NSApp.terminate(nil)
    }

    public static func inspectBundleSigningSummary() -> String {
        var code: SecStaticCode?
        let url = Bundle.main.bundleURL.resolvingSymlinksInPath() as CFURL
        guard SecStaticCodeCreateWithPath(url, [], &code) == errSecSuccess, let staticCode = code else {
            return "Non firmato"
        }
        var infoRef: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticCode, flags, &infoRef) == errSecSuccess,
              let info = infoRef as? [String: Any] else {
            return "Non firmato"
        }
        let certs = info[kSecCodeInfoCertificates as String] as? [SecCertificate]
        let team = info[kSecCodeInfoTeamIdentifier as String] as? String
        return classifySigningIdentity(hasCertificates: !(certs?.isEmpty ?? true), teamIdentifier: team)
    }

    nonisolated public static func classifySigningIdentity(hasCertificates: Bool, teamIdentifier: String?) -> String {
        if let team = teamIdentifier, !team.isEmpty {
            return "Developer ID (\(team))"
        }
        if hasCertificates {
            return "Certificato Locale (Stabile)"
        }
        return "Ad-Hoc (Temporanea)"
    }

    private func observeAccessibilityChanges() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.refreshAccessibilityStatus()
                if AXIsProcessTrusted(), self.eventTap == nil {
                    self.installEventTapIfNeeded()
                }
                self.refreshAccessibilityStatus()
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.refreshAccessibilityStatus()
                if AXIsProcessTrusted(), self.eventTap == nil {
                    self.installEventTapIfNeeded()
                }
                self.refreshAccessibilityStatus()
            }
        }
    }

    public func start() {
        refreshAccessibilityStatus()
        if AXIsProcessTrusted() {
            installEventTapIfNeeded()
        }
        refreshAccessibilityStatus()

        permissionCheckTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if AXIsProcessTrusted() && self.eventTap == nil {
                    self.installEventTapIfNeeded()
                }
                self.refreshAccessibilityStatus()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionCheckTimer = timer
    }

    public func stop() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
        stopEventTap()
    }

    private func installEventTapIfNeeded() {
        guard eventTap == nil else { return }
        // Intercept only NSSystemDefined (14) hardware media/volume/brightness aux keys
        // so normal typing keystrokes are never inspected or delayed.
        let mask: CGEventMask = (1 << 14)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, type, event, refcon -> Unmanaged<CGEvent>? in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<MediaKeyManager>.fromOpaque(refcon).takeUnretainedValue()
            return manager.handleEventTap(type: type, event: event)
        }

        // Prefer .cghidEventTap so HID Volume/Brightness events are swallowed BEFORE macOS
        // ControlCenter / BezelServices renders the standard macOS HUD.
        var createdTap: CFMachPort? = nil
        var mode = "Inattivo"
        if let hidTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) {
            createdTap = hidTap
            mode = "HID"
        } else if let sessionTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) {
            createdTap = sessionTap
            mode = "Session"
        }

        guard let tap = createdTap else {
            isMonitoring = false
            activeTapMode = "Inattivo"
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        isMonitoring = true
        activeTapMode = mode
    }

    private func stopEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            runLoopSource = nil
        }
        isMonitoring = false
        activeTapMode = "Inattivo"
    }

    private func handleEventTap(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        let isOptionShift = flags.contains(.maskAlternate) && flags.contains(.maskShift)
        let step = isOptionShift ? fineStep : normalStep

        // Handle dedicated Apple keyboard brightness function keycodes (107/113/144/145)
        if type == .keyDown || type == .keyUp {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if [107, 113, 144, 145].contains(keyCode) && !flags.contains(.maskCommand) && !flags.contains(.maskControl) {
                guard AppSettings.shared.enableBrightness else {
                    return Unmanaged.passUnretained(event)
                }
                let displayID = BrightnessManager.shared.targetDisplayID()
                guard DisplayServicesBridge.canChangeBrightness(displayID: displayID) else {
                    return Unmanaged.passUnretained(event)
                }
                if type == .keyDown {
                    let isUp = (keyCode == 113 || keyCode == 144)
                    if Thread.isMainThread {
                        MainActor.assumeIsolated {
                            BrightnessManager.shared.adjustBrightness(by: isUp ? step : -step)
                        }
                    } else {
                        DispatchQueue.main.async {
                            BrightnessManager.shared.adjustBrightness(by: isUp ? step : -step)
                        }
                    }
                }
                return nil // Suppress native brightness HUD
            }
            return Unmanaged.passUnretained(event)
        }

        // Handle NSSystemDefined (type 14) media/volume/brightness aux keys
        guard type.rawValue == 14 else {
            return Unmanaged.passUnretained(event)
        }
        guard let nsEvent = NSEvent(cgEvent: event), nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passUnretained(event)
        }

        let data1 = nsEvent.data1
        let keyCode = (data1 & 0xFFFF0000) >> 16
        let keyFlags = data1 & 0x0000FFFF
        let keyState = (keyFlags & 0xFF00) >> 8
        let isKeyDown = keyState == 0x0A
        let isKeyUp = keyState == 0x0B
        guard isKeyDown || isKeyUp else {
            return Unmanaged.passUnretained(event)
        }

        // NX_KEYTYPE values from IOKit/hidsystem/ev_keymap.h:
        // 0 = SOUND_UP, 1 = SOUND_DOWN, 7 = MUTE
        // 2 = BRIGHTNESS_UP, 3 = BRIGHTNESS_DOWN
        // 16 = PLAY, 17 = NEXT, 18 = PREVIOUS, 19 = FAST, 20 = REWIND
        switch keyCode {
        case 0, 1, 7: // Volume Up, Down, Mute
            guard AppSettings.shared.enableVolume else {
                return Unmanaged.passUnretained(event)
            }
            if flags.contains(.maskShift) && flags.contains(.maskAlternate) == false && keyCode != 7 {
                // Shift+Volume opens Sound preferences if system behavior desired, otherwise handle
            }
            if isKeyDown {
                let code = keyCode
                if Thread.isMainThread {
                    MainActor.assumeIsolated {
                        switch code {
                        case 0: VolumeManager.shared.adjustVolume(by: step)
                        case 1: VolumeManager.shared.adjustVolume(by: -step)
                        case 7: VolumeManager.shared.toggleMute()
                        default: break
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        switch code {
                        case 0: VolumeManager.shared.adjustVolume(by: step)
                        case 1: VolumeManager.shared.adjustVolume(by: -step)
                        case 7: VolumeManager.shared.toggleMute()
                        default: break
                        }
                    }
                }
            }
            return nil // Suppress native volume HUD

        case 2, 3: // Brightness Up, Down
            guard AppSettings.shared.enableBrightness else {
                return Unmanaged.passUnretained(event)
            }
            let displayID = BrightnessManager.shared.targetDisplayID()
            guard DisplayServicesBridge.canChangeBrightness(displayID: displayID) else {
                return Unmanaged.passUnretained(event)
            }
            if isKeyDown {
                let isUp = (keyCode == 2)
                if Thread.isMainThread {
                    MainActor.assumeIsolated {
                        BrightnessManager.shared.adjustBrightness(by: isUp ? step : -step)
                    }
                } else {
                    DispatchQueue.main.async {
                        BrightnessManager.shared.adjustBrightness(by: isUp ? step : -step)
                    }
                }
            }
            return nil // Suppress native brightness HUD

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func observeBetterDisplay() {
        let dnc = DistributedNotificationCenter.default()
        betterDisplayObservers.append(
            dnc.addObserver(forName: Notification.Name("pro.betterdisplay.BetterDisplay.launched"), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.isBetterDisplayRunning = true }
            }
        )
        betterDisplayObservers.append(
            dnc.addObserver(forName: Notification.Name("pro.betterdisplay.BetterDisplay.terminated"), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.isBetterDisplayRunning = false }
            }
        )
        betterDisplayObservers.append(
            dnc.addObserver(forName: Notification.Name("com.betterdisplay.BetterDisplay.osd"), object: nil, queue: .main) { note in
                guard let info = note.userInfo else { return }
                if let val = info["value"] as? Double {
                    Task { @MainActor in
                        if let control = info["controlTarget"] as? String, control.lowercased().contains("volume") {
                            VolumeManager.shared.onVolumeChanged?(Float(val), val <= 0.001, "External Display", "display")
                        } else {
                            BrightnessManager.shared.onBrightnessChanged?(Float(val), true)
                        }
                    }
                }
            }
        )
    }
}
