import Foundation
import AppKit
import CoreGraphics
import ServiceManagement
import Combine

// MARK: - Game Detection

@MainActor
public final class GameManager: ObservableObject {
    public static let shared = GameManager()

    @Published public var isGaming: Bool = false

    private let trackedGameBundleIdentifiers: Set<String> = [
        "com.riotgames.leagueoflegends",
        "com.riotgames.leagueoflegends.gameclient",
        "com.riotgames.leagueclient",
        "com.riotgames.leagueclientux",
        "com.nvidia.gfnpc.mall",
        "com.valvesoftware.steam",
        "com.epicgames.EpicGamesLauncher",
        "com.blizzard.battlenet"
    ]

    private let trackedGamePathFragments: [String] = [
        "/application support/minecraft/runtime/",
        "/steamapps/common/",
        "/crossover/",
        "/whisky/"
    ]

    private var observer: NSObjectProtocol?

    private init() {
        checkFrontmostApp()
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkFrontmostApp()
            }
        }
    }

    public func checkFrontmostApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            isGaming = false
            return
        }
        let bid = app.bundleIdentifier ?? ""
        let path = app.executableURL?.path.lowercased() ?? ""
        let matchedBID = trackedGameBundleIdentifiers.contains(bid)
        let matchedPath = trackedGamePathFragments.contains { path.contains($0) }
        isGaming = matchedBID || matchedPath
    }
}

// MARK: - Screen & Fullscreen Manager

@MainActor
public final class ScreenManager: ObservableObject {
    public static let shared = ScreenManager()

    @Published public var isFullscreen: Bool = false
    @Published public var availableScreens: [NSScreen] = NSScreen.screens

    private var observers: [NSObjectProtocol] = []
    private var pollTimer: Timer?

    private init() {
        refreshScreens()
        let nc = NotificationCenter.default
        observers.append(
            nc.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refreshScreens() }
            }
        )
        observers.append(
            NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.evaluateFullscreen() }
            }
        )
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluateFullscreen() }
        }
    }

    public func refreshScreens() {
        availableScreens = NSScreen.screens
        evaluateFullscreen()
    }

    public func evaluateFullscreen() {
        guard let mainScreen = NSScreen.main else {
            isFullscreen = false
            return
        }
        let screenFrame = mainScreen.frame
        let myPID = ProcessInfo.processInfo.processIdentifier
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
            let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
            var foundFullscreen = false
            for win in windowList {
                guard let pid = win[kCGWindowOwnerPID as String] as? Int32, pid != myPID else { continue }
                guard let layer = win[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
                guard let boundsDict = win[kCGWindowBounds as String] as? [String: Any],
                      let x = boundsDict["X"] as? CGFloat,
                      let y = boundsDict["Y"] as? CGFloat,
                      let w = boundsDict["Width"] as? CGFloat,
                      let h = boundsDict["Height"] as? CGFloat else { continue }
                let owner = (win[kCGWindowOwnerName as String] as? String) ?? ""
                if owner == "Dock" || owner == "Window Server" || owner == "Finder" { continue }
                if abs(w - screenFrame.width) < 2 && abs(h - screenFrame.height) < 2 && x <= 1 && y <= 1 {
                    foundFullscreen = true
                    break
                }
            }
            Task { @MainActor [weak self] in
                if self?.isFullscreen != foundFullscreen {
                    self?.isFullscreen = foundFullscreen
                }
            }
        }
    }

    public func targetScreens(for settings: AppSettings) -> [NSScreen] {
        let screens = NSScreen.screens
        switch settings.showOnDisplay {
        case .builtInDisplay:
            if let builtIn = screens.first(where: { screen in
                guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return false }
                return CGDisplayIsBuiltin(id) != 0
            }) {
                return [builtIn]
            }
            return screens.first.map { [$0] } ?? []
        case .mainScreen:
            return (NSScreen.main ?? screens.first).map { [$0] } ?? []
        case .allDisplays:
            return screens
        case .specificDisplay:
            if let match = screens.first(where: { Self.displayUUID(for: $0) == settings.showOnDisplayUUID }) {
                return [match]
            }
            return screens.first.map { [$0] } ?? []
        }
    }

    public static func displayUUID(for screen: NSScreen) -> String {
        guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else {
            return screen.localizedName
        }
        return CFUUIDCreateString(nil, uuid) as String
    }
}

// MARK: - Launch at Login Helper

@MainActor
public enum LaunchAtLoginManager {
    public static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Fails gracefully when running from unbundled SwiftPM binary
        }
    }

    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}

// MARK: - File Tray Manager (Bonus functional shelf)

@MainActor
public final class FileTrayManager: ObservableObject {
    public static let shared = FileTrayManager()

    @Published public var items: [TrayFileItem] = []

    private init() {}

    public func add(urls: [URL]) {
        for url in urls {
            if !items.contains(where: { $0.url == url }) {
                items.append(TrayFileItem(url: url))
            }
        }
        HapticFeedback.shared.perform(.alignment)
    }

    public func remove(_ item: TrayFileItem) {
        items.removeAll { $0.id == item.id }
    }

    public func clear() {
        items.removeAll()
    }

    public func shareViaAirDrop(_ item: TrayFileItem) {
        if let service = NSSharingService(named: .sendViaAirDrop) {
            service.perform(withItems: [item.url])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        }
    }
}
