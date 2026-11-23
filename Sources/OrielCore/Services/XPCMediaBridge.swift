import Foundation

@objc public protocol OrielHelperProtocol {
    func startNowPlayingObservation()
    func stopNowPlayingObservation()
    func getNowPlayingInfo(_ reply: @escaping ([String: Any]) -> Void)
    func getNowPlayingBundle(_ reply: @escaping (String?) -> Void)
    func getIsPlaying(_ reply: @escaping (Bool) -> Void)
    func playPause()
    func nextTrack()
    func previousTrack()
    func setPlayerPosition(_ seconds: Double)
    func setShuffleMode(_ mode: Int)
    func setRepeatMode(_ mode: Int)
}

@objc public protocol OrielClientProtocol {
    func nowPlayingDidChange()
    func playbackQueueDidChange()
    func applicationDidChange()
    func applicationIsPlayingDidChange(isPlaying: Bool, bundleIdentifier: String?)
}

@MainActor
public final class XPCMediaBridge: NSObject, OrielClientProtocol {
    public static let shared = XPCMediaBridge()
    public static let helperServiceName = "com.oriel.app.helper"

    private var connection: NSXPCConnection?
    private var usingFallback = false
    private var fallbackObservers: [NSObjectProtocol] = []

    public var onNowPlayingChange: (() -> Void)?

    private override init() {
        super.init()
    }

    public func startObservation() {
        // Only try XPC when running inside an app bundle containing the XPCService
        let xpcURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/XPCServices/OrielHelper.xpc")
        if FileManager.default.fileExists(atPath: xpcURL.path) {
            connectXPC()
        } else {
            startDirectFallback()
        }
    }

    public func stopObservation() {
        if let conn = connection {
            let proxy = conn.remoteObjectProxy as? OrielHelperProtocol
            proxy?.stopNowPlayingObservation()
            conn.invalidate()
            connection = nil
        }
        for obs in fallbackObservers {
            NotificationCenter.default.removeObserver(obs)
        }
        fallbackObservers.removeAll()
    }

    private func connectXPC() {
        let conn = NSXPCConnection(serviceName: Self.helperServiceName)
        let remoteInterface = NSXPCInterface(with: OrielHelperProtocol.self)
        let allowedClasses = NSSet(array: [
            NSDictionary.self, NSArray.self, NSString.self,
            NSNumber.self, NSData.self, NSDate.self, NSURL.self
        ]) as! Set<AnyHashable>
        remoteInterface.setClasses(allowedClasses, for: #selector(OrielHelperProtocol.getNowPlayingInfo(_:)), argumentIndex: 0, ofReply: true)
        conn.remoteObjectInterface = remoteInterface
        conn.exportedInterface = NSXPCInterface(with: OrielClientProtocol.self)
        conn.exportedObject = self
        conn.invalidationHandler = { [weak self] in
            Task { @MainActor in
                self?.connection = nil
                self?.startDirectFallback()
            }
        }
        conn.interruptionHandler = { [weak self] in
            Task { @MainActor in
                self?.onNowPlayingChange?()
            }
        }
        conn.resume()
        connection = conn
        usingFallback = false

        let proxy = conn.remoteObjectProxyWithErrorHandler { [weak self] _ in
            Task { @MainActor in
                self?.startDirectFallback()
            }
        } as? OrielHelperProtocol
        proxy?.startNowPlayingObservation()
    }

    private func startDirectFallback() {
        guard !usingFallback else { return }
        usingFallback = true
        MediaRemoteBridge.registerNotifications(on: .main)
        let names = [
            "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
            "kMRMediaRemoteNowPlayingPlaybackQueueDidChangeNotification"
        ]
        for name in names {
            let token = NotificationCenter.default.addObserver(
                forName: Notification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.onNowPlayingChange?()
                }
            }
            fallbackObservers.append(token)
        }
    }

    public func fetchNowPlayingInfo(completion: @escaping @Sendable ([String: Any], String?, Bool) -> Void) {
        let once = OnceCompletion(completion)
        if let conn = connection, !usingFallback {
            guard let proxy = conn.remoteObjectProxyWithErrorHandler({ _ in
                Self.fetchDirectly(completion: { info, bid, playing in
                    once.complete(info, bid, playing)
                })
            }) as? OrielHelperProtocol else {
                once.complete([:], nil, false)
                return
            }
            // Watchdog ensures XPC stalls on macOS MediaRemote restrictions never block fallback.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                once.complete([:], nil, false)
            }
            proxy.getNowPlayingInfo { info in
                proxy.getNowPlayingBundle { bid in
                    proxy.getIsPlaying { playing in
                        once.complete(info, bid, playing)
                    }
                }
            }
        } else {
            Self.fetchDirectly { info, bid, playing in
                once.complete(info, bid, playing)
            }
        }
    }

    nonisolated private static func fetchDirectly(completion: @escaping @Sendable ([String: Any], String?, Bool) -> Void) {
        MediaRemoteBridge.fetchNowPlayingInfo { info in
            MediaRemoteBridge.fetchNowPlayingBundleID { bid in
                MediaRemoteBridge.fetchIsPlaying { playing in
                    completion(info, bid, playing)
                }
            }
        }
    }

    public func playPause() {
        if let proxy = connection?.remoteObjectProxy as? OrielHelperProtocol, !usingFallback {
            proxy.playPause()
        } else {
            MediaRemoteBridge.sendCommand(2)
        }
    }

    public func nextTrack() {
        if let proxy = connection?.remoteObjectProxy as? OrielHelperProtocol, !usingFallback {
            proxy.nextTrack()
        } else {
            MediaRemoteBridge.sendCommand(4)
        }
    }

    public func previousTrack() {
        if let proxy = connection?.remoteObjectProxy as? OrielHelperProtocol, !usingFallback {
            proxy.previousTrack()
        } else {
            MediaRemoteBridge.sendCommand(5)
        }
    }

    public func setPlayerPosition(_ seconds: Double) {
        if let proxy = connection?.remoteObjectProxy as? OrielHelperProtocol, !usingFallback {
            proxy.setPlayerPosition(seconds)
        } else {
            MediaRemoteBridge.setElapsedTime(seconds)
        }
    }

    public func setShuffleMode(_ mode: Int) {
        if let proxy = connection?.remoteObjectProxy as? OrielHelperProtocol, !usingFallback {
            proxy.setShuffleMode(mode)
        }
    }

    public func setRepeatMode(_ mode: Int) {
        if let proxy = connection?.remoteObjectProxy as? OrielHelperProtocol, !usingFallback {
            proxy.setRepeatMode(mode)
        }
    }

    // MARK: - OrielClientProtocol callbacks

    nonisolated public func nowPlayingDidChange() {
        Task { @MainActor in onNowPlayingChange?() }
    }

    nonisolated public func playbackQueueDidChange() {
        Task { @MainActor in onNowPlayingChange?() }
    }

    nonisolated public func applicationDidChange() {
        Task { @MainActor in onNowPlayingChange?() }
    }

    nonisolated public func applicationIsPlayingDidChange(isPlaying: Bool, bundleIdentifier: String?) {
        Task { @MainActor in onNowPlayingChange?() }
    }
}

private final class OnceCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false
    private let handler: @Sendable ([String: Any], String?, Bool) -> Void

    init(_ handler: @escaping @Sendable ([String: Any], String?, Bool) -> Void) {
        self.handler = handler
    }

    func complete(_ info: [String: Any], _ bundleID: String?, _ isPlaying: Bool) {
        lock.lock()
        let shouldFire = !finished
        finished = true
        lock.unlock()
        if shouldFire {
            handler(info, bundleID, isPlaying)
        }
    }
}
