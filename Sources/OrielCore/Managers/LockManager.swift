import Foundation
import AppKit
import IOKit.pwr_mgt
import Combine

@MainActor
public final class SpaceManager {
    public private(set) var spaceID: UInt64?

    public init(level: Int32 = 400) {
        self.spaceID = SkyLightBridge.createSpace(level: level)
    }

    public func attach(window: NSWindow) {
        guard let spaceID, window.windowNumber > 0 else { return }
        SkyLightBridge.addWindow(window.windowNumber, toSpace: spaceID)
    }

    public func detach(window: NSWindow) {
        guard let spaceID, window.windowNumber > 0 else { return }
        SkyLightBridge.removeWindow(window.windowNumber, fromSpace: spaceID)
    }

    deinit {
        if let spaceID {
            SkyLightBridge.destroySpace(spaceID)
        }
    }
}

@MainActor
public final class LockManager: ObservableObject {
    public static let shared = LockManager()

    @Published public var isLocked: Bool = false
    @Published public var isScreensaverActive: Bool = false

    public var onLockStateChanged: ((Bool) -> Void)?

    private var distributedObservers: [NSObjectProtocol] = []
    private var keepAwakeAssertionID: IOPMAssertionID = 0
    private var hasKeepAwakeAssertion = false

    private init() {
        isLocked = SkyLightBridge.isScreenLocked()
        setupObservers()
    }

    private func setupObservers() {
        let dnc = DistributedNotificationCenter.default()

        distributedObservers.append(
            dnc.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.handleLocked() }
            }
        )
        distributedObservers.append(
            dnc.addObserver(forName: Notification.Name("com.apple.screenLockUIIsShown"), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.handleLocked() }
            }
        )
        distributedObservers.append(
            dnc.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.handleUnlocked() }
            }
        )
        distributedObservers.append(
            dnc.addObserver(forName: Notification.Name("com.apple.screenLockUIIsHidden"), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.handleUnlocked() }
            }
        )
        distributedObservers.append(
            dnc.addObserver(forName: Notification.Name("com.apple.screensaver.didstart"), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.isScreensaverActive = true
                    if AppSettings.shared.showOnScreenSaver {
                        self?.onLockStateChanged?(true)
                    }
                }
            }
        )
        distributedObservers.append(
            dnc.addObserver(forName: Notification.Name("com.apple.screensaver.didstop"), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.isScreensaverActive = false
                    if !(self?.isLocked ?? false) {
                        self?.onLockStateChanged?(false)
                    }
                }
            }
        )
    }

    private func handleLocked() {
        guard !isLocked else { return }
        isLocked = true
        if AppSettings.shared.playSoundOnLock {
            SoundManager.shared.play(.lock)
        }
        updateKeepAwakeAssertion()
        onLockStateChanged?(true)
    }

    private func handleUnlocked() {
        guard isLocked else { return }
        isLocked = false
        if AppSettings.shared.playSoundOnUnlock {
            SoundManager.shared.play(.unlock)
        }
        releaseKeepAwakeAssertion()
        onLockStateChanged?(false)
    }

    public func updateKeepAwakeAssertion() {
        if isLocked && AppSettings.shared.enableLockScreen && AppSettings.shared.keepAwake {
            guard !hasKeepAwakeAssertion else { return }
            let reason = "Oriel Lock Screen Widgets" as CFString
            let err = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &keepAwakeAssertionID
            )
            hasKeepAwakeAssertion = (err == kIOReturnSuccess)
        } else {
            releaseKeepAwakeAssertion()
        }
    }

    private func releaseKeepAwakeAssertion() {
        guard hasKeepAwakeAssertion else { return }
        IOPMAssertionRelease(keepAwakeAssertionID)
        keepAwakeAssertionID = 0
        hasKeepAwakeAssertion = false
    }
}
