import Foundation
import SwiftUI
import Combine

// MARK: - Enums matching Oriel Settings & Options

public enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general
    case battery
    case connectivity
    case focus
    case display
    case sound
    case nowPlaying
    case calendar
    case fileTray
    case lockScreen
    case about

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general: return "General"
        case .battery: return "Battery"
        case .connectivity: return "Connectivity"
        case .focus: return "Focus"
        case .display: return "Display"
        case .sound: return "Sound"
        case .nowPlaying: return "Now Playing"
        case .calendar: return "Calendar"
        case .fileTray: return "File Tray"
        case .lockScreen: return "Lock Screen"
        case .about: return "About"
        }
    }

    public var symbolName: String {
        switch self {
        case .general: return "gearshape.fill"
        case .battery: return "battery.75percent"
        case .connectivity: return "airpodspro"
        case .focus: return "moon.fill"
        case .display: return "sun.max.fill"
        case .sound: return "speaker.wave.2.fill"
        case .nowPlaying: return "waveform"
        case .calendar: return "calendar"
        case .fileTray: return "tray.fill"
        case .lockScreen: return "lock.fill"
        case .about: return "info.circle.fill"
        }
    }

    public var iconColor: Color {
        switch self {
        case .general: return Color.gray
        case .battery: return OrielColors.green
        case .connectivity: return OrielColors.sky
        case .focus: return OrielColors.indigo
        case .display: return OrielColors.amber
        case .sound: return OrielColors.rose
        case .nowPlaying: return OrielColors.coral
        case .calendar: return OrielColors.orange
        case .fileTray: return OrielColors.teal
        case .lockScreen: return OrielColors.purple
        case .about: return OrielColors.slate
        }
    }
}

public enum DisplayType: String, CaseIterable, Identifiable, Codable, Sendable {
    case builtInDisplay
    case mainScreen
    case allDisplays
    case specificDisplay

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .builtInDisplay: return "Built-in display"
        case .mainScreen: return "Main display"
        case .allDisplays: return "All displays"
        case .specificDisplay: return "Selected display"
        }
    }
}

public enum IdleActivityMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case none
    case nowPlaying
    case calendar
    case duo

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: return "None"
        case .nowPlaying: return "Playing"
        case .calendar: return "Calendar"
        case .duo: return "Duo"
        }
    }
}

public enum NowPlayingColorStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case artwork
    case color
    case gradient
    case mono

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .artwork: return "Artwork"
        case .color: return "Colored"
        case .gradient: return "Gradient"
        case .mono: return "Monochrome"
        }
    }
}

public enum NowPlayingControlChoice: String, CaseIterable, Identifiable, Codable, Sendable {
    case like
    case favorite
    case shuffle
    case repeating
    case copyLink

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .like: return "Like"
        case .favorite: return "Favorite"
        case .shuffle: return "Shuffle"
        case .repeating: return "Repeat"
        case .copyLink: return "Copy"
        }
    }

    public var symbolName: String {
        switch self {
        case .like: return "heart"
        case .favorite: return "star"
        case .shuffle: return "shuffle"
        case .repeating: return "repeat"
        case .copyLink: return "link"
        }
    }
}

public enum NowPlayingMusicApp: String, CaseIterable, Identifiable, Codable, Sendable {
    case system
    case music
    case spotify

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: return "System"
        case .music: return "Music"
        case .spotify: return "Spotify"
        }
    }
}

public enum NowPlayingTitleBadge: String, CaseIterable, Identifiable, Codable, Sendable {
    case none
    case explicit
    case format

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: return "None"
        case .explicit: return "Explicit"
        case .format: return "Format"
        }
    }
}

public enum HUDProgressStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case white
    case accent
    case stylized
    case glow
    case decibel

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .white: return "White"
        case .accent: return "Accent"
        case .stylized: return "Stylized"
        case .glow: return "Glow"
        case .decibel: return "Decibel"
        }
    }

    public static var brightnessCases: [HUDProgressStyle] {
        [.white, .accent, .stylized, .glow]
    }

    public static var volumeCases: [HUDProgressStyle] {
        [.white, .accent, .stylized, .decibel]
    }
}

public enum HUDSpeed: String, CaseIterable, Identifiable, Codable, Sendable {
    case smooth
    case fast
    case instant

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .smooth: return "Smooth"
        case .fast: return "Fast"
        case .instant: return "Instant"
        }
    }

    public var animationDuration: TimeInterval {
        switch self {
        case .smooth: return 0.20
        case .fast: return 0.11
        case .instant: return 0.0
        }
    }
}

public enum VolumeOutputDeviceMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case symbol
    case device

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .symbol: return "Show symbol"
        case .device: return "Show device"
        }
    }
}

public enum ConnectivityModel: String, CaseIterable, Identifiable, Codable, Sendable {
    case threeDimensional
    case symbol

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .threeDimensional: return "3D models"
        case .symbol: return "Symbols"
        }
    }
}

public enum TransportType: String, CaseIterable, Identifiable, Codable, Sendable {
    case drive
    case transit
    case walk

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .drive: return "Driving"
        case .transit: return "Transit"
        case .walk: return "Walking"
        }
    }

    public var symbolName: String {
        switch self {
        case .drive: return "car.fill"
        case .transit: return "tram.fill"
        case .walk: return "figure.walk"
        }
    }
}

public enum WeatherStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case conditions
    case sun
    case precipitation

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .conditions: return "Conditions"
        case .sun: return "Sun"
        case .precipitation: return "Precipitation"
        }
    }
}

public enum LockScreenNowPlayingStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case clear
    case frosted
    case glass

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .clear: return "Clear"
        case .frosted: return "Frosted"
        case .glass: return "Glass"
        }
    }
}

public enum LockScreenWidgetType: String, CaseIterable, Identifiable, Codable, Sendable {
    case weather
    case calendar
    case nowPlaying
    case focus
    case connectivity
    case battery

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .weather: return "Weather"
        case .calendar: return "Calendar"
        case .nowPlaying: return "Now Playing"
        case .focus: return "Focus"
        case .connectivity: return "Connectivity"
        case .battery: return "Battery"
        }
    }
}

// MARK: - Persistent Settings Store

@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    private let defaults: UserDefaults
    private var isRestoring = false

    // General
    @Published public var hasCompletedOnboarding: Bool { didSet { save("hasCompletedOnboarding", hasCompletedOnboarding) } }
    @Published public var launchAtLogin: Bool { didSet { save("launchAtLogin", launchAtLogin) } }
    @Published public var hideMenuBarIcon: Bool { didSet { save("hideMenuBarIcon", hideMenuBarIcon) } }
    @Published public var hideFromScreenCapture: Bool { didSet { save("hideFromScreenCapture", hideFromScreenCapture) } }
    @Published public var forceSimulatedNotch: Bool { didSet { save("forceSimulatedNotch", forceSimulatedNotch) } }
    @Published public var hideWhileInFullscreen: Bool { didSet { save("hideWhileInFullscreen", hideWhileInFullscreen) } }
    @Published public var hideWhileGaming: Bool { didSet { save("hideWhileGaming", hideWhileGaming) } }
    @Published public var hideWhileInMissionControl: Bool { didSet { save("hideWhileInMissionControl", hideWhileInMissionControl) } }
    @Published public var showOnDisplay: DisplayType { didSet { saveEnum("showOnDisplay", showOnDisplay) } }
    @Published public var showOnDisplayUUID: String { didSet { save("showOnDisplayUUID", showOnDisplayUUID) } }
    @Published public var contrastOutline: Bool { didSet { save("contrastOutline", contrastOutline) } }
    @Published public var progressiveBlur: Bool { didSet { save("progressiveBlur", progressiveBlur) } }
    @Published public var enableHaptics: Bool { didSet { save("enableHaptics", enableHaptics) } }
    @Published public var expandNotchOnHover: Bool { didSet { save("expandNotchOnHover", expandNotchOnHover) } }
    @Published public var hoverDuration: Double { didSet { save("hoverDuration", hoverDuration) } }
    @Published public var naturalMovement: Bool { didSet { save("naturalMovement", naturalMovement) } }
    @Published public var swipeToToggle: Bool { didSet { save("swipeToToggle", swipeToToggle) } }
    @Published public var swipeToCycleActivity: Bool { didSet { save("swipeToCycleActivity", swipeToCycleActivity) } }
    @Published public var swipeToDismiss: Bool { didSet { save("swipeToDismiss", swipeToDismiss) } }
    @Published public var swipeToSkip: Bool { didSet { save("swipeToSkip", swipeToSkip) } }
    @Published public var notchAdjustedWidth: Double { didSet { save("notchAdjustedWidth", notchAdjustedWidth) } }
    @Published public var notchAdjustedHeight: Double { didSet { save("notchAdjustedHeight", notchAdjustedHeight) } }
    @Published public var idleActivity: IdleActivityMode { didSet { saveEnum("idleActivity", idleActivity) } }
    @Published public var mostRecentActivity: Bool { didSet { save("mostRecentActivity", mostRecentActivity) } }
    @Published public var forceEnableActivity: Bool { didSet { save("forceEnableActivity", forceEnableActivity) } }
    @Published public var customAccentHex: String { didSet { save("customAccentHex", customAccentHex) } }
    @Published public var notchWingPadding: Double { didSet { save("notchWingPadding", notchWingPadding) } }
    @Published public var animationSpeed: HUDSpeed { didSet { saveEnum("animationSpeed", animationSpeed) } }

    // Battery
    @Published public var enableBattery: Bool { didSet { save("enableBattery", enableBattery) } }
    @Published public var batteryDuration: Double { didSet { save("batteryDuration", batteryDuration) } }
    @Published public var notifyOnLowPowerMode: Bool { didSet { save("notifyOnLowPowerMode", notifyOnLowPowerMode) } }
    @Published public var warnOnLowBattery: Bool { didSet { save("warnOnLowBattery", warnOnLowBattery) } }
    @Published public var lowBatteryThreshold: Double { didSet { save("lowBatteryThreshold", lowBatteryThreshold) } }
    @Published public var playSoundOnLowBattery: Bool { didSet { save("playSoundOnLowBattery", playSoundOnLowBattery) } }
    @Published public var hideBatteryLabel: Bool { didSet { save("hideBatteryLabel", hideBatteryLabel) } }
    @Published public var hideBatteryPercentage: Bool { didSet { save("hideBatteryPercentage", hideBatteryPercentage) } }
    @Published public var allowBatteryWhenFocused: Bool { didSet { save("allowBatteryWhenFocused", allowBatteryWhenFocused) } }
    @Published public var allowBatteryWhenLocked: Bool { didSet { save("allowBatteryWhenLocked", allowBatteryWhenLocked) } }

    // Connectivity
    @Published public var enableConnectivity: Bool { didSet { save("enableConnectivity", enableConnectivity) } }
    @Published public var connectivityDuration: Double { didSet { save("connectivityDuration", connectivityDuration) } }
    @Published public var connectivityModel: ConnectivityModel { didSet { saveEnum("connectivityModel", connectivityModel) } }
    @Published public var warnOnLowConnectBattery: Bool { didSet { save("warnOnLowConnectBattery", warnOnLowConnectBattery) } }
    @Published public var lowConnectBatteryThreshold: Double { didSet { save("lowConnectBatteryThreshold", lowConnectBatteryThreshold) } }
    @Published public var playSoundOnLowConnectBattery: Bool { didSet { save("playSoundOnLowConnectBattery", playSoundOnLowConnectBattery) } }
    @Published public var allowConnectivityWhenFocused: Bool { didSet { save("allowConnectivityWhenFocused", allowConnectivityWhenFocused) } }
    @Published public var allowConnectivityWhenLocked: Bool { didSet { save("allowConnectivityWhenLocked", allowConnectivityWhenLocked) } }

    // Focus
    @Published public var enableFocus: Bool { didSet { save("enableFocus", enableFocus) } }
    @Published public var focusDuration: Double { didSet { save("focusDuration", focusDuration) } }
    @Published public var playSoundOnSleepFocus: Bool { didSet { save("playSoundOnSleepFocus", playSoundOnSleepFocus) } }
    @Published public var replaceWaveformDuringFocus: Bool { didSet { save("replaceWaveformDuringFocus", replaceWaveformDuringFocus) } }
    @Published public var replaceWaveformDuringFocusModeIdentifier: String { didSet { save("replaceWaveformDuringFocusModeIdentifier", replaceWaveformDuringFocusModeIdentifier) } }
    @Published public var hideFocusLabel: Bool { didSet { save("hideFocusLabel", hideFocusLabel) } }
    @Published public var allowFocusWhenLocked: Bool { didSet { save("allowFocusWhenLocked", allowFocusWhenLocked) } }

    // Display (Brightness HUD)
    @Published public var enableBrightness: Bool { didSet { save("enableBrightness", enableBrightness) } }
    @Published public var brightnessDuration: Double { didSet { save("brightnessDuration", brightnessDuration) } }
    @Published public var brightnessProgressStyle: HUDProgressStyle { didSet { saveEnum("brightnessProgressStyle", brightnessProgressStyle) } }
    @Published public var brightnessSpeed: HUDSpeed { didSet { saveEnum("brightnessSpeed", brightnessSpeed) } }
    @Published public var showBrightnessPercentage: Bool { didSet { save("showBrightnessPercentage", showBrightnessPercentage) } }
    @Published public var hideBrightnessLabel: Bool { didSet { save("hideBrightnessLabel", hideBrightnessLabel) } }
    @Published public var allowBrightnessWhenFocused: Bool { didSet { save("allowBrightnessWhenFocused", allowBrightnessWhenFocused) } }
    @Published public var allowBrightnessWhenLocked: Bool { didSet { save("allowBrightnessWhenLocked", allowBrightnessWhenLocked) } }

    // Sound (Volume HUD)
    @Published public var enableVolume: Bool { didSet { save("enableVolume", enableVolume) } }
    @Published public var volumeDuration: Double { didSet { save("volumeDuration", volumeDuration) } }
    @Published public var volumeProgressStyle: HUDProgressStyle { didSet { saveEnum("volumeProgressStyle", volumeProgressStyle) } }
    @Published public var volumeSpeed: HUDSpeed { didSet { saveEnum("volumeSpeed", volumeSpeed) } }
    @Published public var volumeOutputDevice: VolumeOutputDeviceMode { didSet { saveEnum("volumeOutputDevice", volumeOutputDevice) } }
    @Published public var showVolumePercentage: Bool { didSet { save("showVolumePercentage", showVolumePercentage) } }
    @Published public var hideVolumeLabel: Bool { didSet { save("hideVolumeLabel", hideVolumeLabel) } }
    @Published public var linkHUDSettings: Bool { didSet { save("linkHUDSettings", linkHUDSettings) } }
    @Published public var allowVolumeWhenFocused: Bool { didSet { save("allowVolumeWhenFocused", allowVolumeWhenFocused) } }
    @Published public var allowVolumeWhenLocked: Bool { didSet { save("allowVolumeWhenLocked", allowVolumeWhenLocked) } }

    // Now Playing
    @Published public var enableNowPlaying: Bool { didSet { save("enableNowPlaying", enableNowPlaying) } }
    @Published public var automaticMusicApp: Bool { didSet { save("automaticMusicApp", automaticMusicApp) } }
    @Published public var musicApp: NowPlayingMusicApp { didSet { saveEnum("musicApp", musicApp) } }
    @Published public var idleDuration: Double { didSet { save("idleDuration", idleDuration) } }
    @Published public var useLiveWaveform: Bool { didSet { save("useLiveWaveform", useLiveWaveform) } }
    @Published public var disableWaveform: Bool { didSet { save("disableWaveform", disableWaveform) } }
    @Published public var waveformColorStyle: NowPlayingColorStyle { didSet { saveEnum("waveformColorStyle", waveformColorStyle) } }
    @Published public var disableAlbumArtFlip: Bool { didSet { save("disableAlbumArtFlip", disableAlbumArtFlip) } }
    @Published public var hideWhileSourceIsActive: Bool { didSet { save("hideWhileSourceIsActive", hideWhileSourceIsActive) } }
    @Published public var songTitleBadge: NowPlayingTitleBadge { didSet { saveEnum("songTitleBadge", songTitleBadge) } }
    @Published public var hideSongTitleExtras: Bool { didSet { save("hideSongTitleExtras", hideSongTitleExtras) } }
    @Published public var controlChoice: NowPlayingControlChoice { didSet { saveEnum("controlChoice", controlChoice) } }
    @Published public var enableQuickPeek: Bool { didSet { save("enableQuickPeek", enableQuickPeek) } }
    @Published public var whenSongChanges: Bool { didSet { save("whenSongChanges", whenSongChanges) } }
    @Published public var peekDuration: Double { didSet { save("peekDuration", peekDuration) } }
    @Published public var showRemainingTime: Bool { didSet { save("showRemainingTime", showRemainingTime) } }

    // Calendar
    @Published public var enableCalendar: Bool { didSet { save("enableCalendar", enableCalendar) } }
    @Published public var timeBeforeEvent: Double { didSet { save("timeBeforeEvent", timeBeforeEvent) } }
    @Published public var playSoundOnCalendarEvent: Bool { didSet { save("playSoundOnCalendarEvent", playSoundOnCalendarEvent) } }
    @Published public var useCalendarColor: Bool { didSet { save("useCalendarColor", useCalendarColor) } }
    @Published public var useColoredCalendarIndicator: Bool { didSet { save("useColoredCalendarIndicator", useColoredCalendarIndicator) } }
    @Published public var disableActivityDuringEvents: Bool { didSet { save("disableActivityDuringEvents", disableActivityDuringEvents) } }
    @Published public var showWeatherOnEmptyDay: Bool { didSet { save("showWeatherOnEmptyDay", showWeatherOnEmptyDay) } }
    @Published public var useEventIndicators: Bool { didSet { save("useEventIndicators", useEventIndicators) } }
    @Published public var alwaysShowMonthView: Bool { didSet { save("alwaysShowMonthView", alwaysShowMonthView) } }
    @Published public var playHourlyChime: Bool { didSet { save("playHourlyChime", playHourlyChime) } }
    @Published public var notifyWhenTimeToLeave: Bool { didSet { save("notifyWhenTimeToLeave", notifyWhenTimeToLeave) } }
    @Published public var timeToLeaveBuffer: Double { didSet { save("timeToLeaveBuffer", timeToLeaveBuffer) } }
    @Published public var timeToLeaveDuration: Double { didSet { save("timeToLeaveDuration", timeToLeaveDuration) } }
    @Published public var playSoundOnTimeToLeave: Bool { didSet { save("playSoundOnTimeToLeave", playSoundOnTimeToLeave) } }
    @Published public var defaultTransportType: TransportType { didSet { saveEnum("defaultTransportType", defaultTransportType) } }
    @Published public var excludedCalendars: [String] { didSet { save("excludedCalendars", excludedCalendars) } }
    @Published public var enableCalendarQuickPeek: Bool { didSet { save("enableCalendarQuickPeek", enableCalendarQuickPeek) } }
    @Published public var beforeEventStarts: Bool { didSet { save("beforeEventStarts", beforeEventStarts) } }
    @Published public var whenEventIsStarting: Bool { didSet { save("whenEventIsStarting", whenEventIsStarting) } }
    @Published public var calendarPeekDuration: Double { didSet { save("calendarPeekDuration", calendarPeekDuration) } }

    // File Tray (Bonus working shelf)
    @Published public var enableFileTray: Bool { didSet { save("enableFileTray", enableFileTray) } }

    // Lock Screen
    @Published public var enableLockScreen: Bool { didSet { save("enableLockScreen", enableLockScreen) } }
    @Published public var keepAwake: Bool { didSet { save("keepAwake", keepAwake) } }
    @Published public var showOnScreenSaver: Bool { didSet { save("showOnScreenSaver", showOnScreenSaver) } }
    @Published public var playSoundOnLock: Bool { didSet { save("playSoundOnLock", playSoundOnLock) } }
    @Published public var playSoundOnUnlock: Bool { didSet { save("playSoundOnUnlock", playSoundOnUnlock) } }
    @Published public var allowBatteryWidgetWhenLocked: Bool { didSet { save("allowBatteryWidgetWhenLocked", allowBatteryWidgetWhenLocked) } }
    @Published public var allowConnectivityWidgetWhenLocked: Bool { didSet { save("allowConnectivityWidgetWhenLocked", allowConnectivityWidgetWhenLocked) } }
    @Published public var allowFocusWidgetWhenLocked: Bool { didSet { save("allowFocusWidgetWhenLocked", allowFocusWidgetWhenLocked) } }
    @Published public var allowNowPlayingWidgetWhenLocked: Bool { didSet { save("allowNowPlayingWidgetWhenLocked", allowNowPlayingWidgetWhenLocked) } }
    @Published public var allowCalendarWidgetWhenLocked: Bool { didSet { save("allowCalendarWidgetWhenLocked", allowCalendarWidgetWhenLocked) } }
    @Published public var allowWeatherWidgetWhenLocked: Bool { didSet { save("allowWeatherWidgetWhenLocked", allowWeatherWidgetWhenLocked) } }
    @Published public var nowPlayingStyle: LockScreenNowPlayingStyle { didSet { saveEnum("nowPlayingStyle", nowPlayingStyle) } }
    @Published public var showVolumeControlOnLockScreen: Bool { didSet { save("showVolumeControlOnLockScreen", showVolumeControlOnLockScreen) } }
    @Published public var nowPlayingWidgetOffset: Double { didSet { save("nowPlayingWidgetOffset", nowPlayingWidgetOffset) } }
    @Published public var weatherStyle: WeatherStyle { didSet { saveEnum("weatherStyle", weatherStyle) } }
    @Published public var hideIdleDuration: Double { didSet { save("hideIdleDuration", hideIdleDuration) } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isRestoring = true

        self.hasCompletedOnboarding = defaults.object(forKey: "hasCompletedOnboarding") as? Bool ?? false
        self.launchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? false
        self.hideMenuBarIcon = defaults.object(forKey: "hideMenuBarIcon") as? Bool ?? false
        self.hideFromScreenCapture = defaults.object(forKey: "hideFromScreenCapture") as? Bool ?? false
        self.forceSimulatedNotch = defaults.object(forKey: "forceSimulatedNotch") as? Bool ?? false
        self.hideWhileInFullscreen = defaults.object(forKey: "hideWhileInFullscreen") as? Bool ?? true
        self.hideWhileGaming = defaults.object(forKey: "hideWhileGaming") as? Bool ?? true
        self.hideWhileInMissionControl = defaults.object(forKey: "hideWhileInMissionControl") as? Bool ?? false
        self.showOnDisplay = Self.loadEnum(defaults, "showOnDisplay", default: .builtInDisplay)
        self.showOnDisplayUUID = defaults.string(forKey: "showOnDisplayUUID") ?? ""
        self.contrastOutline = defaults.object(forKey: "contrastOutline") as? Bool ?? true
        self.progressiveBlur = defaults.object(forKey: "progressiveBlur") as? Bool ?? true
        self.enableHaptics = defaults.object(forKey: "enableHaptics") as? Bool ?? true
        self.expandNotchOnHover = defaults.object(forKey: "expandNotchOnHover") as? Bool ?? true
        self.hoverDuration = defaults.object(forKey: "hoverDuration") as? Double ?? 0.12
        self.naturalMovement = defaults.object(forKey: "naturalMovement") as? Bool ?? true
        self.swipeToToggle = defaults.object(forKey: "swipeToToggle") as? Bool ?? true
        self.swipeToCycleActivity = defaults.object(forKey: "swipeToCycleActivity") as? Bool ?? true
        self.swipeToDismiss = defaults.object(forKey: "swipeToDismiss") as? Bool ?? true
        self.swipeToSkip = defaults.object(forKey: "swipeToSkip") as? Bool ?? true
        self.notchAdjustedWidth = defaults.object(forKey: "notchAdjustedWidth") as? Double ?? 0.0
        self.notchAdjustedHeight = defaults.object(forKey: "notchAdjustedHeight") as? Double ?? 0.0
        self.idleActivity = Self.loadEnum(defaults, "idleActivity", default: .nowPlaying)
        self.mostRecentActivity = defaults.object(forKey: "mostRecentActivity") as? Bool ?? true
        self.forceEnableActivity = defaults.object(forKey: "forceEnableActivity") as? Bool ?? false
        self.customAccentHex = defaults.string(forKey: "customAccentHex") ?? "#2DD4BF"
        self.notchWingPadding = defaults.object(forKey: "notchWingPadding") as? Double ?? 0.0
        self.animationSpeed = Self.loadEnum(defaults, "animationSpeed", default: .fast)

        self.enableBattery = defaults.object(forKey: "enableBattery") as? Bool ?? true
        self.batteryDuration = defaults.object(forKey: "batteryDuration") as? Double ?? 2.5
        self.notifyOnLowPowerMode = defaults.object(forKey: "notifyOnLowPowerMode") as? Bool ?? true
        self.warnOnLowBattery = defaults.object(forKey: "warnOnLowBattery") as? Bool ?? true
        self.lowBatteryThreshold = defaults.object(forKey: "lowBatteryThreshold") as? Double ?? 20.0
        self.playSoundOnLowBattery = defaults.object(forKey: "playSoundOnLowBattery") as? Bool ?? true
        self.hideBatteryLabel = defaults.object(forKey: "hideBatteryLabel") as? Bool ?? false
        self.hideBatteryPercentage = defaults.object(forKey: "hideBatteryPercentage") as? Bool ?? false
        self.allowBatteryWhenFocused = defaults.object(forKey: "allowBatteryWhenFocused") as? Bool ?? true
        self.allowBatteryWhenLocked = defaults.object(forKey: "allowBatteryWhenLocked") as? Bool ?? true

        self.enableConnectivity = defaults.object(forKey: "enableConnectivity") as? Bool ?? true
        self.connectivityDuration = defaults.object(forKey: "connectivityDuration") as? Double ?? 3.5
        self.connectivityModel = Self.loadEnum(defaults, "connectivityModel", default: .threeDimensional)
        self.warnOnLowConnectBattery = defaults.object(forKey: "warnOnLowConnectBattery") as? Bool ?? true
        self.lowConnectBatteryThreshold = defaults.object(forKey: "lowConnectBatteryThreshold") as? Double ?? 20.0
        self.playSoundOnLowConnectBattery = defaults.object(forKey: "playSoundOnLowConnectBattery") as? Bool ?? false
        self.allowConnectivityWhenFocused = defaults.object(forKey: "allowConnectivityWhenFocused") as? Bool ?? true
        self.allowConnectivityWhenLocked = defaults.object(forKey: "allowConnectivityWhenLocked") as? Bool ?? true

        self.enableFocus = defaults.object(forKey: "enableFocus") as? Bool ?? true
        self.focusDuration = defaults.object(forKey: "focusDuration") as? Double ?? 2.5
        self.playSoundOnSleepFocus = defaults.object(forKey: "playSoundOnSleepFocus") as? Bool ?? false
        self.replaceWaveformDuringFocus = defaults.object(forKey: "replaceWaveformDuringFocus") as? Bool ?? true
        self.replaceWaveformDuringFocusModeIdentifier = defaults.string(forKey: "replaceWaveformDuringFocusModeIdentifier") ?? ""
        self.hideFocusLabel = defaults.object(forKey: "hideFocusLabel") as? Bool ?? false
        self.allowFocusWhenLocked = defaults.object(forKey: "allowFocusWhenLocked") as? Bool ?? true

        self.enableBrightness = defaults.object(forKey: "enableBrightness") as? Bool ?? true
        self.brightnessDuration = defaults.object(forKey: "brightnessDuration") as? Double ?? 1.8
        self.brightnessProgressStyle = Self.loadEnum(defaults, "brightnessProgressStyle", default: .white)
        self.brightnessSpeed = Self.loadEnum(defaults, "brightnessSpeed", default: .fast)
        self.showBrightnessPercentage = defaults.object(forKey: "showBrightnessPercentage") as? Bool ?? false
        self.hideBrightnessLabel = defaults.object(forKey: "hideBrightnessLabel") as? Bool ?? false
        self.allowBrightnessWhenFocused = defaults.object(forKey: "allowBrightnessWhenFocused") as? Bool ?? true
        self.allowBrightnessWhenLocked = defaults.object(forKey: "allowBrightnessWhenLocked") as? Bool ?? true

        self.enableVolume = defaults.object(forKey: "enableVolume") as? Bool ?? true
        self.volumeDuration = defaults.object(forKey: "volumeDuration") as? Double ?? 1.8
        self.volumeProgressStyle = Self.loadEnum(defaults, "volumeProgressStyle", default: .white)
        self.volumeSpeed = Self.loadEnum(defaults, "volumeSpeed", default: .fast)
        self.volumeOutputDevice = Self.loadEnum(defaults, "volumeOutputDevice", default: .device)
        self.showVolumePercentage = defaults.object(forKey: "showVolumePercentage") as? Bool ?? false
        self.hideVolumeLabel = defaults.object(forKey: "hideVolumeLabel") as? Bool ?? false
        self.linkHUDSettings = defaults.object(forKey: "linkHUDSettings") as? Bool ?? false
        self.allowVolumeWhenFocused = defaults.object(forKey: "allowVolumeWhenFocused") as? Bool ?? true
        self.allowVolumeWhenLocked = defaults.object(forKey: "allowVolumeWhenLocked") as? Bool ?? true

        self.enableNowPlaying = defaults.object(forKey: "enableNowPlaying") as? Bool ?? true
        self.automaticMusicApp = defaults.object(forKey: "automaticMusicApp") as? Bool ?? true
        self.musicApp = Self.loadEnum(defaults, "musicApp", default: .system)
        self.idleDuration = defaults.object(forKey: "idleDuration") as? Double ?? 15.0
        self.useLiveWaveform = defaults.object(forKey: "useLiveWaveform") as? Bool ?? true
        self.disableWaveform = defaults.object(forKey: "disableWaveform") as? Bool ?? false
        self.waveformColorStyle = Self.loadEnum(defaults, "waveformColorStyle", default: .artwork)
        self.disableAlbumArtFlip = defaults.object(forKey: "disableAlbumArtFlip") as? Bool ?? false
        self.hideWhileSourceIsActive = defaults.object(forKey: "hideWhileSourceIsActive") as? Bool ?? false
        self.songTitleBadge = Self.loadEnum(defaults, "songTitleBadge", default: .format)
        self.hideSongTitleExtras = defaults.object(forKey: "hideSongTitleExtras") as? Bool ?? false
        self.controlChoice = Self.loadEnum(defaults, "controlChoice", default: .like)
        self.enableQuickPeek = defaults.object(forKey: "enableQuickPeek") as? Bool ?? true
        self.whenSongChanges = defaults.object(forKey: "whenSongChanges") as? Bool ?? true
        self.peekDuration = defaults.object(forKey: "peekDuration") as? Double ?? 3.5
        self.showRemainingTime = defaults.object(forKey: "showRemainingTime") as? Bool ?? true

        self.enableCalendar = defaults.object(forKey: "enableCalendar") as? Bool ?? true
        self.timeBeforeEvent = defaults.object(forKey: "timeBeforeEvent") as? Double ?? 900.0
        self.playSoundOnCalendarEvent = defaults.object(forKey: "playSoundOnCalendarEvent") as? Bool ?? true
        self.useCalendarColor = defaults.object(forKey: "useCalendarColor") as? Bool ?? true
        self.useColoredCalendarIndicator = defaults.object(forKey: "useColoredCalendarIndicator") as? Bool ?? true
        self.disableActivityDuringEvents = defaults.object(forKey: "disableActivityDuringEvents") as? Bool ?? false
        self.showWeatherOnEmptyDay = defaults.object(forKey: "showWeatherOnEmptyDay") as? Bool ?? true
        self.useEventIndicators = defaults.object(forKey: "useEventIndicators") as? Bool ?? true
        self.alwaysShowMonthView = defaults.object(forKey: "alwaysShowMonthView") as? Bool ?? false
        self.playHourlyChime = defaults.object(forKey: "playHourlyChime") as? Bool ?? false
        self.notifyWhenTimeToLeave = defaults.object(forKey: "notifyWhenTimeToLeave") as? Bool ?? false
        self.timeToLeaveBuffer = defaults.object(forKey: "timeToLeaveBuffer") as? Double ?? 300.0
        self.timeToLeaveDuration = defaults.object(forKey: "timeToLeaveDuration") as? Double ?? 5.0
        self.playSoundOnTimeToLeave = defaults.object(forKey: "playSoundOnTimeToLeave") as? Bool ?? true
        self.defaultTransportType = Self.loadEnum(defaults, "defaultTransportType", default: .drive)
        self.excludedCalendars = defaults.stringArray(forKey: "excludedCalendars") ?? []
        self.enableCalendarQuickPeek = defaults.object(forKey: "enableCalendarQuickPeek") as? Bool ?? true
        self.beforeEventStarts = defaults.object(forKey: "beforeEventStarts") as? Bool ?? true
        self.whenEventIsStarting = defaults.object(forKey: "whenEventIsStarting") as? Bool ?? true
        self.calendarPeekDuration = defaults.object(forKey: "calendarPeekDuration") as? Double ?? 4.0

        self.enableFileTray = defaults.object(forKey: "enableFileTray") as? Bool ?? true

        self.enableLockScreen = defaults.object(forKey: "enableLockScreen") as? Bool ?? true
        self.keepAwake = defaults.object(forKey: "keepAwake") as? Bool ?? false
        self.showOnScreenSaver = defaults.object(forKey: "showOnScreenSaver") as? Bool ?? true
        self.playSoundOnLock = defaults.object(forKey: "playSoundOnLock") as? Bool ?? false
        self.playSoundOnUnlock = defaults.object(forKey: "playSoundOnUnlock") as? Bool ?? false
        self.allowBatteryWidgetWhenLocked = defaults.object(forKey: "allowBatteryWidgetWhenLocked") as? Bool ?? true
        self.allowConnectivityWidgetWhenLocked = defaults.object(forKey: "allowConnectivityWidgetWhenLocked") as? Bool ?? true
        self.allowFocusWidgetWhenLocked = defaults.object(forKey: "allowFocusWidgetWhenLocked") as? Bool ?? true
        self.allowNowPlayingWidgetWhenLocked = defaults.object(forKey: "allowNowPlayingWidgetWhenLocked") as? Bool ?? true
        self.allowCalendarWidgetWhenLocked = defaults.object(forKey: "allowCalendarWidgetWhenLocked") as? Bool ?? true
        self.allowWeatherWidgetWhenLocked = defaults.object(forKey: "allowWeatherWidgetWhenLocked") as? Bool ?? true
        self.nowPlayingStyle = Self.loadEnum(defaults, "nowPlayingStyle", default: .glass)
        self.showVolumeControlOnLockScreen = defaults.object(forKey: "showVolumeControlOnLockScreen") as? Bool ?? true
        self.nowPlayingWidgetOffset = defaults.object(forKey: "nowPlayingWidgetOffset") as? Double ?? 0.0
        self.weatherStyle = Self.loadEnum(defaults, "weatherStyle", default: .conditions)
        self.hideIdleDuration = defaults.object(forKey: "hideIdleDuration") as? Double ?? 0.0

        self.isRestoring = false
    }

    public var accentColor: Color {
        OrielColors.color(fromHex: customAccentHex)
    }

    private func save(_ key: String, _ value: Any) {
        guard !isRestoring else { return }
        defaults.set(value, forKey: key)
    }

    private func saveEnum<T: RawRepresentable>(_ key: String, _ value: T) where T.RawValue == String {
        guard !isRestoring else { return }
        defaults.set(value.rawValue, forKey: key)
    }

    private static func loadEnum<T: RawRepresentable>(_ defaults: UserDefaults, _ key: String, default fallback: T) -> T where T.RawValue == String {
        guard let raw = defaults.string(forKey: key), let val = T(rawValue: raw) else {
            return fallback
        }
        return val
    }
}
