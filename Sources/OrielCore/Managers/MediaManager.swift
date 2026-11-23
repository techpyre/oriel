import Foundation
import AppKit
import ApplicationServices
import CoreImage
import SwiftUI
import Combine

@MainActor
public final class MediaManager: ObservableObject {
    public static let shared = MediaManager()

    @Published public var track: MediaTrackInfo = MediaTrackInfo()
    @Published public var artworkImage: NSImage? = nil
    @Published public var blurredArtworkImage: NSImage? = nil
    @Published public var dominantColors: [Color] = [OrielColors.accent, .white]
    @Published public var isSourceAppActive: Bool = false
    @Published public var isHiddenIdle: Bool = false
    @Published public var artworkFlipped: Bool = false
    @Published public var spotifyAutomationDenied: Bool = false
    @Published public var musicAutomationDenied: Bool = false

    public var onTrackChanged: ((MediaTrackInfo) -> Void)?

    private var pollTimer: Timer?
    private var idleHideWorkItem: DispatchWorkItem?
    private var lastTrackSignature: String = ""
    private var lastArtworkHash: Int = 0
    private var lastTrackFromDirectFallback: Bool = false
    private var artworkCache: [String: Data] = [:]
    private var pendingArtworkLookups: Set<String> = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []

    private let browserBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.google.Chrome",
        "company.thebrowser.dia",
        "company.thebrowser.Browser",
        "org.mozilla.firefox",
        "com.brave.Browser"
    ]

    private init() {
        setupObservers()
        refreshNowPlaying()
    }

    private func setupObservers() {
        XPCMediaBridge.shared.onNowPlayingChange = { [weak self] in
            self?.refreshNowPlaying()
        }
        XPCMediaBridge.shared.startObservation()

        let dnc = DistributedNotificationCenter.default()
        distributedObservers.append(
            dnc.addObserver(forName: Notification.Name("com.apple.Music.playerInfo"), object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated {
                    self?.handleAppleMusicNotification(note.userInfo)
                    self?.refreshNowPlaying()
                }
            }
        )
        distributedObservers.append(
            dnc.addObserver(forName: Notification.Name("com.spotify.client.PlaybackStateChanged"), object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated {
                    self?.handleSpotifyNotification(note.userInfo)
                    self?.refreshNowPlaying()
                }
            }
        )

        let wnc = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            wnc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.updateSourceAppActive() }
            }
        )
        workspaceObservers.append(
            wnc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refreshNowPlaying() }
            }
        )

        // Periodic refresh for seeker sync & transient player updates
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshNowPlaying()
            }
        }
    }

    public func refreshNowPlaying() {
        let settings = AppSettings.shared
        if !settings.automaticMusicApp {
            if settings.musicApp == .music {
                fetchAppleMusicDirectly()
                return
            } else if settings.musicApp == .spotify {
                fetchSpotifyDirectly()
                return
            }
        }

        XPCMediaBridge.shared.fetchNowPlayingInfo { [weak self] info, bundleID, isPlayingFlag in
            Task { @MainActor in
                guard let self else { return }
                if let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String, !title.isEmpty {
                    self.lastTrackFromDirectFallback = false
                    self.applyMediaRemoteInfo(info, bundleID: bundleID, isPlayingFlag: isPlayingFlag)
                } else {
                    // Fallback to Apple Music / Spotify if MediaRemote returned empty
                    self.tryDirectPlayerFallback()
                }
            }
        }
    }

    private func applyMediaRemoteInfo(_ info: [String: Any], bundleID: String?, isPlayingFlag: Bool) {
        let title = (info["kMRMediaRemoteNowPlayingInfoTitle"] as? String) ?? ""
        let artist = (info["kMRMediaRemoteNowPlayingInfoArtist"] as? String) ?? ""
        let album = (info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String) ?? ""
        let artworkData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
        let duration = (info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double) ?? 0
        let elapsed = (info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double) ?? 0
        let timestamp = (info["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date) ?? Date()
        let rate = (info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double) ?? (isPlayingFlag ? 1.0 : 0.0)
        let isExplicit = (info["kMRMediaRemoteNowPlayingInfoIsExplicitTrack"] as? Bool) ?? false
        let isLossless = (info["orielMediaRemoteAudioIsLossless"] as? Bool) ?? false
        let isDolbyAtmos = (info["orielMediaRemoteAudioIsDolbyAtmos"] as? Bool) ?? false
        let mediaType = (info["kMRMediaRemoteNowPlayingInfoMediaType"] as? String) ?? ""
        let isPodcast = mediaType == "MRMediaRemoteMediaTypePodcast"
        let isLive = duration <= 0 && !title.isEmpty
        let isPlaying = isPlayingFlag || rate > 0.01

        let bid = bundleID ?? guessRunningPlayerBundleID() ?? ""
        let appName = appDisplayName(for: bid)
        let pid = NSRunningApplication.runningApplications(withBundleIdentifier: bid).first?.processIdentifier ?? 0

        var shareURL: URL? = nil
        if let adamID = info["kMRMediaRemoteNowPlayingInfoiTunesStoreIdentifier"] as? NSNumber, adamID.intValue > 0 {
            shareURL = URL(string: "https://music.apple.com/song/\(adamID.intValue)")
        }

        let sig = "\(title)|\(artist)|\(album)"
        let resolvedArtwork: Data? = {
            if let data = artworkData, !data.isEmpty { return data }
            if let cached = artworkCache[sig], !cached.isEmpty { return cached }
            if sig == lastTrackSignature { return track.artworkData }
            return nil
        }()

        let newTrack = MediaTrackInfo(
            title: title,
            artist: artist,
            album: album,
            artworkData: resolvedArtwork,
            duration: duration,
            elapsedTime: elapsed,
            timestamp: timestamp,
            playbackRate: rate,
            isPlaying: isPlaying,
            isExplicit: isExplicit,
            isLossless: isLossless,
            isDolbyAtmos: isDolbyAtmos,
            isPodcast: isPodcast,
            isLive: isLive,
            isLoved: track.isLoved,
            isShuffled: track.isShuffled,
            repeatMode: track.repeatMode,
            sourceBundleID: bid,
            sourceAppName: appName,
            audioPID: pid,
            shareURL: shareURL
        )

        commitTrack(newTrack)
        if resolvedArtwork == nil && newTrack.hasTrack {
            fetchMissingArtworkIfNeeded(for: newTrack)
        }
    }

    private func tryDirectPlayerFallback() {
        let spotifyRunning = isAppRunning("com.spotify.client")
        let musicRunning = isAppRunning("com.apple.Music")

        if spotifyRunning {
            fetchSpotifyDirectly()
        } else if spotifyAutomationDenied {
            spotifyAutomationDenied = false
        }
        if musicRunning {
            fetchAppleMusicDirectly()
        } else if musicAutomationDenied {
            musicAutomationDenied = false
        }
        if !spotifyRunning && !musicRunning {
            if track.hasTrack {
                track.isPlaying = false
                AudioManager.shared.updateSpectrumTracking(isPlaying: false, pid: 0)
                scheduleIdleHideIfNeeded()
            }
        }
    }

    private func fetchAppleMusicDirectly() {
        let script = """
        if application "Music" is running then
            tell application "Music"
                if player state is stopped then return ""
                set tName to name of current track
                set tArtist to artist of current track
                set tAlbum to album of current track
                set tDur to duration of current track
                set tPos to player position
                set tState to (player state is playing)
                set tFav to favorited of current track
                return tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tDur & "|||" & tPos & "|||" & tState & "|||" & tFav
            end tell
        end if
        return ""
        """
        runAppleScriptAsync(script) { [weak self] out, errNum in
            guard let self else { return }
            if errNum == -1743 || errNum == -1744 {
                self.musicAutomationDenied = true
                return
            }
            if errNum == nil {
                self.musicAutomationDenied = false
            }
            guard let out, !out.isEmpty else { return }
            let parts = out.components(separatedBy: "|||")
            guard parts.count >= 6 else { return }
            let isPlaying = parts[5] == "true"
            // Don't let paused Apple Music overwrite an actively playing Spotify track
            if !isPlaying && self.track.hasTrack && self.track.isPlaying && self.track.sourceBundleID != "com.apple.Music" {
                return
            }
            let isFav = parts.count >= 7 ? (parts[6] == "true") : false
            let sig = "\(parts[0])|\(parts[1])|\(parts[2])"
            let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").first?.processIdentifier ?? 0
            let existingArt = self.artworkCache[sig] ?? (self.track.sourceBundleID == "com.apple.Music" && self.track.title == parts[0] ? self.track.artworkData : nil)
            let info = MediaTrackInfo(
                title: parts[0],
                artist: parts[1],
                album: parts[2],
                artworkData: existingArt,
                duration: Double(parts[3].replacingOccurrences(of: ",", with: ".")) ?? 0,
                elapsedTime: Double(parts[4].replacingOccurrences(of: ",", with: ".")) ?? 0,
                timestamp: Date(),
                playbackRate: isPlaying ? 1.0 : 0.0,
                isPlaying: isPlaying,
                isLoved: isFav,
                sourceBundleID: "com.apple.Music",
                sourceAppName: "Music",
                audioPID: pid
            )
            self.lastTrackFromDirectFallback = true
            self.commitTrack(info)
            if existingArt == nil && info.hasTrack {
                self.fetchMissingArtworkIfNeeded(for: info)
            }
        }
    }

    private func fetchSpotifyDirectly() {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify"
                if player state is stopped then return ""
                set tName to name of current track
                set tArtist to artist of current track
                set tAlbum to album of current track
                set tDur to (duration of current track) / 1000.0
                set tPos to player position
                set tState to (player state is playing)
                set tUrl to spotify url of current track
                set tArt to artwork url of current track
                return tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tDur & "|||" & tPos & "|||" & tState & "|||" & tUrl & "|||" & tArt
            end tell
        end if
        return ""
        """
        runAppleScriptAsync(script) { [weak self] out, errNum in
            guard let self else { return }
            if errNum == -1743 || errNum == -1744 {
                self.spotifyAutomationDenied = true
                return
            }
            if errNum == nil {
                self.spotifyAutomationDenied = false
            }
            guard let out, !out.isEmpty else { return }
            let parts = out.components(separatedBy: "|||")
            guard parts.count >= 6 else { return }
            let isPlaying = parts[5] == "true"
            // Don't let paused Spotify overwrite an actively playing Apple Music track
            if !isPlaying && self.track.hasTrack && self.track.isPlaying && self.track.sourceBundleID != "com.spotify.client" {
                return
            }
            let shareURL: URL? = parts.count >= 7 ? Self.spotifyShareURL(from: parts[6]) : nil
            let artworkURLString: String? = parts.count >= 8 ? parts[7].trimmingCharacters(in: .whitespacesAndNewlines) : nil
            let sig = "\(parts[0])|\(parts[1])|\(parts[2])"
            let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").first?.processIdentifier ?? 0
            let existingArt = self.artworkCache[sig] ?? (self.track.sourceBundleID == "com.spotify.client" && self.track.title == parts[0] ? self.track.artworkData : nil)
            let info = MediaTrackInfo(
                title: parts[0],
                artist: parts[1],
                album: parts[2],
                artworkData: existingArt,
                duration: Double(parts[3].replacingOccurrences(of: ",", with: ".")) ?? 0,
                elapsedTime: Double(parts[4].replacingOccurrences(of: ",", with: ".")) ?? 0,
                timestamp: Date(),
                playbackRate: isPlaying ? 1.0 : 0.0,
                isPlaying: isPlaying,
                sourceBundleID: "com.spotify.client",
                sourceAppName: "Spotify",
                audioPID: pid,
                shareURL: shareURL
            )
            self.lastTrackFromDirectFallback = true
            self.commitTrack(info)
            if existingArt == nil, let urlStr = artworkURLString, let url = URL(string: urlStr) {
                self.downloadArtwork(from: url, signature: sig)
            } else if existingArt == nil && info.hasTrack {
                self.fetchMissingArtworkIfNeeded(for: info)
            }
        }
    }

    private func fetchMissingArtworkIfNeeded(for item: MediaTrackInfo) {
        let sig = "\(item.title)|\(item.artist)|\(item.album)"
        if let cached = artworkCache[sig], !cached.isEmpty {
            applyResolvedArtwork(cached, signature: sig)
            return
        }
        guard !pendingArtworkLookups.contains(sig) else { return }
        pendingArtworkLookups.insert(sig)

        // 1. Try MediaRemote playback queue directly
        MediaRemoteBridge.fetchPlaybackQueueArtwork { [weak self] data in
            Task { @MainActor in
                guard let self else { return }
                if let data, !data.isEmpty {
                    self.pendingArtworkLookups.remove(sig)
                    self.applyResolvedArtwork(data, signature: sig)
                    return
                }
                // 2. Fallback to Spotify artwork url via AppleScript + HTTPS fetch, else public oEmbed / iTunes Search
                if (item.sourceBundleID == "com.spotify.client" || self.isAppRunning("com.spotify.client")) && !self.spotifyAutomationDenied {
                    let script = """
                    if application "Spotify" is running then
                        tell application "Spotify"
                            if player state is not stopped then return artwork url of current track
                        end tell
                    end if
                    return ""
                    """
                    self.runAppleScriptAsync(script) { [weak self] urlStr, errNum in
                        guard let self else { return }
                        if let trimmed = urlStr?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !trimmed.isEmpty,
                           let url = URL(string: trimmed) {
                            self.pendingArtworkLookups.remove(sig)
                            self.downloadArtwork(from: url, signature: sig)
                        } else {
                            if errNum == -1743 || errNum == -1744 {
                                self.spotifyAutomationDenied = true
                            }
                            self.fetchPublicFallbackArtwork(for: item, signature: sig)
                        }
                    }
                } else {
                    self.fetchPublicFallbackArtwork(for: item, signature: sig)
                }
            }
        }
    }

    private func fetchPublicFallbackArtwork(for item: MediaTrackInfo, signature: String) {
        let shareURL = item.shareURL
        let title = item.title
        let artist = item.artist
        Task.detached(priority: .userInitiated) { [weak self] in
            var resolvedURL: URL? = nil

            // 1. Spotify oEmbed (zero auth, returns official cover art thumbnail_url)
            if let shareURL, shareURL.absoluteString.contains("open.spotify.com/track/"),
               var comps = URLComponents(string: "https://open.spotify.com/oembed") {
                comps.queryItems = [URLQueryItem(name: "url", value: shareURL.absoluteString)]
                if let oembedURL = comps.url,
                   let (jsonData, _) = try? await URLSession.shared.data(from: oembedURL) {
                    resolvedURL = Self.parseSpotifyOEmbedThumbnailURL(from: jsonData)
                }
            }

            // 2. iTunes Search API fallback (zero auth, 600x600 artwork for Apple Music / any song)
            if resolvedURL == nil, !title.isEmpty {
                let query = artist.isEmpty ? title : "\(title) \(artist)"
                if var comps = URLComponents(string: "https://itunes.apple.com/search") {
                    comps.queryItems = [
                        URLQueryItem(name: "term", value: query),
                        URLQueryItem(name: "entity", value: "song"),
                        URLQueryItem(name: "limit", value: "1")
                    ]
                    if let searchURL = comps.url,
                       let (jsonData, _) = try? await URLSession.shared.data(from: searchURL) {
                        resolvedURL = Self.parseITunesArtworkURL(from: jsonData)
                    }
                }
            }

            var downloaded: Data? = nil
            if let resolvedURL,
               let (imgData, _) = try? await URLSession.shared.data(from: resolvedURL),
               !imgData.isEmpty {
                downloaded = imgData
            }

            await MainActor.run {
                guard let self else { return }
                self.pendingArtworkLookups.remove(signature)
                if let downloaded {
                    self.applyResolvedArtwork(downloaded, signature: signature)
                }
            }
        }
    }

    private func downloadArtwork(from url: URL, signature: String) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url), !data.isEmpty else { return }
            await MainActor.run {
                self?.applyResolvedArtwork(data, signature: signature)
            }
        }
    }

    private func applyResolvedArtwork(_ data: Data, signature: String) {
        artworkCache[signature] = data
        if artworkCache.count > 24, let firstKey = artworkCache.keys.first(where: { $0 != signature }) {
            artworkCache.removeValue(forKey: firstKey)
        }
        let currentSig = "\(track.title)|\(track.artist)|\(track.album)"
        guard currentSig == signature else { return }
        var updated = track
        updated.artworkData = data
        commitTrack(updated)
    }

    private func commitTrack(_ newTrack: MediaTrackInfo) {
        let sig = "\(newTrack.title)|\(newTrack.artist)|\(newTrack.album)"
        let trackChanged = (sig != lastTrackSignature) && newTrack.hasTrack
        lastTrackSignature = sig

        if let data = newTrack.artworkData {
            artworkCache[sig] = data
            let h = data.hashValue
            if h != lastArtworkHash || artworkImage == nil {
                lastArtworkHash = h
                let targetSig = sig
                Task.detached(priority: .userInitiated) { [weak self] in
                    let decoded = NSImage(data: data)
                    let blurred = Self.makeCachedBlurredImage(from: data)
                    let extracted = DominantColorExtractor.extractColors(from: data, count: 2)
                    await MainActor.run {
                        guard let self else { return }
                        let currentSig = "\(self.track.title)|\(self.track.artist)|\(self.track.album)"
                        if currentSig == targetSig || self.lastArtworkHash == h {
                            self.artworkImage = decoded
                            self.blurredArtworkImage = blurred
                            self.dominantColors = extracted
                        }
                    }
                }
            }
        } else if trackChanged {
            artworkImage = nil
            blurredArtworkImage = nil
            dominantColors = [AppSettings.shared.accentColor, .white]
        }

        track = newTrack
        updateSourceAppActive()

        if newTrack.isPlaying {
            isHiddenIdle = false
            idleHideWorkItem?.cancel()
        } else {
            scheduleIdleHideIfNeeded()
        }

        AudioManager.shared.updateSpectrumTracking(isPlaying: newTrack.isPlaying, pid: newTrack.audioPID)

        if trackChanged {
            onTrackChanged?(newTrack)
        }
    }

    private func scheduleIdleHideIfNeeded() {
        idleHideWorkItem?.cancel()
        let delay = AppSettings.shared.idleDuration
        guard delay > 0 else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.track.isPlaying else { return }
            self.isHiddenIdle = true
        }
        idleHideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func updateSourceAppActive() {
        guard let frontBID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
              !track.sourceBundleID.isEmpty else {
            isSourceAppActive = false
            return
        }
        isSourceAppActive = (frontBID == track.sourceBundleID)
    }

    // MARK: - Playback Controls

    public func togglePlayPause() {
        HapticFeedback.shared.perform(.alignment)
        if lastTrackFromDirectFallback, let appName = directPlayerAppName {
            runAppleScriptAsync("tell application \"\(appName)\" to playpause") { _, _ in }
        } else {
            XPCMediaBridge.shared.playPause()
        }
        track.isPlaying.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.refreshNowPlaying()
        }
    }

    public func nextTrack() {
        HapticFeedback.shared.perform(.alignment)
        if lastTrackFromDirectFallback, let appName = directPlayerAppName {
            runAppleScriptAsync("tell application \"\(appName)\" to next track") { _, _ in }
        } else {
            XPCMediaBridge.shared.nextTrack()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.refreshNowPlaying()
        }
    }

    public func previousTrack() {
        HapticFeedback.shared.perform(.alignment)
        if lastTrackFromDirectFallback, let appName = directPlayerAppName {
            runAppleScriptAsync("tell application \"\(appName)\" to previous track") { _, _ in }
        } else {
            XPCMediaBridge.shared.previousTrack()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.refreshNowPlaying()
        }
    }

    public func seek(to seconds: TimeInterval) {
        let clamped = max(0, min(track.duration, seconds))
        track.elapsedTime = clamped
        track.timestamp = Date()
        if lastTrackFromDirectFallback, let appName = directPlayerAppName {
            let formatted = String(format: "%.2f", clamped)
            runAppleScriptAsync("tell application \"\(appName)\" to set player position to \(formatted)") { _, _ in }
        } else {
            XPCMediaBridge.shared.setPlayerPosition(clamped)
        }
    }

    private var directPlayerAppName: String? {
        if track.sourceBundleID == "com.spotify.client" { return "Spotify" }
        if track.sourceBundleID == "com.apple.Music" { return "Music" }
        return nil
    }

    public func triggerExtraControl() {
        HapticFeedback.shared.perform(.alignment)
        switch AppSettings.shared.controlChoice {
        case .like, .favorite:
            toggleLikeOrFavorite()
        case .shuffle:
            track.isShuffled.toggle()
            XPCMediaBridge.shared.setShuffleMode(track.isShuffled ? 1 : 0)
        case .repeating:
            track.repeatMode = (track.repeatMode + 1) % 3
            XPCMediaBridge.shared.setRepeatMode(track.repeatMode)
        case .copyLink:
            copyTrackLink()
        }
    }

    private func toggleLikeOrFavorite() {
        track.isLoved.toggle()
        if track.sourceBundleID == "com.apple.Music" {
            let val = track.isLoved ? "true" : "false"
            runAppleScriptAsync("tell application \"Music\" to set favorited of current track to \(val)") { _, _ in }
        }
    }

    private func copyTrackLink() {
        let text = track.shareURL?.absoluteString ?? "\(track.title) - \(track.artist)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    public func openSourceApp() {
        let bid = track.sourceBundleID
        guard !bid.isEmpty else { return }

        // If browser, focus the matching tab via AppleScript just like Oriel
        if bid == "com.apple.Safari" || bid == "com.apple.SafariTechnologyPreview" {
            let safeTitle = track.title.replacingOccurrences(of: "\"", with: "\\\"")
            let appName = bid == "com.apple.Safari" ? "Safari" : "Safari Technology Preview"
            let script = """
            if application "\(appName)" is running then
                tell application "\(appName)"
                    repeat with w in windows
                        repeat with t in tabs of w
                            if (name of t as text) contains "\(safeTitle)" then
                                set current tab of w to t
                                set index of w to 1
                                activate
                                return true
                            end if
                        end repeat
                    end repeat
                end tell
            end if
            """
            runAppleScriptAsync(script) { _, _ in }
            return
        } else if bid == "com.google.Chrome" {
            let safeTitle = track.title.replacingOccurrences(of: "\"", with: "\\\"")
            let script = """
            if application "Google Chrome" is running then
                tell application "Google Chrome"
                    repeat with w in windows
                        set tabIndex to 0
                        repeat with t in tabs of w
                            set tabIndex to tabIndex + 1
                            if (title of t as text) contains "\(safeTitle)" then
                                set active tab index of w to tabIndex
                                set index of w to 1
                                activate
                                return true
                            end if
                        end repeat
                    end repeat
                end tell
            end if
            """
            runAppleScriptAsync(script) { _, _ in }
            return
        } else if bid == "company.thebrowser.dia" {
            let safeTitle = track.title.replacingOccurrences(of: "\"", with: "\\\"")
            let script = """
            if application "Dia" is running then
                tell application "Dia"
                    repeat with w in windows
                        repeat with t in tabs of w
                            if (title of t as text) contains "\(safeTitle)" then
                                focus t
                                activate
                                return true
                            end if
                        end repeat
                    end repeat
                end tell
            end if
            """
            runAppleScriptAsync(script) { _, _ in }
            return
        }

        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    // MARK: - Helpers

    nonisolated public static func spotifyShareURL(from uri: String) -> URL? {
        if uri.hasPrefix("spotify:track:") {
            let id = uri.replacingOccurrences(of: "spotify:track:", with: "")
            return URL(string: "https://open.spotify.com/track/\(id)")
        }
        return URL(string: uri)
    }

    private func isAppRunning(_ bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    private func guessRunningPlayerBundleID() -> String? {
        if isAppRunning("com.apple.Music") { return "com.apple.Music" }
        if isAppRunning("com.spotify.client") { return "com.spotify.client" }
        for bid in browserBundleIDs where isAppRunning(bid) {
            return bid
        }
        return nil
    }

    private func appDisplayName(for bundleID: String) -> String {
        switch bundleID {
        case "com.apple.Music": return "Music"
        case "com.spotify.client": return "Spotify"
        case "com.apple.Safari": return "Safari"
        case "com.apple.SafariTechnologyPreview": return "Safari TP"
        case "com.google.Chrome": return "Chrome"
        case "company.thebrowser.dia": return "Dia"
        case "com.tidal.desktop": return "TIDAL"
        default:
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
               let name = app.localizedName {
                return name
            }
            return "Media"
        }
    }

    // MARK: - Distributed Notification & Automation Fallbacks

    private func handleSpotifyNotification(_ userInfo: [AnyHashable: Any]?) {
        guard let parsed = Self.parseSpotifyNotificationPayload(userInfo) else { return }
        if parsed.isStopped {
            if track.sourceBundleID == "com.spotify.client" {
                track.isPlaying = false
                AudioManager.shared.updateSpectrumTracking(isPlaying: false, pid: 0)
                scheduleIdleHideIfNeeded()
            }
            return
        }
        let sig = "\(parsed.title)|\(parsed.artist)|\(parsed.album)"
        let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").first?.processIdentifier ?? 0
        let existingArt = artworkCache[sig] ?? (track.sourceBundleID == "com.spotify.client" && track.title == parsed.title ? track.artworkData : nil)
        let info = MediaTrackInfo(
            title: parsed.title,
            artist: parsed.artist,
            album: parsed.album,
            artworkData: existingArt,
            duration: parsed.duration,
            elapsedTime: parsed.elapsed,
            timestamp: Date(),
            playbackRate: parsed.isPlaying ? 1.0 : 0.0,
            isPlaying: parsed.isPlaying,
            sourceBundleID: "com.spotify.client",
            sourceAppName: "Spotify",
            audioPID: pid,
            shareURL: parsed.shareURL
        )
        lastTrackFromDirectFallback = true
        commitTrack(info)
        if existingArt == nil && info.hasTrack {
            fetchMissingArtworkIfNeeded(for: info)
        }
    }

    private func handleAppleMusicNotification(_ userInfo: [AnyHashable: Any]?) {
        guard let parsed = Self.parseAppleMusicNotificationPayload(userInfo) else { return }
        if parsed.isStopped {
            if track.sourceBundleID == "com.apple.Music" {
                track.isPlaying = false
                AudioManager.shared.updateSpectrumTracking(isPlaying: false, pid: 0)
                scheduleIdleHideIfNeeded()
            }
            return
        }
        let sig = "\(parsed.title)|\(parsed.artist)|\(parsed.album)"
        let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").first?.processIdentifier ?? 0
        let existingArt = artworkCache[sig] ?? (track.sourceBundleID == "com.apple.Music" && track.title == parsed.title ? track.artworkData : nil)
        let info = MediaTrackInfo(
            title: parsed.title,
            artist: parsed.artist,
            album: parsed.album,
            artworkData: existingArt,
            duration: parsed.duration,
            elapsedTime: parsed.elapsed,
            timestamp: Date(),
            playbackRate: parsed.isPlaying ? 1.0 : 0.0,
            isPlaying: parsed.isPlaying,
            sourceBundleID: "com.apple.Music",
            sourceAppName: "Music",
            audioPID: pid
        )
        lastTrackFromDirectFallback = true
        commitTrack(info)
        if existingArt == nil && info.hasTrack {
            fetchMissingArtworkIfNeeded(for: info)
        }
    }

    public struct ParsedPlayerNotification: Equatable, Sendable {
        public let title: String
        public let artist: String
        public let album: String
        public let duration: Double
        public let elapsed: Double
        public let isPlaying: Bool
        public let isStopped: Bool
        public let shareURL: URL?
    }

    nonisolated public static func parseSpotifyNotificationPayload(_ userInfo: [AnyHashable: Any]?) -> ParsedPlayerNotification? {
        guard let userInfo else { return nil }
        let state = (userInfo["Player State"] as? String ?? "").lowercased()
        let isStopped = state == "stopped"
        let title = (userInfo["Name"] as? String) ?? ""
        guard !title.isEmpty || isStopped else { return nil }
        let artist = (userInfo["Artist"] as? String) ?? ""
        let album = (userInfo["Album"] as? String) ?? ""
        let rawDur = (userInfo["Duration"] as? NSNumber)?.doubleValue ?? 0
        // Spotify notifications report Duration in seconds or milliseconds depending on version
        let duration = rawDur > 36000 ? (rawDur / 1000.0) : rawDur
        let elapsed = (userInfo["Playback Position"] as? NSNumber)?.doubleValue ?? 0
        let trackURI = (userInfo["Track ID"] as? String) ?? ""
        return ParsedPlayerNotification(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            elapsed: elapsed,
            isPlaying: state == "playing",
            isStopped: isStopped,
            shareURL: spotifyShareURL(from: trackURI)
        )
    }

    nonisolated public static func parseAppleMusicNotificationPayload(_ userInfo: [AnyHashable: Any]?) -> ParsedPlayerNotification? {
        guard let userInfo else { return nil }
        let state = (userInfo["Player State"] as? String ?? "").lowercased()
        let isStopped = state == "stopped"
        let title = (userInfo["Name"] as? String) ?? ""
        guard !title.isEmpty || isStopped else { return nil }
        let artist = (userInfo["Artist"] as? String) ?? ""
        let album = (userInfo["Album"] as? String) ?? ""
        let totalMs = (userInfo["Total Time"] as? NSNumber)?.doubleValue ?? 0
        let duration = totalMs > 0 ? (totalMs / 1000.0) : 0
        return ParsedPlayerNotification(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            elapsed: 0,
            isPlaying: state == "playing",
            isStopped: isStopped,
            shareURL: nil
        )
    }

    nonisolated private static let blurCIContext = CIContext(options: [.useSoftwareRenderer: false])

    nonisolated private static func makeCachedBlurredImage(from data: Data) -> NSImage? {
        guard let ciInput = CIImage(data: data) else { return nil }
        let target: CGFloat = 80
        let sx = target / max(1, ciInput.extent.width)
        let sy = target / max(1, ciInput.extent.height)
        let scaled = ciInput
            .transformed(by: CGAffineTransform(scaleX: sx, y: sy))
            .clampedToExtent()
        guard let blur = CIFilter(name: "CIGaussianBlur") else { return nil }
        blur.setValue(scaled, forKey: kCIInputImageKey)
        blur.setValue(12.0, forKey: kCIInputRadiusKey)
        guard let sat = CIFilter(name: "CIColorControls"),
              let blurred = blur.outputImage else { return nil }
        sat.setValue(blurred, forKey: kCIInputImageKey)
        sat.setValue(1.4, forKey: kCIInputSaturationKey)
        let crop = CGRect(x: 0, y: 0, width: target, height: target)
        guard let finalCI = sat.outputImage?.cropped(to: crop),
              let cg = blurCIContext.createCGImage(finalCI, from: crop) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: target, height: target))
    }

    nonisolated public static func parseSpotifyOEmbedThumbnailURL(from data: Data) -> URL? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let thumb = obj["thumbnail_url"] as? String else { return nil }
        return URL(string: thumb)
    }

    nonisolated public static func parseITunesArtworkURL(from data: Data) -> URL? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = obj["results"] as? [[String: Any]],
              let first = results.first,
              let raw = (first["artworkUrl100"] as? String) ?? (first["artworkUrl60"] as? String) else {
            return nil
        }
        let highRes = raw.replacingOccurrences(of: "100x100bb", with: "600x600bb")
            .replacingOccurrences(of: "60x60bb", with: "600x600bb")
        return URL(string: highRes)
    }

    public func refreshAutomationStatusAsync() {
        // Non-blocking check via lightweight player probe instead of AEDeterminePermissionToAutomateTarget
        // which can block background GCD threads indefinitely on macOS 27.
        if isAppRunning("com.spotify.client") {
            fetchSpotifyDirectly()
        } else {
            spotifyAutomationDenied = false
        }
        if isAppRunning("com.apple.Music") {
            fetchAppleMusicDirectly()
        } else {
            musicAutomationDenied = false
        }
    }

    public func requestAutomationPermission(for bundleID: String) {
        let appName = (bundleID == "com.apple.Music") ? "Music" : "Spotify"
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let probe = "if application \"\(appName)\" is running then tell application \"\(appName)\" to get player state as string"
        runAppleScriptAsync(probe) { [weak self] _, errNum in
            guard let self else { return }
            let denied = (errNum == -1743 || errNum == -1744)
            if bundleID == "com.spotify.client" {
                self.spotifyAutomationDenied = denied
            } else if bundleID == "com.apple.Music" {
                self.musicAutomationDenied = denied
            }
            if !denied {
                self.refreshNowPlaying()
            } else if errNum == -1743 {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func runAppleScriptAsync(_ source: String, completion: @escaping @MainActor @Sendable (String?, Int?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var err: NSDictionary?
            let script = NSAppleScript(source: source)
            let result = script?.executeAndReturnError(&err).stringValue
            let errNum = err?[NSAppleScript.errorNumber] as? Int
            Task { @MainActor in
                completion(result, errNum)
            }
        }
    }
}
