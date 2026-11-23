import AppKit
import SwiftUI
import OrielCore

/// Overlay widgets rendered on the Lock Screen (Now Playing, Weather, Calendar, Focus,
/// Connectivity, Battery) over the elevated Lock Screen space using Clear / Frosted / Glass styling.
public struct LockScreenView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var media = MediaManager.shared
    @ObservedObject private var volume = VolumeManager.shared
    @ObservedObject private var weather = WeatherManager.shared
    @ObservedObject private var calendar = CalendarManager.shared
    @ObservedObject private var focus = FocusManager.shared
    @ObservedObject private var connectivity = ConnectivityManager.shared
    @ObservedObject private var battery = BatteryManager.shared

    public init() {}

    public static func safeBottomClearance(forScreenHeight height: CGFloat) -> CGFloat {
        // macOS Lock Screen places the user avatar, name, password box, and Touch ID prompt
        // in the bottom ~225–245pt; 276pt / 30% keeps all widgets cleanly above the avatar
        // while staying comfortably below the top clock (~230pt from top).
        max(276, height * 0.30)
    }

    public var body: some View {
        GeometryReader { geo in
            let bottomClearance = Self.safeBottomClearance(forScreenHeight: geo.size.height)
            VStack(spacing: 0) {
                Spacer(minLength: max(220, geo.size.height * 0.25))

                VStack(spacing: 12) {
                    statusWidgetsRow

                    if settings.allowNowPlayingWidgetWhenLocked && (media.track.hasTrack || settings.forceEnableActivity) {
                        nowPlayingCard
                    }
                }
                .offset(y: settings.nowPlayingWidgetOffset)
                .padding(.bottom, bottomClearance)
                .padding(.horizontal, 32)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @ViewBuilder
    private var statusWidgetsRow: some View {
        HStack(spacing: 10) {
            if settings.allowWeatherWidgetWhenLocked, let w = weather.weather {
                LockScreenWidgetSurface(style: settings.nowPlayingStyle, cornerRadius: 16) {
                    HStack(spacing: 7) {
                        Image(systemName: w.symbolName)
                            .font(.system(size: 14, weight: .semibold))
                            .symbolRenderingMode(.multicolor)
                        switch settings.weatherStyle {
                        case .conditions:
                            Text("\(Int(round(w.temperatureCelsius)))° • \(w.conditionDescription)")
                                .font(.system(size: 12.5, weight: .medium))
                        case .sun:
                            Text("\(Int(round(w.temperatureCelsius)))° • \(w.isDaylight ? "Daylight" : "Night")")
                                .font(.system(size: 12.5, weight: .medium))
                        case .precipitation:
                            Text("\(w.precipitationChance)% rain")
                                .font(.system(size: 12.5, weight: .medium))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }

            if settings.allowCalendarWidgetWhenLocked, let ev = calendar.nextRelevantEvent {
                LockScreenWidgetSurface(style: settings.nowPlayingStyle, cornerRadius: 16) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(OrielColors.color(fromHex: ev.colorHex))
                            .frame(width: 7, height: 7)
                        Text(ev.title)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(timeFormatter.string(from: ev.startDate))
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }

            if settings.allowFocusWidgetWhenLocked, focus.isFocusActive, let mode = focus.activeFocusMode {
                LockScreenWidgetSurface(style: settings.nowPlayingStyle, cornerRadius: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: mode.symbol)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(mode.tintColor)
                        Text(mode.name)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }

            if settings.allowConnectivityWidgetWhenLocked, let dev = connectivity.activeOutputDevice {
                LockScreenWidgetSurface(style: settings.nowPlayingStyle, cornerRadius: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: dev.symbolName)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(OrielColors.sky)
                        Text(dev.name)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if let pct = dev.effectiveBattery {
                            Text("\(pct)%")
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(OrielColors.charging)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }

            if settings.allowBatteryWidgetWhenLocked {
                LockScreenWidgetSurface(style: settings.nowPlayingStyle, cornerRadius: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: battery.isCharging ? "battery.100percent.bolt" : "battery.75percent")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(battery.isCharging ? OrielColors.charging : (battery.batteryLevel <= 20 ? OrielColors.lowBattery : .white))
                        Text("\(battery.batteryLevel)%")
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var nowPlayingCard: some View {
        LockScreenWidgetSurface(style: settings.nowPlayingStyle, cornerRadius: 22) {
            VStack(spacing: 9) {
                HStack(spacing: 11) {
                    if let img = media.artworkImage {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.7)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white.opacity(0.8))
                            )
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        MarqueeText(
                            media.track.hasTrack ? media.track.title : "Oriel Now Playing",
                            font: .system(size: 13.5, weight: .semibold),
                            color: .white
                        )
                        Text(media.track.hasTrack ? media.track.artist : "Ready for playback")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        LiquidGlassIconButton(systemName: "backward.fill", size: 26, iconSize: 12) {
                            media.previousTrack()
                        }

                        LiquidGlassIconButton(systemName: media.track.isPlaying ? "pause.fill" : "play.fill", size: 32, iconSize: 14.5, prominent: true) {
                            media.togglePlayPause()
                        }

                        LiquidGlassIconButton(systemName: "forward.fill", size: 26, iconSize: 12) {
                            media.nextTrack()
                        }
                    }
                }

                if settings.showVolumeControlOnLockScreen {
                    HStack(spacing: 8) {
                        Image(systemName: volume.isMuted ? "speaker.slash.fill" : "speaker.wave.1.fill")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.white.opacity(0.7))
                        Slider(
                            value: Binding(
                                get: { Double(volume.volume) },
                                set: { volume.setVolume(Float($0), notify: false) }
                            ),
                            in: 0...1
                        )
                        .tint(.white)
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .padding(12)
            .frame(width: 332)
        }
    }

    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }
}
