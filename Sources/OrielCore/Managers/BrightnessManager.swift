import Foundation
import AppKit
import CoreGraphics
import Combine

@MainActor
public final class BrightnessManager: ObservableObject {
    public static let shared = BrightnessManager()

    @Published public var currentBrightness: Float = 0.5
    @Published public var isExternalDisplay: Bool = false

    public var onBrightnessChanged: ((Float, Bool) -> Void)?

    private var suppressUntil: Date = .distantPast
    private var pollTimer: Timer?
    private var lastPollTickAt: CFTimeInterval = 0

    private init() {
        syncFromDisplay(notify: false)
        // Fast ~150ms responsiveness when Accessibility tap isn't suppressing keys,
        // otherwise light 2s check for Control Center / Touch Bar external changes.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let now = CFAbsoluteTimeGetCurrent()
                let interval: CFTimeInterval = MediaKeyManager.shared.isAccessibilityAuthorized ? 2.0 : 0.14
                guard now - self.lastPollTickAt >= interval else { return }
                self.lastPollTickAt = now
                self.pollBrightness()
            }
        }
    }

    public func targetDisplayID() -> CGDirectDisplayID {
        let mainID = CGMainDisplayID()
        if DisplayServicesBridge.canChangeBrightness(displayID: mainID) {
            return mainID
        }
        // Fallback to built-in display
        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: 8)
        var count: UInt32 = 0
        if CGGetOnlineDisplayList(8, &onlineDisplays, &count) == .success {
            for i in 0..<Int(count) {
                let d = onlineDisplays[i]
                if CGDisplayIsBuiltin(d) != 0 && DisplayServicesBridge.canChangeBrightness(displayID: d) {
                    return d
                }
            }
        }
        return mainID
    }

    public func syncFromDisplay(notify: Bool) {
        let displayID = targetDisplayID()
        let external = CGDisplayIsBuiltin(displayID) == 0
        isExternalDisplay = external
        if let val = DisplayServicesBridge.getBrightness(displayID: displayID) {
            currentBrightness = val
            if notify && Date() > suppressUntil {
                onBrightnessChanged?(val, external)
            }
        }
    }

    private func pollBrightness() {
        guard Date() > suppressUntil else { return }
        let displayID = targetDisplayID()
        guard let val = DisplayServicesBridge.getBrightness(displayID: displayID) else { return }
        if abs(val - currentBrightness) > 0.015 {
            currentBrightness = val
            isExternalDisplay = CGDisplayIsBuiltin(displayID) == 0
            onBrightnessChanged?(val, isExternalDisplay)
        }
    }

    public func adjustBrightness(by delta: Float) {
        let displayID = targetDisplayID()
        let current = DisplayServicesBridge.getBrightness(displayID: displayID) ?? currentBrightness
        let target = max(0, min(1, current + delta))
        setBrightness(target, displayID: displayID, notify: true)
    }

    public func setBrightness(_ value: Float, displayID: CGDirectDisplayID? = nil, notify: Bool = true) {
        let targetID = displayID ?? targetDisplayID()
        let clamped = max(0, min(1, value))
        currentBrightness = clamped
        isExternalDisplay = CGDisplayIsBuiltin(targetID) == 0
        suppressUntil = Date().addingTimeInterval(0.35)

        let smooth = AppSettings.shared.brightnessSpeed == .smooth
        _ = DisplayServicesBridge.setBrightness(displayID: targetID, value: clamped, smooth: smooth)

        if notify {
            onBrightnessChanged?(clamped, isExternalDisplay)
        }
    }
}
