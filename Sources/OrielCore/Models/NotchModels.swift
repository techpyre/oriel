import Foundation
import AppKit
import SwiftUI

// MARK: - Live Activity & Notifications

public enum LiveActivity: Equatable, Sendable {
    case none
    case isLocked
    case isAdjusting
    case isCalendar
    case isPlaying
}

public enum ExpandedActivity: String, CaseIterable, Equatable, Sendable {
    case nowPlaying
    case calendar
    case duo
    case fileTray
}

public enum NotchNotification: Equatable, Sendable {
    case none
    case isCharging(level: Int)
    case isLowBattery(level: Int)
    case isLowPowerMode
    case didConnectAirPods(name: String, symbol: String, battery: Int?)
    case isLowAirPodsBattery(name: String, symbol: String, battery: Int)
    case isFocus(mode: FocusMode, active: Bool)
    case didChangeVolume(level: Float, isMuted: Bool, deviceName: String, deviceSymbol: String)
    case didChangeBrightness(level: Float, isExternal: Bool)
    case timeToLeave(title: String, minutes: Int, transport: TransportType)
}

public enum QuickPeekContent: Equatable, Sendable {
    case none
    case track(title: String, artist: String, artworkData: Data?)
    case calendarEvent(title: String, startDate: Date, colorHex: String, meetingURL: URL?)
}

// MARK: - Domain Models

public struct FocusMode: Equatable, Identifiable, Sendable {
    public var id: String { identifier }
    public let identifier: String
    public let name: String
    public let symbol: String
    public let tintColor: Color

    public init(identifier: String, name: String, symbol: String, tintColor: Color) {
        self.identifier = identifier
        self.name = name
        self.symbol = symbol
        self.tintColor = tintColor
    }
}

public struct MediaTrackInfo: Equatable, Sendable {
    public var title: String
    public var artist: String
    public var album: String
    public var artworkData: Data?
    public var duration: TimeInterval
    public var elapsedTime: TimeInterval
    public var timestamp: Date
    public var playbackRate: Double
    public var isPlaying: Bool
    public var isExplicit: Bool
    public var isLossless: Bool
    public var isDolbyAtmos: Bool
    public var isPodcast: Bool
    public var isLive: Bool
    public var isLoved: Bool
    public var isShuffled: Bool
    public var repeatMode: Int // 0 = off, 1 = one, 2 = all
    public var sourceBundleID: String
    public var sourceAppName: String
    public var audioPID: pid_t
    public var shareURL: URL?

    public init(
        title: String = "",
        artist: String = "",
        album: String = "",
        artworkData: Data? = nil,
        duration: TimeInterval = 0,
        elapsedTime: TimeInterval = 0,
        timestamp: Date = Date(),
        playbackRate: Double = 0,
        isPlaying: Bool = false,
        isExplicit: Bool = false,
        isLossless: Bool = false,
        isDolbyAtmos: Bool = false,
        isPodcast: Bool = false,
        isLive: Bool = false,
        isLoved: Bool = false,
        isShuffled: Bool = false,
        repeatMode: Int = 0,
        sourceBundleID: String = "",
        sourceAppName: String = "",
        audioPID: pid_t = 0,
        shareURL: URL? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkData = artworkData
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.timestamp = timestamp
        self.playbackRate = playbackRate
        self.isPlaying = isPlaying
        self.isExplicit = isExplicit
        self.isLossless = isLossless
        self.isDolbyAtmos = isDolbyAtmos
        self.isPodcast = isPodcast
        self.isLive = isLive
        self.isLoved = isLoved
        self.isShuffled = isShuffled
        self.repeatMode = repeatMode
        self.sourceBundleID = sourceBundleID
        self.sourceAppName = sourceAppName
        self.audioPID = audioPID
        self.shareURL = shareURL
    }

    public var hasTrack: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func currentPosition(at date: Date = Date()) -> TimeInterval {
        guard duration > 0 else { return 0 }
        let delta = isPlaying ? max(0, date.timeIntervalSince(timestamp)) * max(playbackRate, 1.0) : 0
        return min(duration, max(0, elapsedTime + delta))
    }
}

public struct CalendarEventItem: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let calendarID: String
    public let calendarTitle: String
    public let colorHex: String
    public let location: String?
    public let meetingURL: URL?
    public let meetingProvider: String?

    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        calendarID: String,
        calendarTitle: String,
        colorHex: String,
        location: String? = nil,
        meetingURL: URL? = nil,
        meetingProvider: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarID = calendarID
        self.calendarTitle = calendarTitle
        self.colorHex = colorHex
        self.location = location
        self.meetingURL = meetingURL
        self.meetingProvider = meetingProvider
    }
}

public struct AudioDeviceInfo: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let modelIdentifier: String?
    public let symbolName: String
    public let transportType: String
    public let batterySingle: Int?
    public let batteryLeft: Int?
    public let batteryRight: Int?
    public let batteryCase: Int?
    public let isAirPods: Bool

    public init(
        id: String,
        name: String,
        modelIdentifier: String? = nil,
        symbolName: String = "headphones",
        transportType: String = "Bluetooth",
        batterySingle: Int? = nil,
        batteryLeft: Int? = nil,
        batteryRight: Int? = nil,
        batteryCase: Int? = nil,
        isAirPods: Bool = false
    ) {
        self.id = id
        self.name = name
        self.modelIdentifier = modelIdentifier
        self.symbolName = symbolName
        self.transportType = transportType
        self.batterySingle = batterySingle
        self.batteryLeft = batteryLeft
        self.batteryRight = batteryRight
        self.batteryCase = batteryCase
        self.isAirPods = isAirPods
    }

    public var effectiveBattery: Int? {
        if let s = batterySingle { return s }
        let values = [batteryLeft, batteryRight].compactMap { $0 }
        return values.min()
    }
}

public struct WeatherSnapshot: Equatable, Sendable {
    public let temperatureCelsius: Double
    public let conditionCode: Int
    public let conditionDescription: String
    public let symbolName: String
    public let isDaylight: Bool
    public let precipitationChance: Int
    public let isRaining: Bool
    public let lastFetchDate: Date

    public init(
        temperatureCelsius: Double,
        conditionCode: Int,
        conditionDescription: String,
        symbolName: String,
        isDaylight: Bool,
        precipitationChance: Int,
        isRaining: Bool,
        lastFetchDate: Date = Date()
    ) {
        self.temperatureCelsius = temperatureCelsius
        self.conditionCode = conditionCode
        self.conditionDescription = conditionDescription
        self.symbolName = symbolName
        self.isDaylight = isDaylight
        self.precipitationChance = precipitationChance
        self.isRaining = isRaining
        self.lastFetchDate = lastFetchDate
    }
}

public struct TrayFileItem: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let addedAt: Date

    public init(id: UUID = UUID(), url: URL, name: String? = nil, addedAt: Date = Date()) {
        self.id = id
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.addedAt = addedAt
    }
}

// MARK: - Notch Geometry Metrics

public struct NotchMetrics: Equatable, Sendable {
    public let hasPhysicalNotch: Bool
    public let isSimulated: Bool
    public let notchWidth: CGFloat
    public let notchHeight: CGFloat
    public let topCornerRadius: CGFloat
    public let bottomCornerRadius: CGFloat

    public static func compute(
        screenFrame: CGRect,
        safeAreaTop: CGFloat,
        auxLeft: CGRect?,
        auxRight: CGRect?,
        adjustedWidth: CGFloat,
        adjustedHeight: CGFloat,
        forceSimulated: Bool
    ) -> NotchMetrics {
        let physicalNotch: Bool
        let baseWidth: CGFloat
        let baseHeight: CGFloat

        if safeAreaTop > 0, let left = auxLeft, let right = auxRight {
            let computedWidth = max(120, screenFrame.width - left.width - right.width)
            physicalNotch = true
            baseWidth = computedWidth
            baseHeight = safeAreaTop
        } else {
            physicalNotch = false
            baseWidth = 180
            baseHeight = 32
        }

        let isModernOS = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26
        let topRadius: CGFloat = isModernOS ? 13.0 : 9.0
        let bottomRadius: CGFloat = isModernOS ? 13.0 : 9.0

        return NotchMetrics(
            hasPhysicalNotch: physicalNotch,
            isSimulated: !physicalNotch && forceSimulated,
            notchWidth: max(120, baseWidth + adjustedWidth),
            notchHeight: max(24, baseHeight + adjustedHeight),
            topCornerRadius: topRadius,
            bottomCornerRadius: bottomRadius
        )
    }

    @MainActor
    public static func forScreen(_ screen: NSScreen, adjustedWidth: CGFloat = 0, adjustedHeight: CGFloat = 0, forceSimulated: Bool = false) -> NotchMetrics {
        compute(
            screenFrame: screen.frame,
            safeAreaTop: screen.safeAreaInsets.top,
            auxLeft: screen.auxiliaryTopLeftArea,
            auxRight: screen.auxiliaryTopRightArea,
            adjustedWidth: adjustedWidth,
            adjustedHeight: adjustedHeight,
            forceSimulated: forceSimulated
        )
    }
}
