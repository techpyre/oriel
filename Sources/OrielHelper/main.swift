import Foundation

@objc protocol OrielHelperProtocol {
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

@objc protocol OrielClientProtocol {
    func nowPlayingDidChange()
    func playbackQueueDidChange()
    func applicationDidChange()
    func applicationIsPlayingDidChange(isPlaying: Bool, bundleIdentifier: String?)
}

private enum MR {
    static let handle: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
        RTLD_LAZY
    )

    typealias RegisterFn = @convention(c) (DispatchQueue) -> Void
    typealias UnregisterFn = @convention(c) () -> Void
    typealias GetInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]?) -> Void) -> Void
    typealias GetIsPlayingFn = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    typealias SendCommandFn = @convention(c) (UInt32, CFDictionary?) -> Bool
    typealias SetElapsedTimeFn = @convention(c) (Double) -> Void
    typealias SetShuffleFn = @convention(c) (Int32) -> Void
    typealias SetRepeatFn = @convention(c) (Int32) -> Void
    typealias GetClientFn = @convention(c) (DispatchQueue, @escaping (AnyObject?) -> Void) -> Void
    typealias ClientBundleIDFn = @convention(c) (AnyObject) -> CFString?
    typealias QueueReqCreateFn = @convention(c) (Int, Int) -> AnyObject?
    typealias QueueReqSetArtFn = @convention(c) (AnyObject, Bool) -> Void
    typealias RequestQueueFn = @convention(c) (AnyObject, AnyObject?, DispatchQueue, @escaping (AnyObject?, AnyObject?) -> Void) -> Void
    typealias QueueGetItemFn = @convention(c) (AnyObject, Int) -> AnyObject?
    typealias GetOriginFn = @convention(c) () -> AnyObject?
    typealias PlayerPathCreateFn = @convention(c) (AnyObject?, AnyObject?, AnyObject?) -> AnyObject?

    static let register: RegisterFn? = load("MRMediaRemoteRegisterForNowPlayingNotifications")
    static let unregister: UnregisterFn? = load("MRMediaRemoteUnregisterForNowPlayingNotifications")
    static let getInfo: GetInfoFn? = load("MRMediaRemoteGetNowPlayingInfo")
    static let getIsPlaying: GetIsPlayingFn? = load("MRMediaRemoteGetNowPlayingApplicationIsPlaying")
    static let sendCommand: SendCommandFn? = load("MRMediaRemoteSendCommand")
    static let setElapsed: SetElapsedTimeFn? = load("MRMediaRemoteSetElapsedTime")
    static let setShuffle: SetShuffleFn? = load("MRMediaRemoteSetShuffleMode")
    static let setRepeat: SetRepeatFn? = load("MRMediaRemoteSetRepeatMode")
    static let getClient: GetClientFn? = load("MRMediaRemoteGetNowPlayingClient")
    static let clientBundleID: ClientBundleIDFn? = load("MRNowPlayingClientGetBundleIdentifier")
    static let queueReqCreate: QueueReqCreateFn? = load("MRPlaybackQueueRequestCreate")
    static let queueReqSetArt: QueueReqSetArtFn? = load("MRPlaybackQueueRequestSetIncludeArtwork")
    static let requestQueue: RequestQueueFn? = load("MRMediaRemoteRequestNowPlayingPlaybackQueueForPlayer")
    static let queueGetItem: QueueGetItemFn? = load("MRPlaybackQueueGetContentItemAtOffset")
    static let getLocalOrigin: GetOriginFn? = load("MRMediaRemoteGetLocalOrigin")
    static let playerPathCreate: PlayerPathCreateFn? = load("MRNowPlayingPlayerPathCreate")

    static func load<T>(_ name: String) -> T? {
        guard let h = handle, let sym = dlsym(h, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }
}

final class HelperService: NSObject, OrielHelperProtocol {
    weak var connection: NSXPCConnection?
    private var observers: [NSObjectProtocol] = []

    func startNowPlayingObservation() {
        stopNowPlayingObservation()
        MR.register?(.main)

        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: Notification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"), object: nil, queue: .main) { [weak self] _ in
            (self?.connection?.remoteObjectProxy as? OrielClientProtocol)?.nowPlayingDidChange()
        })
        observers.append(nc.addObserver(forName: Notification.Name("kMRMediaRemoteNowPlayingPlaybackQueueDidChangeNotification"), object: nil, queue: .main) { [weak self] _ in
            (self?.connection?.remoteObjectProxy as? OrielClientProtocol)?.playbackQueueDidChange()
        })
        observers.append(nc.addObserver(forName: Notification.Name("kMRMediaRemoteNowPlayingApplicationDidChangeNotification"), object: nil, queue: .main) { [weak self] _ in
            (self?.connection?.remoteObjectProxy as? OrielClientProtocol)?.applicationDidChange()
        })
        observers.append(nc.addObserver(forName: Notification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"), object: nil, queue: .main) { [weak self] note in
            let isPlaying = (note.userInfo?["kMRMediaRemoteNowPlayingApplicationIsPlayingUserInfoKey"] as? Bool) ?? false
            (self?.connection?.remoteObjectProxy as? OrielClientProtocol)?.applicationIsPlayingDidChange(isPlaying: isPlaying, bundleIdentifier: nil)
        })
    }

    func stopNowPlayingObservation() {
        for o in observers {
            NotificationCenter.default.removeObserver(o)
        }
        observers.removeAll()
        MR.unregister?()
    }

    func getNowPlayingInfo(_ reply: @escaping ([String: Any]) -> Void) {
        guard let fn = MR.getInfo else {
            reply([:])
            return
        }
        fn(.main) { dict in
            var sanitized: [String: Any] = [:]
            for (k, v) in (dict ?? [:]) {
                if v is NSString || v is NSNumber || v is NSData || v is NSDate || v is NSURL {
                    sanitized[k] = v
                }
            }
            if let existing = sanitized["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data, !existing.isEmpty {
                reply(sanitized)
                return
            }
            guard !sanitized.isEmpty else {
                reply(sanitized)
                return
            }
            self.fetchPlaybackQueueArtwork { artData in
                if let artData, !artData.isEmpty {
                    sanitized["kMRMediaRemoteNowPlayingInfoArtworkData"] = artData
                }
                reply(sanitized)
            }
        }
    }

    private func fetchPlaybackQueueArtwork(completion: @escaping (Data?) -> Void) {
        guard let getClient = MR.getClient,
              let getOrigin = MR.getLocalOrigin,
              let pathCreate = MR.playerPathCreate,
              let reqCreate = MR.queueReqCreate,
              let reqSetArt = MR.queueReqSetArt,
              let reqQueue = MR.requestQueue,
              let getItem = MR.queueGetItem else {
            completion(nil)
            return
        }
        getClient(.main) { client in
            guard let client else {
                completion(nil)
                return
            }
            let origin = getOrigin()
            let path = pathCreate(origin, client, nil)
            guard let req = reqCreate(0, 1) else {
                completion(nil)
                return
            }
            reqSetArt(req, true)
            if (req as? NSObject)?.responds(to: NSSelectorFromString("setArtworkWidth:")) == true {
                (req as? NSObject)?.setValue(600.0, forKey: "artworkWidth")
                (req as? NSObject)?.setValue(600.0, forKey: "artworkHeight")
            }
            reqQueue(req, path, .main) { playbackQueue, _ in
                guard let q = playbackQueue,
                      let item = getItem(q, 0) as? NSObject,
                      let artwork = item.value(forKey: "artwork") as? NSObject,
                      let data = artwork.value(forKey: "imageData") as? Data,
                      !data.isEmpty else {
                    completion(nil)
                    return
                }
                completion(data)
            }
        }
    }

    func getNowPlayingBundle(_ reply: @escaping (String?) -> Void) {
        guard let getClient = MR.getClient, let getBID = MR.clientBundleID else {
            reply(nil)
            return
        }
        getClient(.main) { client in
            guard let client else {
                reply(nil)
                return
            }
            reply(getBID(client) as String?)
        }
    }

    func getIsPlaying(_ reply: @escaping (Bool) -> Void) {
        guard let fn = MR.getIsPlaying else {
            reply(false)
            return
        }
        fn(.main) { playing in
            reply(playing)
        }
    }

    func playPause() { _ = MR.sendCommand?(2, nil) }
    func nextTrack() { _ = MR.sendCommand?(4, nil) }
    func previousTrack() { _ = MR.sendCommand?(5, nil) }
    func setPlayerPosition(_ seconds: Double) { MR.setElapsed?(seconds) }
    func setShuffleMode(_ mode: Int) { MR.setShuffle?(Int32(mode)) }
    func setRepeatMode(_ mode: Int) { MR.setRepeat?(Int32(mode)) }
}

final class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        let exportedInterface = NSXPCInterface(with: OrielHelperProtocol.self)
        let allowed = NSSet(array: [
            NSDictionary.self, NSArray.self, NSString.self,
            NSNumber.self, NSData.self, NSDate.self, NSURL.self
        ]) as! Set<AnyHashable>
        exportedInterface.setClasses(allowed, for: #selector(OrielHelperProtocol.getNowPlayingInfo(_:)), argumentIndex: 0, ofReply: true)
        newConnection.exportedInterface = exportedInterface

        let helper = HelperService()
        helper.connection = newConnection
        newConnection.exportedObject = helper
        newConnection.remoteObjectInterface = NSXPCInterface(with: OrielClientProtocol.self)
        newConnection.invalidationHandler = {
            helper.stopNowPlayingObservation()
        }
        newConnection.resume()
        return true
    }
}

let delegate = ServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
