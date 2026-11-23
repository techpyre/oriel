import Foundation
import IOKit.ps
import Combine

@MainActor
public final class BatteryManager: ObservableObject {
    public static let shared = BatteryManager()

    @Published public var batteryLevel: Int = 100
    @Published public var isCharging: Bool = false
    @Published public var isPluggedIn: Bool = false
    @Published public var isLowPowerModeEnabled: Bool = false
    @Published public var remainingMinutes: Int? = nil

    public var onChargingConnected: ((Int) -> Void)?
    public var onLowBattery: ((Int) -> Void)?
    public var onLowPowerModeActivated: (() -> Void)?

    private var powerSourceRunLoopSource: CFRunLoopSource?
    private var lowPowerObserver: NSObjectProtocol?
    private var hasNotifiedLowThreshold = false
    private var previousPluggedIn: Bool?

    private init() {
        refreshBatteryState(notify: false)
        installPowerSourceObserver()
    }

    public func refreshBatteryState(notify: Bool) {
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        if notify && lowPower && !isLowPowerModeEnabled && AppSettings.shared.notifyOnLowPowerMode {
            onLowPowerModeActivated?()
        }
        isLowPowerModeEnabled = lowPower

        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }

        for src in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, src)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            if let type = desc[kIOPSTypeKey] as? String, type == kIOPSInternalBatteryType {
                let currentCap = (desc[kIOPSCurrentCapacityKey] as? Int) ?? 100
                let maxCap = (desc[kIOPSMaxCapacityKey] as? Int) ?? 100
                let pct = maxCap > 0 ? Int((Double(currentCap) / Double(maxCap)) * 100.0) : currentCap
                let charging = (desc[kIOPSIsChargingKey] as? Bool) ?? false
                let powerState = (desc[kIOPSPowerSourceStateKey] as? String) ?? ""
                let plugged = (powerState == kIOPSACPowerValue)
                let timeToEmpty = desc[kIOPSTimeToEmptyKey] as? Int

                batteryLevel = max(0, min(100, pct))
                isCharging = charging
                isPluggedIn = plugged
                remainingMinutes = (timeToEmpty ?? -1) > 0 ? timeToEmpty : nil

                if notify {
                    if let prev = previousPluggedIn, !prev && plugged {
                        onChargingConnected?(batteryLevel)
                        hasNotifiedLowThreshold = false
                    }
                    let threshold = Int(AppSettings.shared.lowBatteryThreshold)
                    if !plugged && batteryLevel <= threshold && !hasNotifiedLowThreshold && AppSettings.shared.warnOnLowBattery {
                        hasNotifiedLowThreshold = true
                        if AppSettings.shared.playSoundOnLowBattery {
                            SoundManager.shared.play(.lowBattery)
                        }
                        onLowBattery?(batteryLevel)
                    } else if batteryLevel > threshold + 5 {
                        hasNotifiedLowThreshold = false
                    }
                }
                previousPluggedIn = plugged
                break
            }
        }
    }

    private func installPowerSourceObserver() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        if let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let manager = Unmanaged<BatteryManager>.fromOpaque(ctx).takeUnretainedValue()
            Task { @MainActor in
                manager.refreshBatteryState(notify: true)
            }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            powerSourceRunLoopSource = source
        }

        lowPowerObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshBatteryState(notify: true)
            }
        }
    }
}
