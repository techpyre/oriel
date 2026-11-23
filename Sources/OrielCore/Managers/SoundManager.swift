import Foundation
import AppKit
import AVFoundation

@MainActor
public final class SoundManager: NSObject, AVAudioPlayerDelegate {
    public static let shared = SoundManager()

    public enum SoundEffect: String, CaseIterable, Sendable {
        case chime
        case event
        case haptic
        case lock
        case unlock
        case lowBattery = "low-battery"
        case lowPower = "low-power"
        case sleep
        case volume
        case directions
    }

    private var cachedURLs: [SoundEffect: URL] = [:]
    private var preloadedPlayers: [SoundEffect: [AVAudioPlayer]] = [:]
    private var fallbackSounds: [SoundEffect: NSSound] = [:]
    private var lastVolumeTickAt: CFTimeInterval = 0
    private let defaultVolume: Float = 0.5

    private override init() {
        super.init()
        preloadAllSounds()
    }

    private func preloadAllSounds() {
        let exts = ["caf", "wav", "m4a", "aiff"]
        for effect in SoundEffect.allCases {
            for ext in exts {
                if let url = Bundle.main.url(forResource: effect.rawValue, withExtension: ext) {
                    cachedURLs[effect] = url
                    if let p1 = try? AVAudioPlayer(contentsOf: url),
                       let p2 = try? AVAudioPlayer(contentsOf: url) {
                        p1.prepareToPlay()
                        p2.prepareToPlay()
                        preloadedPlayers[effect] = [p1, p2]
                    }
                    break
                }
            }
            if cachedURLs[effect] == nil {
                switch effect {
                case .lock: fallbackSounds[effect] = NSSound(named: "Tink")
                case .unlock: fallbackSounds[effect] = NSSound(named: "Pop")
                case .lowBattery, .lowPower: fallbackSounds[effect] = NSSound(named: "Basso")
                case .chime, .event, .directions: fallbackSounds[effect] = NSSound(named: "Glass")
                case .sleep: fallbackSounds[effect] = NSSound(named: "Purr")
                case .volume:
                    let path = "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff"
                    if FileManager.default.fileExists(atPath: path) {
                        let url = URL(fileURLWithPath: path)
                        cachedURLs[effect] = url
                        if let p1 = try? AVAudioPlayer(contentsOf: url) {
                            p1.prepareToPlay()
                            preloadedPlayers[effect] = [p1]
                        }
                    }
                case .haptic:
                    break
                }
            }
        }
    }

    public func play(_ effect: SoundEffect, volume: Float? = nil) {
        if effect == .volume {
            let now = CFAbsoluteTimeGetCurrent()
            if now - lastVolumeTickAt < 0.045 { return }
            lastVolumeTickAt = now
        }

        let targetVol = volume ?? defaultVolume
        if let pool = preloadedPlayers[effect] {
            if let idle = pool.first(where: { !$0.isPlaying }) ?? pool.first {
                idle.volume = targetVol
                idle.currentTime = 0
                idle.play()
                return
            }
        }
        if let url = cachedURLs[effect], let player = try? AVAudioPlayer(contentsOf: url) {
            player.volume = targetVol
            player.play()
            return
        }
        if let snd = fallbackSounds[effect] {
            snd.stop()
            snd.play()
        }
    }
}
