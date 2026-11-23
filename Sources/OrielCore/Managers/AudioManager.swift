import Foundation
import AppKit
import Combine

@MainActor
public final class AudioManager: ObservableObject {
    public static let shared = AudioManager()

    @Published public var authorizationStatus: TCCBridge.Status = .notDetermined
    @Published public var liveLevels: [CGFloat] = []
    @Published public var isTapActive: Bool = false

    private var spectrumTap: NSObject?
    private var spectrumAnalyzer: NSObject?
    private var spectrumObserver: NSObject?
    private var attachedPID: pid_t = 0
    private var frequencyBands: [NSObject] = []
    private var lastLivePublishTime: CFTimeInterval = 0

    private static var hasLoadedPrivateFrameworks = false

    private init() {
        refreshPermissionStatus()
    }

    public func refreshPermissionStatus() {
        let next = TCCBridge.audioCaptureStatus()
        if authorizationStatus != next {
            authorizationStatus = next
        }
    }

    public func requestPermission() {
        TCCBridge.requestAudioCapture { [weak self] granted in
            Task { @MainActor in
                self?.authorizationStatus = granted ? .authorized : .denied
            }
        }
    }

    public func updateSpectrumTracking(isPlaying: Bool, pid: pid_t) {
        refreshPermissionStatus()
        guard isPlaying else {
            stopTap()
            if !liveLevels.isEmpty {
                liveLevels = []
            }
            return
        }

        if AppSettings.shared.useLiveWaveform && authorizationStatus == .authorized && pid > 0 {
            if attachedPID != pid || !isTapActive {
                startLiveTap(for: pid)
            }
        } else if !liveLevels.isEmpty {
            // Let isolated WaveformView drive organic motion locally without global @Published spam
            liveLevels = []
        }
    }

    private func loadMediaPlaybackCore() -> Bool {
        if Self.hasLoadedPrivateFrameworks { return true }
        let mpc = dlopen("/System/Library/PrivateFrameworks/MediaPlaybackCore.framework/MediaPlaybackCore", RTLD_LAZY)
        let mcui = dlopen("/System/Library/PrivateFrameworks/MediaCoreUI.framework/MediaCoreUI", RTLD_LAZY)
        Self.hasLoadedPrivateFrameworks = (mpc != nil || mcui != nil)
        return Self.hasLoadedPrivateFrameworks
    }

    private func startLiveTap(for pid: pid_t) {
        stopTap()
        guard loadMediaPlaybackCore(),
              let tapCls = NSClassFromString("MPCProcessAudioTap") as? NSObject.Type,
              let analyzerCls = NSClassFromString("MPCAudioSpectrumAnalyzer") as? NSObject.Type,
              let observerCls = NSClassFromString("MPCAudioSpectrumObserver") as? NSObject.Type else {
            return
        }

        // Attempt initWithPID:refreshRate:numberOfChannels:delegate:
        let tapSel = NSSelectorFromString("initWithPID:refreshRate:numberOfChannels:delegate:")
        let allocTap = tapCls.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue() as? NSObject
        guard let tapAlloc = allocTap, tapAlloc.responds(to: tapSel) else { return }

        typealias InitTapIMP = @convention(c) (AnyObject, Selector, Int32, Int32, UInt32, AnyObject?) -> AnyObject?
        let imp = unsafeBitCast(tapAlloc.method(for: tapSel), to: InitTapIMP.self)
        guard let tapObj = imp(tapAlloc, tapSel, pid, 30, 2, nil) as? NSObject else { return }

        let analyzerAlloc = analyzerCls.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue() as? NSObject
        let analyzerInitSel = NSSelectorFromString("initWithPlaybackEngine:refreshRate:")
        guard let analyzerAlloc, analyzerAlloc.responds(to: analyzerInitSel) else { return }

        typealias InitAnalyzerIMP = @convention(c) (AnyObject, Selector, AnyObject?, Int32) -> AnyObject?
        let analyzerImp = unsafeBitCast(analyzerAlloc.method(for: analyzerInitSel), to: InitAnalyzerIMP.self)
        guard let analyzerObj = analyzerImp(analyzerAlloc, analyzerInitSel, nil, 30) as? NSObject else { return }

        let setTapSel = NSSelectorFromString("setProcessAudioTap:")
        if analyzerObj.responds(to: setTapSel) {
            analyzerObj.perform(setTapSel, with: tapObj)
        }

        let observerObj = observerCls.init()
        let onUpdateSel = NSSelectorFromString("setOnUpdate:")
        if observerObj.responds(to: onUpdateSel) {
            let block: @convention(block) (NSArray?) -> Void = { [weak self] bands in
                guard let bands else { return }
                var levels: [CGFloat] = []
                for idx in 0..<min(6, bands.count) {
                    if let val = (bands[idx] as? NSNumber)?.doubleValue {
                        let normalized = CGFloat(max(0.14, min(1.0, (val + 55.0) / 55.0)))
                        levels.append(normalized)
                    }
                }
                while levels.count < 6 { levels.append(0.18) }
                Task { @MainActor in
                    guard let self else { return }
                    let now = CFAbsoluteTimeGetCurrent()
                    guard now - self.lastLivePublishTime >= (1.0 / 15.0) else { return }
                    self.lastLivePublishTime = now
                    self.liveLevels = levels
                }
            }
            observerObj.perform(onUpdateSel, with: block)
        }

        let addObserverSel = NSSelectorFromString("addObserver:")
        if analyzerObj.responds(to: addObserverSel) {
            analyzerObj.perform(addObserverSel, with: observerObj)
        }
        let startSel = NSSelectorFromString("start")
        if tapObj.responds(to: startSel) {
            tapObj.perform(startSel)
        }

        self.spectrumTap = tapObj
        self.spectrumAnalyzer = analyzerObj
        self.spectrumObserver = observerObj
        self.attachedPID = pid
        self.isTapActive = true
    }

    public func stopTap() {
        if let tap = spectrumTap {
            let stopSel = NSSelectorFromString("stop")
            if tap.responds(to: stopSel) {
                tap.perform(stopSel)
            }
        }
        if let analyzer = spectrumAnalyzer, let obs = spectrumObserver {
            let remSel = NSSelectorFromString("removeObserver:")
            if analyzer.responds(to: remSel) {
                analyzer.perform(remSel, with: obs)
            }
        }
        spectrumTap = nil
        spectrumAnalyzer = nil
        spectrumObserver = nil
        attachedPID = 0
        isTapActive = false
    }
}
