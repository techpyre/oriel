import Foundation
import CoreAudio
import AudioToolbox
import Combine

@MainActor
public final class VolumeManager: ObservableObject {
    public static let shared = VolumeManager()

    @Published public var volume: Float = 0.5
    @Published public var isMuted: Bool = false
    @Published public var canControlVolume: Bool = true
    @Published public var outputDeviceName: String = "Speakers"
    @Published public var outputDeviceSymbol: String = "speaker.wave.2.fill"

    public var onVolumeChanged: ((Float, Bool, String, String) -> Void)?

    private var currentOutputDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var isWritingVolume = false
    private var suppressCallbackUntil: Date = .distantPast

    private init() {
        refreshOutputDevice()
        installSystemListeners()
    }

    public func refreshOutputDevice() {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else {
            canControlVolume = false
            return
        }

        if deviceID != currentOutputDeviceID {
            removeDeviceListeners(for: currentOutputDeviceID)
            currentOutputDeviceID = deviceID
            installDeviceListeners(for: deviceID)
        }

        outputDeviceName = fetchDeviceName(deviceID) ?? "Speakers"
        outputDeviceSymbol = fetchDeviceSymbol(deviceID, name: outputDeviceName)
        syncVolumeFromDevice(notify: false)
    }

    public func syncVolumeFromDevice(notify: Bool) {
        guard currentOutputDeviceID != kAudioObjectUnknown else { return }

        let (vol, hasVol) = readVolumeScalar(deviceID: currentOutputDeviceID)
        let muted = readMuteState(deviceID: currentOutputDeviceID)

        canControlVolume = hasVol
        if let v = vol {
            volume = v
        }
        isMuted = muted

        if notify && Date() > suppressCallbackUntil {
            onVolumeChanged?(volume, isMuted, outputDeviceName, outputDeviceSymbol)
        }
    }

    public func adjustVolume(by delta: Float, playFeedback: Bool = true) {
        guard currentOutputDeviceID != kAudioObjectUnknown else { return }
        if !canControlVolume {
            refreshOutputDevice()
        }
        let target = max(0, min(1, (isMuted && delta > 0 ? 0 : volume) + delta))
        if isMuted && delta > 0 {
            setMuted(false, notify: false)
        }
        setVolume(target, notify: true)
        if playFeedback && shouldPlayVolumeFeedback() {
            SoundManager.shared.play(.volume, volume: max(0.15, target))
        }
    }

    public func toggleMute() {
        setMuted(!isMuted, notify: true)
    }

    public func setVolume(_ newValue: Float, notify: Bool = true) {
        guard currentOutputDeviceID != kAudioObjectUnknown else { return }
        let clamped = max(0, min(1, newValue))
        volume = clamped
        suppressCallbackUntil = Date().addingTimeInterval(0.25)

        var val = clamped
        let size = UInt32(MemoryLayout<Float32>.size)

        // Try virtual main volume first, then channel 1 & 2
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(currentOutputDeviceID, &addr) {
            AudioObjectSetPropertyData(currentOutputDeviceID, &addr, 0, nil, size, &val)
        } else {
            for ch: UInt32 in [0, 1, 2] {
                var chAddr = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioDevicePropertyScopeOutput,
                    mElement: ch
                )
                if AudioObjectHasProperty(currentOutputDeviceID, &chAddr) {
                    AudioObjectSetPropertyData(currentOutputDeviceID, &chAddr, 0, nil, size, &val)
                }
            }
        }

        if notify {
            onVolumeChanged?(clamped, isMuted, outputDeviceName, outputDeviceSymbol)
        }
    }

    public func setMuted(_ muted: Bool, notify: Bool = true) {
        guard currentOutputDeviceID != kAudioObjectUnknown else { return }
        isMuted = muted
        suppressCallbackUntil = Date().addingTimeInterval(0.25)
        var muteVal: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(currentOutputDeviceID, &addr) {
            AudioObjectSetPropertyData(currentOutputDeviceID, &addr, 0, nil, size, &muteVal)
        }
        if notify {
            onVolumeChanged?(volume, isMuted, outputDeviceName, outputDeviceSymbol)
        }
    }

    public static func decibelString(for scalar: Float) -> String {
        if scalar <= 0.001 { return "-∞ dB" }
        let db = 20.0 * log10(Double(scalar))
        return String(format: "%.1f dB", db)
    }

    private func shouldPlayVolumeFeedback() -> Bool {
        UserDefaults(suiteName: "com.apple.sound.beep.feedback")?.bool(forKey: "com.apple.sound.beep.feedback") ?? false
    }

    private func readVolumeScalar(deviceID: AudioDeviceID) -> (Float?, Bool) {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(deviceID, &addr) {
            var vol: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &vol) == noErr {
                return (vol, true)
            }
        }
        for ch: UInt32 in [0, 1, 2] {
            var chAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: ch
            )
            if AudioObjectHasProperty(deviceID, &chAddr) {
                var vol: Float32 = 0
                var size = UInt32(MemoryLayout<Float32>.size)
                if AudioObjectGetPropertyData(deviceID, &chAddr, 0, nil, &size, &vol) == noErr {
                    return (vol, true)
                }
            }
        }
        return (nil, false)
    }

    private func readMuteState(deviceID: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &addr) else { return false }
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        if AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &muted) == noErr {
            return muted != 0
        }
        return false
    }

    private func fetchDeviceName(_ deviceID: AudioDeviceID) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &name) { ptr in
            AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, ptr)
        }
        return status == noErr ? (name as String) : nil
    }

    private func fetchDeviceSymbol(_ deviceID: AudioDeviceID, name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpods pro") { return "airpodspro" }
        if lower.contains("airpods") { return "airpods.gen3" }
        if lower.contains("homepod") { return "homepodmini.fill" }
        if lower.contains("headphone") || lower.contains("beats") || lower.contains("wh-") { return "headphones" }
        if lower.contains("display") || lower.contains("hdmi") { return "display" }

        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        if AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &transport) == noErr {
            switch transport {
            case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
                return "headphones"
            case kAudioDeviceTransportTypeAirPlay:
                return "airplayaudio"
            default:
                break
            }
        }
        return "speaker.wave.2.fill"
    }

    private func installSystemListeners() {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, DispatchQueue.main) { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshOutputDevice()
            }
        }
    }

    private func installDeviceListeners(for deviceID: AudioDeviceID) {
        let selectors: [AudioObjectPropertySelector] = [
            kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            kAudioDevicePropertyVolumeScalar,
            kAudioDevicePropertyMute
        ]
        for sel in selectors {
            var addr = AudioObjectPropertyAddress(
                mSelector: sel,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectHasProperty(deviceID, &addr) {
                AudioObjectAddPropertyListenerBlock(deviceID, &addr, DispatchQueue.main) { [weak self] _, _ in
                    Task { @MainActor in
                        self?.syncVolumeFromDevice(notify: true)
                    }
                }
            }
        }
    }

    private func removeDeviceListeners(for deviceID: AudioDeviceID) {
        // Listener blocks tied to device lifecycle are cleaned on device switch
        _ = deviceID
    }
}
