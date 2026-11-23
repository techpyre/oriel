import Foundation
import AppKit
import QuartzCore

// MARK: - SkyLight / CoreGraphics Private Space & Session APIs

public enum SkyLightBridge {
    private static let cgHandle: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
        RTLD_LAZY
    )

    private typealias CGSMainConnectionIDFn = @convention(c) () -> Int32
    private typealias CGSSpaceCreateFn = @convention(c) (Int32, Int32, CFDictionary?) -> UInt64
    private typealias CGSSpaceSetAbsoluteLevelFn = @convention(c) (Int32, UInt64, Int32) -> Int32
    private typealias CGSSpaceDestroyFn = @convention(c) (Int32, UInt64) -> Int32
    private typealias CGSAddWindowsToSpacesFn = @convention(c) (Int32, CFArray, CFArray) -> Int32
    private typealias CGSRemoveWindowsFromSpacesFn = @convention(c) (Int32, CFArray, CFArray) -> Int32
    private typealias CGSShowSpacesFn = @convention(c) (Int32, CFArray) -> Int32
    private typealias CGSHideSpacesFn = @convention(c) (Int32, CFArray) -> Int32
    private typealias CGSCopyManagedDisplaySpacesFn = @convention(c) (Int32) -> CFArray?
    private typealias CGSessionCopyCurrentDictionaryFn = @convention(c) () -> CFDictionary?

    private static let _mainConn: CGSMainConnectionIDFn? = load("CGSMainConnectionID")
    private static let _spaceCreate: CGSSpaceCreateFn? = load("CGSSpaceCreate")
    private static let _spaceSetLevel: CGSSpaceSetAbsoluteLevelFn? = load("CGSSpaceSetAbsoluteLevel")
    private static let _spaceDestroy: CGSSpaceDestroyFn? = load("CGSSpaceDestroy")
    private static let _addWindows: CGSAddWindowsToSpacesFn? = load("CGSAddWindowsToSpaces")
    private static let _removeWindows: CGSRemoveWindowsFromSpacesFn? = load("CGSRemoveWindowsFromSpaces")
    private static let _showSpaces: CGSShowSpacesFn? = load("CGSShowSpaces")
    private static let _hideSpaces: CGSHideSpacesFn? = load("CGSHideSpaces")
    private static let _copyDisplaySpaces: CGSCopyManagedDisplaySpacesFn? = load("CGSCopyManagedDisplaySpaces")
    private static let _sessionDict: CGSessionCopyCurrentDictionaryFn? = load("CGSessionCopyCurrentDictionary")

    private static func load<T>(_ name: String) -> T? {
        guard let h = cgHandle, let sym = dlsym(h, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    public static func mainConnectionID() -> Int32 {
        _mainConn?() ?? 0
    }

    public static func createSpace(level: Int32 = 400) -> UInt64? {
        let conn = mainConnectionID()
        guard conn != 0, let create = _spaceCreate else { return nil }
        let space = create(conn, 1, nil)
        guard space != 0 else { return nil }
        _ = _spaceSetLevel?(conn, space, level)
        _ = _showSpaces?(conn, [NSNumber(value: space)] as CFArray)
        return space
    }

    public static func destroySpace(_ spaceID: UInt64) {
        let conn = mainConnectionID()
        guard conn != 0 else { return }
        _ = _hideSpaces?(conn, [NSNumber(value: spaceID)] as CFArray)
        _ = _spaceDestroy?(conn, spaceID)
    }

    public static func addWindow(_ windowNumber: Int, toSpace spaceID: UInt64) {
        let conn = mainConnectionID()
        guard conn != 0, windowNumber > 0, spaceID != 0 else { return }
        _ = _addWindows?(
            conn,
            [NSNumber(value: windowNumber)] as CFArray,
            [NSNumber(value: spaceID)] as CFArray
        )
    }

    public static func removeWindow(_ windowNumber: Int, fromSpace spaceID: UInt64) {
        let conn = mainConnectionID()
        guard conn != 0, windowNumber > 0, spaceID != 0 else { return }
        _ = _removeWindows?(
            conn,
            [NSNumber(value: windowNumber)] as CFArray,
            [NSNumber(value: spaceID)] as CFArray
        )
    }

    public static func isScreenLocked() -> Bool {
        guard let dict = _sessionDict?() as? [String: Any] else { return false }
        return (dict["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }

    public static func managedDisplaySpaces() -> [[String: Any]] {
        let conn = mainConnectionID()
        guard conn != 0, let arr = _copyDisplaySpaces?(conn) as? [[String: Any]] else { return [] }
        return arr
    }
}

// MARK: - DisplayServices Private Brightness API

public enum DisplayServicesBridge {
    private static let handle: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
        RTLD_LAZY
    )

    private typealias CanChangeFn = @convention(c) (UInt32) -> Bool
    private typealias GetBrightnessFn = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightnessFn = @convention(c) (UInt32, Float) -> Int32
    private typealias SetBrightnessSmoothFn = @convention(c) (UInt32, Float) -> Int32

    private static let _canChange: CanChangeFn? = load("DisplayServicesCanChangeBrightness")
    private static let _get: GetBrightnessFn? = load("DisplayServicesGetBrightness")
    private static let _set: SetBrightnessFn? = load("DisplayServicesSetBrightness")
    private static let _setSmooth: SetBrightnessSmoothFn? = load("DisplayServicesSetBrightnessSmooth")

    private static func load<T>(_ name: String) -> T? {
        guard let h = handle, let sym = dlsym(h, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    public static func canChangeBrightness(displayID: CGDirectDisplayID) -> Bool {
        _canChange?(displayID) ?? false
    }

    public static func getBrightness(displayID: CGDirectDisplayID) -> Float? {
        guard let get = _get else { return nil }
        var val: Float = 0
        let err = get(displayID, &val)
        return err == 0 ? val : nil
    }

    @discardableResult
    public static func setBrightness(displayID: CGDirectDisplayID, value: Float, smooth: Bool = true) -> Bool {
        let clamped = max(0, min(1, value))
        if smooth, let smoothFn = _setSmooth {
            if smoothFn(displayID, clamped) == 0 { return true }
        }
        if let setFn = _set {
            return setFn(displayID, clamped) == 0
        }
        return false
    }
}

// MARK: - TCC Audio Capture Permission Bridge

public enum TCCBridge {
    private static let handle: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/PrivateFrameworks/TCC.framework/TCC",
        RTLD_LAZY
    )

    private typealias PreflightFn = @convention(c) (CFString, CFDictionary?) -> Int
    private typealias RequestFn = @convention(c) (CFString, CFDictionary?, @escaping (Bool) -> Void) -> Void

    private static let _preflight: PreflightFn? = {
        guard let h = handle, let sym = dlsym(h, "TCCAccessPreflight") else { return nil }
        return unsafeBitCast(sym, to: PreflightFn.self)
    }()

    private static let _request: RequestFn? = {
        guard let h = handle, let sym = dlsym(h, "TCCAccessRequest") else { return nil }
        return unsafeBitCast(sym, to: RequestFn.self)
    }()

    public enum Status: Sendable {
        case authorized
        case denied
        case notDetermined
    }

    public static func audioCaptureStatus() -> Status {
        guard let fn = _preflight else { return .notDetermined }
        let res = fn("kTCCServiceAudioCapture" as CFString, nil)
        // 0 = granted, 1 = denied, 2 = unknown/not determined
        switch res {
        case 0: return .authorized
        case 1: return .denied
        default: return .notDetermined
        }
    }

    public static func requestAudioCapture(completion: @escaping @Sendable (Bool) -> Void) {
        guard let fn = _request else {
            completion(false)
            return
        }
        fn("kTCCServiceAudioCapture" as CFString, nil) { granted in
            completion(granted)
        }
    }
}

// MARK: - MediaRemote Direct Dynamic Bridge (Fallback + Helper Support)

public enum MediaRemoteBridge {
    private static let handle: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
        RTLD_LAZY
    )

    private typealias RegisterFn = @convention(c) (DispatchQueue) -> Void
    private typealias UnregisterFn = @convention(c) () -> Void
    private typealias GetInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]?) -> Void) -> Void
    private typealias GetIsPlayingFn = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    private typealias SendCommandFn = @convention(c) (UInt32, CFDictionary?) -> Bool
    private typealias SetElapsedTimeFn = @convention(c) (Double) -> Void
    private typealias GetNowPlayingClientFn = @convention(c) (DispatchQueue, @escaping (AnyObject?) -> Void) -> Void
    private typealias ClientBundleIDFn = @convention(c) (AnyObject) -> CFString?
    private typealias QueueReqCreateFn = @convention(c) (Int, Int) -> AnyObject?
    private typealias QueueReqSetArtFn = @convention(c) (AnyObject, Bool) -> Void
    private typealias RequestQueueFn = @convention(c) (AnyObject, AnyObject?, DispatchQueue, @escaping (AnyObject?, AnyObject?) -> Void) -> Void
    private typealias QueueGetItemFn = @convention(c) (AnyObject, Int) -> AnyObject?
    private typealias GetOriginFn = @convention(c) () -> AnyObject?
    private typealias PlayerPathCreateFn = @convention(c) (AnyObject?, AnyObject?, AnyObject?) -> AnyObject?

    private static let _register: RegisterFn? = load("MRMediaRemoteRegisterForNowPlayingNotifications")
    private static let _unregister: UnregisterFn? = load("MRMediaRemoteUnregisterForNowPlayingNotifications")
    private static let _getInfo: GetInfoFn? = load("MRMediaRemoteGetNowPlayingInfo")
    private static let _getIsPlaying: GetIsPlayingFn? = load("MRMediaRemoteGetNowPlayingApplicationIsPlaying")
    private static let _sendCommand: SendCommandFn? = load("MRMediaRemoteSendCommand")
    private static let _setElapsed: SetElapsedTimeFn? = load("MRMediaRemoteSetElapsedTime")
    private static let _getClient: GetNowPlayingClientFn? = load("MRMediaRemoteGetNowPlayingClient")
    private static let _clientBundleID: ClientBundleIDFn? = load("MRNowPlayingClientGetBundleIdentifier")
    private static let _queueReqCreate: QueueReqCreateFn? = load("MRPlaybackQueueRequestCreate")
    private static let _queueReqSetArt: QueueReqSetArtFn? = load("MRPlaybackQueueRequestSetIncludeArtwork")
    private static let _requestQueue: RequestQueueFn? = load("MRMediaRemoteRequestNowPlayingPlaybackQueueForPlayer")
    private static let _queueGetItem: QueueGetItemFn? = load("MRPlaybackQueueGetContentItemAtOffset")
    private static let _getLocalOrigin: GetOriginFn? = load("MRMediaRemoteGetLocalOrigin")
    private static let _playerPathCreate: PlayerPathCreateFn? = load("MRNowPlayingPlayerPathCreate")

    private static func load<T>(_ name: String) -> T? {
        guard let h = handle, let sym = dlsym(h, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    public static var isAvailable: Bool { _getInfo != nil }

    public static func registerNotifications(on queue: DispatchQueue = .main) {
        _register?(queue)
    }

    public static func unregisterNotifications() {
        _unregister?()
    }

    public static func fetchNowPlayingInfo(on queue: DispatchQueue = .main, completion: @escaping @Sendable ([String: Any]) -> Void) {
        guard let fn = _getInfo else {
            completion([:])
            return
        }
        fn(queue) { dict in
            var result = dict ?? [:]
            if let existing = result["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data, !existing.isEmpty {
                completion(result)
                return
            }
            guard !result.isEmpty else {
                completion(result)
                return
            }
            fetchPlaybackQueueArtwork(on: queue) { artData in
                if let artData, !artData.isEmpty {
                    result["kMRMediaRemoteNowPlayingInfoArtworkData"] = artData
                }
                completion(result)
            }
        }
    }

    public static func fetchPlaybackQueueArtwork(on queue: DispatchQueue = .main, completion: @escaping @Sendable (Data?) -> Void) {
        guard let getClient = _getClient,
              let getOrigin = _getLocalOrigin,
              let pathCreate = _playerPathCreate,
              let reqCreate = _queueReqCreate,
              let reqSetArt = _queueReqSetArt,
              let reqQueue = _requestQueue,
              let getItem = _queueGetItem else {
            completion(nil)
            return
        }
        getClient(queue) { client in
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
            reqQueue(req, path, queue) { playbackQueue, _ in
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

    public static func fetchIsPlaying(on queue: DispatchQueue = .main, completion: @escaping @Sendable (Bool) -> Void) {
        guard let fn = _getIsPlaying else {
            completion(false)
            return
        }
        fn(queue) { playing in
            completion(playing)
        }
    }

    public static func fetchNowPlayingBundleID(on queue: DispatchQueue = .main, completion: @escaping @Sendable (String?) -> Void) {
        guard let fn = _getClient, let getBID = _clientBundleID else {
            completion(nil)
            return
        }
        fn(queue) { client in
            guard let client else {
                completion(nil)
                return
            }
            let bid = getBID(client) as String?
            completion(bid)
        }
    }

    // MRMediaRemoteCommand values: 0 = Play, 1 = Pause, 2 = TogglePlayPause, 4 = NextTrack, 5 = PreviousTrack
    @discardableResult
    public static func sendCommand(_ command: UInt32, options: [String: Any]? = nil) -> Bool {
        _sendCommand?(command, options as CFDictionary?) ?? false
    }

    public static func setElapsedTime(_ seconds: TimeInterval) {
        _setElapsed?(seconds)
    }
}

// MARK: - CoreAnimation Private Backdrop & Variable Blur Helpers

public enum CoreAnimationPrivateBridge {
    public static func makeBackdropLayer() -> CALayer? {
        guard let cls = NSClassFromString("CABackdropLayer") as? CALayer.Type else { return nil }
        let layer = cls.init()
        let boolProps = [
            "windowServerAware": true,
            "allowsInPlaceFiltering": true,
            "disablesOccludedBackdropBlurs": false,
            "ignoresOffscreenGroups": false
        ]
        for (key, value) in boolProps {
            if layer.responds(to: NSSelectorFromString("set\(key.prefix(1).uppercased() + key.dropFirst()):")) {
                layer.setValue(value, forKey: key)
            }
        }
        return layer
    }

    public static func makeCAFilter(type: String, inputParams: [String: Any] = [:]) -> NSObject? {
        guard let filterCls = NSClassFromString("CAFilter") as? NSObject.Type else { return nil }
        let sel = NSSelectorFromString("filterWithType:")
        guard filterCls.responds(to: sel),
              let unmanaged = filterCls.perform(sel, with: type),
              let filter = unmanaged.takeUnretainedValue() as? NSObject else {
            return nil
        }
        for (key, value) in inputParams {
            filter.setValue(value, forKey: key)
        }
        return filter
    }
}
