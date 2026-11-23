import Foundation
import CoreBluetooth
import IOBluetooth
import CoreAudio
import Combine

@MainActor
public final class ConnectivityManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    public static let shared = ConnectivityManager()

    @Published public var bluetoothAuthorized: CBManagerAuthorization = CBCentralManager.authorization
    @Published public var connectedDevices: [AudioDeviceInfo] = []
    @Published public var activeOutputDevice: AudioDeviceInfo?

    public var onDeviceConnected: ((AudioDeviceInfo) -> Void)?
    public var onLowDeviceBattery: ((AudioDeviceInfo, Int) -> Void)?

    private var centralManager: CBCentralManager?
    private var lastKnownDeviceIDs: Set<String> = []
    private var lowBatteryAlertedIDs: Set<String> = []
    private var pollTimer: Timer?

    private override init() {
        super.init()
        refreshConnectedAudioDevices(notify: false)
        installAudioRouteListener()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshConnectedAudioDevices(notify: true)
            }
        }
    }

    public func requestBluetoothPermission() {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: false])
        }
        bluetoothAuthorized = CBCentralManager.authorization
    }

    nonisolated public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            self.bluetoothAuthorized = CBCentralManager.authorization
            self.refreshConnectedAudioDevices(notify: false)
        }
    }

    public func refreshConnectedAudioDevices(notify: Bool) {
        bluetoothAuthorized = CBCentralManager.authorization
        let devices = Self.scanBluetoothAudioDevices()
        connectedDevices = devices

        let currentOutputName = VolumeManager.shared.outputDeviceName
        activeOutputDevice = devices.first(where: { $0.name == currentOutputName }) ?? devices.first

        let newIDs = Set(devices.map(\.id))
        if notify {
            for dev in devices where !lastKnownDeviceIDs.contains(dev.id) {
                onDeviceConnected?(dev)
            }
            let threshold = Int(AppSettings.shared.lowConnectBatteryThreshold)
            for dev in devices {
                if let bat = dev.effectiveBattery, bat <= threshold, !lowBatteryAlertedIDs.contains(dev.id), AppSettings.shared.warnOnLowConnectBattery {
                    lowBatteryAlertedIDs.insert(dev.id)
                    if AppSettings.shared.playSoundOnLowConnectBattery {
                        SoundManager.shared.play(.lowBattery)
                    }
                    onLowDeviceBattery?(dev, bat)
                } else if let bat = dev.effectiveBattery, bat > threshold + 5 {
                    lowBatteryAlertedIDs.remove(dev.id)
                }
            }
        }
        lastKnownDeviceIDs = newIDs
    }

    public static func symbolForDevice(name: String, modelID: String? = nil) -> (symbol: String, isAirPods: Bool) {
        let lower = (name + " " + (modelID ?? "")).lowercased()
        if lower.contains("airpods max") || lower.contains("200a") || lower.contains("201f") {
            return ("airpodsmax", true)
        }
        if lower.contains("airpods pro") || lower.contains("200e") || lower.contains("2014") || lower.contains("2024") {
            return ("airpodspro", true)
        }
        if lower.contains("airpods") || lower.contains("2013") || lower.contains("2019") || lower.contains("200f") {
            return ("airpods.gen3", true)
        }
        if lower.contains("homepod mini") || lower.contains("audioaccessory5") {
            return ("homepodmini.fill", false)
        }
        if lower.contains("homepod") || lower.contains("audioaccessory") {
            return ("homepod.fill", false)
        }
        if lower.contains("beats") {
            return ("beats.headphones", false)
        }
        return ("headphones", false)
    }

    private static func scanBluetoothAudioDevices() -> [AudioDeviceInfo] {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return [] }
        var result: [AudioDeviceInfo] = []
        for dev in paired where dev.isConnected() {
            // Audio major class = 0x04
            let isAudio = (dev.deviceClassMajor == 0x04)
            let name = dev.name ?? "Bluetooth Audio"
            let lower = name.lowercased()
            let looksAudio = isAudio || lower.contains("airpods") || lower.contains("beats") || lower.contains("headphone") || lower.contains("pods") || lower.contains("buds")
            guard looksAudio else { continue }

            let addr = dev.addressString ?? name
            let (sym, isAirPods) = symbolForDevice(name: name)

            // Read Apple battery keys via KVC if exposed by IOBluetoothDevice / IORegistry
            let left = (dev.value(forKey: "batteryPercentLeft") as? Int).flatMap { $0 >= 0 ? $0 : nil }
            let right = (dev.value(forKey: "batteryPercentRight") as? Int).flatMap { $0 >= 0 ? $0 : nil }
            let single = (dev.value(forKey: "batteryPercentSingle") as? Int).flatMap { $0 >= 0 ? $0 : nil }
            let caseBat = (dev.value(forKey: "batteryPercentCase") as? Int).flatMap { $0 >= 0 ? $0 : nil }

            result.append(AudioDeviceInfo(
                id: addr,
                name: name,
                modelIdentifier: nil,
                symbolName: sym,
                transportType: "Bluetooth",
                batterySingle: single,
                batteryLeft: left,
                batteryRight: right,
                batteryCase: caseBat,
                isAirPods: isAirPods
            ))
        }
        return result
    }

    private func installAudioRouteListener() {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, DispatchQueue.main) { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshConnectedAudioDevices(notify: true)
            }
        }
    }

    // Regex parser for OutputContext protobuf logs (like Oriel's ConnectivityManager)
    public static func parseOutputContextLog(_ text: String) -> (name: String, clusterSize: Int, model: String?)? {
        guard text.contains("[OutputContext]") || text.contains("OutputDevice") else { return nil }
        let namePattern = #"name\s*=\s*"([^"]+)";"#
        let clusterPattern = #"configuredClusterSize\s*=\s*([0-9]+);"#
        let modelPattern = #"(AudioAccessory[0-9]+,[0-9]+)"#

        let name = firstMatch(in: text, pattern: namePattern)
        guard let deviceName = name else { return nil }
        let size = firstMatch(in: text, pattern: clusterPattern).flatMap(Int.init) ?? 1
        let model = firstMatch(in: text, pattern: modelPattern)
        return (deviceName, size, model)
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let r = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[r])
    }
}
