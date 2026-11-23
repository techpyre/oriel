import AppKit
import SwiftUI
import UniformTypeIdentifiers
import OrielCore

// MARK: - Root Notch View

public struct NotchView: View {
    @ObservedObject private var controller = NotchController.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var media = MediaManager.shared
    @ObservedObject private var calendar = CalendarManager.shared
    @ObservedObject private var focus = FocusManager.shared
    @ObservedObject private var weather = WeatherManager.shared
    @ObservedObject private var tray = FileTrayManager.shared

    @Namespace private var tabPillNS

    @State private var flipAngle: Double = 0
    @State private var isDropTargeted: Bool = false
    @State private var expandedContentVisible: Bool = false
    @State private var hudIconBounce: Bool = false

    public init() {}

    private var shouldDrawSilhouette: Bool {
        if controller.isHidden && !controller.isExpanded { return false }
        if controller.isExpanded || controller.quickPeek != .none || controller.notification != .none {
            return true
        }
        if controller.liveActivity != .none {
            return true
        }
        return controller.metrics.isSimulated || settings.forceSimulatedNotch
    }

    private var topR: CGFloat {
        controller.isExpanded ? 14 : 9
    }

    private var botR: CGFloat {
        controller.isExpanded ? 22 : (controller.quickPeek != .none ? 18 : 11)
    }

    private var renderedWidth: CGFloat {
        let base = controller.currentWidth
        let hoverBreath: CGFloat = (controller.isHovered && !controller.isExpanded && controller.notification == .none && controller.quickPeek == .none && controller.liveActivity != .none) ? 6 : 0
        let dropBreath: CGFloat = isDropTargeted ? 12 : 0
        return max(controller.metrics.notchWidth, base + hoverBreath + dropBreath + controller.hudElasticStretch)
    }

    private var renderedHeight: CGFloat {
        let base = controller.currentHeight
        let hoverBreath: CGFloat = (controller.isHovered && !controller.isExpanded && controller.notification == .none && controller.quickPeek == .none && controller.liveActivity != .none) ? 2 : 0
        let dropBreath: CGFloat = isDropTargeted ? 4 : 0
        return base + hoverBreath + dropBreath
    }

    private var activeAmbientTint: Color {
        if isDropTargeted {
            return OrielColors.teal
        }
        if controller.notification != .none {
            switch controller.notification {
            case .didChangeVolume(_, let muted, _, _):
                return muted ? OrielColors.lowBattery : settings.accentColor
            case .didChangeBrightness:
                return OrielColors.amber
            case .isCharging:
                return OrielColors.charging
            case .isLowBattery, .isLowAirPodsBattery:
                return OrielColors.lowBattery
            case .isLowPowerMode:
                return OrielColors.amber
            case .didConnectAirPods:
                return OrielColors.sky
            case .isFocus(let mode, _):
                return mode.tintColor
            case .timeToLeave:
                return OrielColors.orange
            case .none:
                break
            }
        }
        if (controller.expandedActivity == .nowPlaying || controller.expandedActivity == .duo),
           media.track.hasTrack,
           let primary = media.dominantColors.first {
            return primary
        }
        return settings.accentColor
    }

    public var body: some View {
        let shape = NotchShape(topCornerRadius: topR, bottomCornerRadius: botR)
        let width = renderedWidth
        let height = renderedHeight
        let isOverlay = controller.quickPeek != .none || controller.notification != .none

        ZStack(alignment: .top) {
            if shouldDrawSilhouette {
                ZStack {
                    LiquidNotchSurface(
                        shape: shape,
                        notchWidth: controller.metrics.notchWidth,
                        notchHeight: controller.metrics.notchHeight,
                        hasPhysicalNotch: controller.metrics.hasPhysicalNotch,
                        isExpanded: controller.isExpanded,
                        isCompactOverlay: isOverlay,
                        isHovered: controller.isHovered || isDropTargeted,
                        accentTint: activeAmbientTint,
                        blurredArtwork: (controller.isExpanded && (controller.expandedActivity == .nowPlaying || controller.expandedActivity == .duo) && media.track.hasTrack) ? media.blurredArtworkImage : nil,
                        dominantColors: media.dominantColors,
                        showOutline: settings.contrastOutline || controller.isExpanded || controller.isHovered
                    )

                    notchContent
                        .padding(.horizontal, topR + 6)
                        .padding(.top, controller.isExpanded ? 0 : 2)
                        .padding(.bottom, controller.isExpanded ? 9 : 2)
                }
                .frame(width: width, height: height)
                .clipShape(shape)
                .overlay {
                    if isDropTargeted {
                        shape
                            .strokeBorder(OrielColors.teal.opacity(0.95), lineWidth: 1.8)
                    }
                }
                .contentShape(shape)
                .scaleEffect(isDropTargeted ? 1.02 : 1.0, anchor: .top)
                .offset(x: controller.swipeOffsetX, y: max(0, controller.swipeOffsetY))
                .shadow(
                    color: Color.black.opacity(controller.isExpanded ? 0.36 : 0.22),
                    radius: controller.isExpanded ? 12 : 6,
                    x: 0,
                    y: controller.isExpanded ? 6 : 3
                )
                .animation(OrielMotion.liquidMorph, value: isDropTargeted)
                .animation(.spring(duration: 0.20, bounce: 0.10), value: controller.swipeOffsetX)
                .animation(.spring(duration: 0.20, bounce: 0.10), value: controller.swipeOffsetY)
                .onTapGesture {
                    if !controller.isExpanded {
                        controller.setExpanded(true)
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                    handleFileDrop(providers: providers)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: controller.isExpanded) { _, expanded in
            if expanded {
                expandedContentVisible = true
            } else {
                expandedContentVisible = false
            }
        }
        .onChange(of: controller.hudPulseToken) { _, _ in
            hudIconBounce = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                hudIconBounce = false
            }
        }
        .onChange(of: media.artworkFlipped) { _, flipped in
            guard !settings.disableAlbumArtFlip else { return }
            withAnimation(.spring(duration: 0.38, bounce: 0.16)) {
                flipAngle = flipped ? 360 : 0
            }
        }
    }

    @ViewBuilder
    private var notchContent: some View {
        if controller.isExpanded {
            expandedView
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
        } else if controller.quickPeek != .none {
            quickPeekView
                .transition(.opacity.combined(with: .offset(y: -4)))
        } else if controller.notification != .none {
            notificationView(controller.notification)
                .transition(.opacity)
        } else {
            closedLiveActivityView
                .transition(.opacity)
        }
    }

    private var centerNotchGap: CGFloat {
        controller.metrics.hasPhysicalNotch
            ? (controller.metrics.notchWidth + 12)
            : max(20, controller.metrics.notchWidth * 0.26)
    }

    @ViewBuilder
    private func notchWingColumns<Left: View, Right: View>(
        @ViewBuilder left: () -> Left,
        @ViewBuilder right: () -> Right
    ) -> some View {
        let total = renderedWidth
        let horizontalPad = (topR + 6) * 2
        let gap = centerNotchGap
        let wingW = max(32, (total - horizontalPad - gap) / 2)

        HStack(spacing: 0) {
            left()
                .frame(width: wingW, alignment: .leading)
                .clipped()

            Spacer()
                .frame(width: gap)

            right()
                .frame(width: wingW, alignment: .trailing)
                .clipped()
        }
    }

    // MARK: - Closed Live Activity Ears

    @ViewBuilder
    private var closedLiveActivityView: some View {
        switch controller.liveActivity {
        case .none:
            Color.clear
        case .isLocked:
            notchWingColumns {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OrielColors.amber)
            } right: {
                Image(systemName: "key.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
            }
        case .isPlaying:
            notchWingColumns {
                Group {
                    if let img = media.artworkImage {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 5.5, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                                    .strokeBorder(Color.white.opacity(controller.isHovered ? 0.42 : 0.22), lineWidth: 0.6)
                            )
                            .scaleEffect(media.track.isPlaying ? (controller.isHovered ? 1.07 : 1.0) : 0.90)
                            .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0))
                            .animation(.spring(duration: 0.24, bounce: 0.14), value: media.track.isPlaying)
                            .animation(.spring(duration: 0.20, bounce: 0.14), value: controller.isHovered)
                    } else {
                        RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.9))
                            )
                    }
                }
            } right: {
                rightPlayingIndicator
            }
        case .isCalendar:
            if let event = calendar.nextRelevantEvent {
                notchWingColumns {
                    Circle()
                        .fill(settings.useColoredCalendarIndicator ? OrielColors.color(fromHex: event.colorHex) : Color.white)
                        .frame(width: 8, height: 8)
                        .padding(.leading, 4)
                } right: {
                    Text(shortCountdown(to: event.startDate))
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(OrielColors.color(fromHex: event.colorHex))
                }
            } else {
                notchWingColumns {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(OrielColors.orange)
                } right: {
                    Text("Cal")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        case .isAdjusting:
            Color.clear
        }
    }

    @ViewBuilder
    private var rightPlayingIndicator: some View {
        if let focusMode = matchingFocusForWaveform {
            Image(systemName: focusMode.symbol)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(focusMode.tintColor)
        } else if settings.disableWaveform {
            Image(systemName: media.track.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 10.5, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(.white.opacity(0.82))
        } else {
            LiveAudioWaveform(
                isPlaying: media.track.isPlaying,
                useLiveLevels: settings.useLiveWaveform,
                tint: resolvedWaveformColor,
                barWidth: 2.0,
                spacing: 1.6,
                maxHeight: 13
            )
        }
    }

    private var matchingFocusForWaveform: FocusMode? {
        guard settings.replaceWaveformDuringFocus,
              focus.isFocusActive,
              let active = focus.activeFocusMode else { return nil }
        if settings.replaceWaveformDuringFocusModeIdentifier.isEmpty ||
            settings.replaceWaveformDuringFocusModeIdentifier == active.identifier {
            return active
        }
        return nil
    }

    private var resolvedWaveformColor: Color {
        switch settings.waveformColorStyle {
        case .artwork, .gradient:
            return media.dominantColors.first ?? settings.accentColor
        case .color:
            return settings.accentColor
        case .mono:
            return .white
        }
    }

    // MARK: - HUD Notifications

    @ViewBuilder
    private func notificationView(_ note: NotchNotification) -> some View {
        switch note {
        case .isCharging(let level):
            notchWingColumns {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(OrielColors.charging)
                    if !settings.hideBatteryLabel {
                        Text("Charging")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.94))
                            .lineLimit(1)
                    }
                }
            } right: {
                HStack(spacing: 4) {
                    if !settings.hideBatteryPercentage {
                        Text("\(level)%")
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundStyle(OrielColors.charging)
                    }
                    Image(systemName: "battery.100percent.bolt")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(OrielColors.charging)
                }
            }

        case .isLowBattery(let level):
            notchWingColumns {
                HStack(spacing: 5) {
                    Image(systemName: "battery.25percent")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(OrielColors.lowBattery)
                    if !settings.hideBatteryLabel {
                        Text("Low Battery")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(OrielColors.lowBattery)
                            .lineLimit(1)
                    }
                }
            } right: {
                Text("\(level)%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(OrielColors.lowBattery)
            }

        case .isLowPowerMode:
            notchWingColumns {
                HStack(spacing: 5) {
                    Image(systemName: "battery.50percent")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(OrielColors.amber)
                    Text("Low Power")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            } right: {
                Text("ON")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(OrielColors.amber)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(OrielColors.amber.opacity(0.18), in: Capsule())
            }

        case .didConnectAirPods(let name, let symbol, let battery):
            notchWingColumns {
                HStack(spacing: 5) {
                    Image(systemName: symbol)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(OrielColors.sky)
                        .scaleEffect(hudIconBounce ? 1.16 : 1.0)
                        .animation(OrielMotion.elasticTap, value: hudIconBounce)
                    Text(name)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } right: {
                if let battery {
                    Text("\(battery)%")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(OrielColors.charging)
                } else {
                    Text("Connected")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(OrielColors.sky)
                }
            }

        case .isLowAirPodsBattery(let name, let symbol, let battery):
            notchWingColumns {
                HStack(spacing: 5) {
                    Image(systemName: symbol)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(OrielColors.lowBattery)
                    Text(name)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } right: {
                Text("\(battery)%")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(OrielColors.lowBattery)
            }

        case .isFocus(let mode, let active):
            notchWingColumns {
                HStack(spacing: 5) {
                    Image(systemName: mode.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(active ? mode.tintColor : .white.opacity(0.55))
                    if !settings.hideFocusLabel {
                        Text(mode.name)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            } right: {
                Text(active ? "On" : "Off")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(active ? mode.tintColor : .white.opacity(0.5))
            }

        case .didChangeVolume(let level, let isMuted, let deviceName, let deviceSymbol):
            notchWingColumns {
                HStack(spacing: 5) {
                    let sym = (settings.volumeOutputDevice == .device) ? deviceSymbol : volumeSymbol(level: level, isMuted: isMuted)
                    Image(systemName: sym)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isMuted ? OrielColors.lowBattery : .white)
                        .contentTransition(.symbolEffect(.replace))
                        .scaleEffect(hudIconBounce ? 1.16 : 1.0)
                        .animation(OrielMotion.elasticTap, value: hudIconBounce)
                        .frame(width: 15)
                    if !settings.hideVolumeLabel {
                        Text(settings.volumeOutputDevice == .device ? deviceName : "Volume")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.94))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            } right: {
                HStack(spacing: 5) {
                    HUDProgressBar(
                        value: isMuted ? 0 : Double(level),
                        style: settings.volumeProgressStyle,
                        tint: settings.accentColor,
                        isMuted: isMuted
                    )
                    .frame(maxWidth: 72)

                    if settings.showVolumePercentage && settings.volumeProgressStyle != .decibel {
                        Text(isMuted ? "0%" : "\(Int(round(level * 100)))%")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundStyle(.white.opacity(0.84))
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }

        case .didChangeBrightness(let level, let isExternal):
            notchWingColumns {
                HStack(spacing: 5) {
                    Image(systemName: isExternal ? "display" : "sun.max.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(OrielColors.amber)
                        .rotationEffect(.degrees(isExternal ? 0 : Double(level) * 90))
                        .scaleEffect(hudIconBounce ? 1.15 : (0.94 + Double(level) * 0.12))
                        .animation(.spring(duration: 0.22, bounce: 0.14), value: level)
                        .animation(OrielMotion.elasticTap, value: hudIconBounce)
                        .frame(width: 15)
                    if !settings.hideBrightnessLabel {
                        Text(isExternal ? "Display" : "Brightness")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.94))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            } right: {
                HStack(spacing: 5) {
                    HUDProgressBar(
                        value: Double(level),
                        style: settings.brightnessProgressStyle,
                        tint: OrielColors.amber
                    )
                    .frame(maxWidth: 72)

                    if settings.showBrightnessPercentage {
                        Text("\(Int(round(level * 100)))%")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundStyle(.white.opacity(0.84))
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }

        case .timeToLeave(let title, let minutes, let transport):
            notchWingColumns {
                HStack(spacing: 5) {
                    Image(systemName: transport.symbolName)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(OrielColors.sky)
                    Text(title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } right: {
                Text("Leave in \(minutes)m")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(OrielColors.amber)
            }

        case .none:
            EmptyView()
        }
    }

    // MARK: - Liquid Glass Quick Peek Banner

    @ViewBuilder
    private var quickPeekView: some View {
        VStack(spacing: 0) {
            if controller.metrics.hasPhysicalNotch {
                Spacer().frame(height: controller.metrics.notchHeight)
            }

            switch controller.quickPeek {
            case .track(let title, let artist, _):
                HStack(spacing: 10) {
                    if let img = media.artworkImage {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 30, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.26), lineWidth: 0.65)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 30, height: 30)
                            .overlay(Image(systemName: "music.note").font(.system(size: 12)).foregroundStyle(.white.opacity(0.85)))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        MarqueeText(title, font: .system(size: 12, weight: .semibold), color: .white)
                        Text(artist)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.white.opacity(0.68))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    LiveAudioWaveform(
                        isPlaying: true,
                        useLiveLevels: settings.useLiveWaveform,
                        tint: resolvedWaveformColor,
                        barWidth: 2,
                        spacing: 1.5,
                        maxHeight: 13
                    )
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 4)

            case .calendarEvent(let title, let startDate, let colorHex, let meetingURL):
                HStack(spacing: 9) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(OrielColors.color(fromHex: colorHex))
                        .frame(width: 3.5, height: 26)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(relativeStartLabel(startDate))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.white.opacity(0.68))
                    }

                    Spacer()

                    if let meetingURL {
                        Button("Join") {
                            NSWorkspace.shared.open(meetingURL)
                        }
                        .buttonStyle(LiquidPressButtonStyle())
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(OrielColors.accent, in: Capsule())
                    }
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 4)

            case .none:
                EmptyView()
            }
        }
    }

    // MARK: - Expanded Notch Workspace

    private var expandedView: some View {
        let headerHeight: CGFloat = controller.metrics.hasPhysicalNotch ? max(30, controller.metrics.notchHeight) : 28
        let total = renderedWidth
        let horizontalPad = (topR + 6) * 2
        let gap = controller.metrics.hasPhysicalNotch ? (controller.metrics.notchWidth + 10) : 18
        let sideWidth = max(56, (total - horizontalPad - gap) / 2)

        return VStack(spacing: 6) {
            // Ultra-clean 3-column top bar hugging the black MacBook notch
            HStack(spacing: 0) {
                HStack(spacing: 2) {
                    compactTabIcon(activity: .nowPlaying, icon: "music.note", help: "Music")
                    compactTabIcon(activity: .calendar, icon: "calendar", help: "Calendar")
                    compactTabIcon(activity: .duo, icon: "rectangle.split.2x1", help: "Duo View")
                    if settings.enableFileTray {
                        compactTabIcon(
                            activity: .fileTray,
                            icon: "tray.fill",
                            badgeCount: tray.items.count,
                            help: "File Tray"
                        )
                    }
                }
                .padding(2.5)
                .background {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.65)
                        )
                }
                .frame(width: sideWidth, alignment: .leading)

                Spacer()
                    .frame(width: gap)

                HStack(spacing: 5) {
                    Text(expandedTabLabel(controller.expandedActivity))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                        .padding(.trailing, 1)

                    LiquidGlassIconButton(systemName: "gearshape.fill", size: 22, iconSize: 10) {
                        NotificationCenter.default.post(name: .orielSettings, object: nil)
                        controller.setExpanded(false)
                    }
                    .help("Settings")

                    LiquidGlassIconButton(systemName: "chevron.up", size: 22, iconSize: 9.5) {
                        controller.setExpanded(false)
                    }
                    .help("Close Notch")
                }
                .frame(width: sideWidth, alignment: .trailing)
            }
            .frame(height: headerHeight)
            .padding(.top, 1)

            // Body container
            ZStack {
                switch controller.expandedActivity {
                case .nowPlaying:
                    ExpandedMediaPlayerView(revealed: expandedContentVisible)
                        .id("tab-nowPlaying")
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                case .calendar:
                    ExpandedCalendarView(compact: false, revealed: expandedContentVisible)
                        .id("tab-calendar")
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                case .duo:
                    HStack(spacing: 12) {
                        ExpandedMediaPlayerView(compact: true, revealed: expandedContentVisible)
                            .frame(maxWidth: .infinity)

                        Rectangle()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: 0.7)
                            .padding(.vertical, 4)

                        ExpandedCalendarView(compact: true, revealed: expandedContentVisible)
                            .frame(maxWidth: .infinity)
                    }
                    .id("tab-duo")
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                case .fileTray:
                    ExpandedFileTrayView(isDropTargeted: isDropTargeted)
                        .id("tab-fileTray")
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
            .animation(OrielMotion.fluidTab, value: controller.expandedActivity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 2)
        .onAppear {
            if controller.isExpanded {
                expandedContentVisible = true
            }
        }
    }

    @ViewBuilder
    private func compactTabIcon(activity: ExpandedActivity, icon: String, badgeCount: Int = 0, help: String) -> some View {
        let selected = controller.expandedActivity == activity
        Button {
            withAnimation(OrielMotion.fluidTab) {
                controller.expandedActivity = activity
            }
            HapticFeedback.shared.perform(.alignment)
        } label: {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    if selected {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.30), Color.white.opacity(0.15)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.38), lineWidth: 0.7)
                            )
                            .matchedGeometryEffect(id: "ActiveTabGlassPill", in: tabPillNS)
                    }

                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(selected ? .white : .white.opacity(0.55))
                }
                .frame(width: 24, height: 19)

                if badgeCount > 0 {
                    Circle()
                        .fill(OrielColors.teal)
                        .frame(width: 5, height: 5)
                        .offset(x: -1, y: 1)
                }
            }
        }
        .buttonStyle(LiquidPressButtonStyle(pressedScale: 0.90))
        .help(help)
    }

    private func expandedTabLabel(_ activity: ExpandedActivity) -> String {
        switch activity {
        case .nowPlaying: return "Music"
        case .calendar: return "Schedule"
        case .duo: return "Duo"
        case .fileTray: return "Tray"
        }
    }

    // MARK: - Helpers

    private func volumeSymbol(level: Float, isMuted: Bool) -> String {
        if isMuted || level <= 0.001 { return "speaker.slash.fill" }
        if level < 0.33 { return "speaker.wave.1.fill" }
        if level < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private func shortCountdown(to date: Date) -> String {
        let mins = Int(ceil(date.timeIntervalSinceNow / 60.0))
        if mins <= 0 { return "Now" }
        if mins < 60 { return "\(mins)m" }
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: date)
    }

    private func relativeStartLabel(_ date: Date) -> String {
        let mins = Int(ceil(date.timeIntervalSinceNow / 60.0))
        if mins <= 0 { return "Starting now" }
        return "In \(mins)m"
    }

    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        var matched = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            matched = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                var resolvedURL: URL?
                if let data = item as? Data {
                    resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
                } else if let url = item as? URL {
                    resolvedURL = url
                }
                if let url = resolvedURL {
                    Task { @MainActor in
                        FileTrayManager.shared.add(urls: [url])
                        if AppSettings.shared.enableFileTray {
                            NotchController.shared.setExpanded(true, activity: .fileTray)
                        }
                    }
                }
            }
        }
        return matched
    }
}

// MARK: - Media Player View

struct ExpandedMediaPlayerView: View {
    var compact: Bool = false
    var revealed: Bool = true

    @ObservedObject private var media = MediaManager.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var connectivity = ConnectivityManager.shared

    @State private var dragProgress: Double?
    @State private var isArtworkHovered = false
    @State private var prevKickX: CGFloat = 0
    @State private var nextKickX: CGFloat = 0
    @State private var extraPopScale: CGFloat = 1.0

    private var trackAccent: Color {
        media.dominantColors.first ?? settings.accentColor
    }

    private var trackIdentity: String {
        "\(media.track.title)|\(media.track.artist)"
    }

    var body: some View {
        VStack(spacing: 7) {
            // Row 1: Artwork, track metadata, and waveform
            HStack(spacing: 11) {
                Button {
                    media.openSourceApp()
                } label: {
                    Group {
                        if let img = media.artworkImage {
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFill()
                        } else {
                            ZStack {
                                LinearGradient(
                                    colors: [Color.white.opacity(0.16), Color.white.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                Image(systemName: "music.note")
                                    .font(.system(size: compact ? 16 : 19, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                        }
                    }
                    .id(trackIdentity)
                    .transition(.opacity.combined(with: .scale(scale: 0.90)))
                    .frame(width: compact ? 46 : 54, height: compact ? 46 : 54)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.42), trackAccent.opacity(0.28)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.9
                            )
                    )
                    .scaleEffect(
                        isArtworkHovered
                            ? 1.05
                            : (media.track.hasTrack ? (media.track.isPlaying ? 1.0 : 0.91) : 1.0)
                    )
                    .animation(.spring(duration: 0.28, bounce: 0.16), value: media.track.isPlaying)
                    .animation(.spring(duration: 0.20, bounce: 0.14), value: isArtworkHovered)
                    .animation(.spring(duration: 0.28, bounce: 0.10), value: trackIdentity)
                }
                .buttonStyle(LiquidPressButtonStyle(pressedScale: 0.93))
                .onHover { isArtworkHovered = $0 }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        MarqueeText(
                            media.track.hasTrack ? media.track.title : "Nothing Playing",
                            font: .system(size: compact ? 13 : 14, weight: .semibold),
                            color: .white
                        )

                        if media.track.hasTrack {
                            titleBadge
                        }
                    }

                    Text(subtitleLine)
                        .font(.system(size: compact ? 10.5 : 11.5, weight: .regular))
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)

                    if !media.track.hasTrack && (media.spotifyAutomationDenied || media.musicAutomationDenied) {
                        HStack(spacing: 6) {
                            if media.spotifyAutomationDenied {
                                Button("Allow Spotify") {
                                    media.requestAutomationPermission(for: "com.spotify.client")
                                }
                                .buttonStyle(LiquidPressButtonStyle())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(settings.accentColor, in: Capsule())
                            }
                            if media.musicAutomationDenied {
                                Button("Allow Music") {
                                    media.requestAutomationPermission(for: "com.apple.Music")
                                }
                                .buttonStyle(LiquidPressButtonStyle())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(.white.opacity(0.92), in: Capsule())
                            }
                        }
                        .padding(.top, 1)
                    } else if let device = connectivity.activeOutputDevice {
                        HStack(spacing: 4) {
                            Image(systemName: device.symbolName)
                                .font(.system(size: 9, weight: .semibold))
                            Text(device.name)
                                .font(.system(size: 9.5, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(trackAccent.opacity(0.95))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Color.white.opacity(0.08), in: Capsule())
                        .padding(.top, 1)
                    }
                }
                .id(trackIdentity)
                .transition(.opacity)
                .animation(.easeOut(duration: 0.20), value: trackIdentity)

                Spacer(minLength: 2)

                LiveAudioWaveform(
                    isPlaying: media.track.isPlaying,
                    useLiveLevels: settings.useLiveWaveform,
                    tint: trackAccent,
                    barWidth: 2.2,
                    spacing: 1.9,
                    maxHeight: 18
                )
            }
            .liquidReveal(visible: revealed, delay: 0.0)

            // Row 2: Playback scrubber
            TimelineView(.periodic(from: Date(), by: 0.5)) { timeline in
                let duration = max(1, media.track.duration)
                let current = media.track.hasTrack ? media.track.currentPosition(at: timeline.date) : 0
                let effective = dragProgress.map { $0 * duration } ?? current
                let ratio = media.track.duration > 0 ? min(1, max(0, effective / duration)) : 0

                HStack(spacing: 7) {
                    Text(formatTime(effective))
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(.white.opacity(0.62))
                        .frame(width: 30, alignment: .leading)

                    MediaProgressSlider(
                        value: ratio,
                        tint: trackAccent,
                        isEnabled: media.track.duration > 0
                    ) { newRatio in
                        dragProgress = newRatio
                    } onCommit: { finalRatio in
                        dragProgress = nil
                        media.seek(to: finalRatio * duration)
                    }

                    Text(settings.showRemainingTime && media.track.duration > 0
                         ? "-\(formatTime(max(0, duration - effective)))"
                         : formatTime(media.track.duration))
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(.white.opacity(0.62))
                        .frame(width: 34, alignment: .trailing)
                }
            }
            .liquidReveal(visible: revealed, delay: 0.025)

            // Row 3: Transport controls
            HStack(spacing: compact ? 12 : 18) {
                LiquidGlassIconButton(
                    systemName: extraControlSymbol,
                    size: 26,
                    iconSize: 11,
                    tint: extraControlActive ? trackAccent : .white
                ) {
                    media.triggerExtraControl()
                    withAnimation(OrielMotion.elasticTap) { extraPopScale = 1.22 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(OrielMotion.elasticTap) { extraPopScale = 1.0 }
                    }
                }
                .scaleEffect(extraPopScale)

                LiquidGlassIconButton(systemName: "backward.fill", size: 29, iconSize: 13) {
                    media.previousTrack()
                    withAnimation(OrielMotion.elasticTap) { prevKickX = -4 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
                        withAnimation(OrielMotion.elasticTap) { prevKickX = 0 }
                    }
                }
                .offset(x: prevKickX)

                LiquidGlassIconButton(
                    systemName: media.track.isPlaying ? "pause.fill" : "play.fill",
                    size: 34,
                    iconSize: 15.5,
                    tint: .white,
                    prominent: true
                ) {
                    media.togglePlayPause()
                }

                LiquidGlassIconButton(systemName: "forward.fill", size: 29, iconSize: 13) {
                    media.nextTrack()
                    withAnimation(OrielMotion.elasticTap) { nextKickX = 4 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
                        withAnimation(OrielMotion.elasticTap) { nextKickX = 0 }
                    }
                }
                .offset(x: nextKickX)

                LiquidGlassIconButton(systemName: "arrow.up.forward.app", size: 26, iconSize: 11) {
                    media.openSourceApp()
                }
            }
            .liquidReveal(visible: revealed, delay: 0.045)
        }
    }

    private var subtitleLine: String {
        guard media.track.hasTrack else { return "Play music in Spotify, Apple Music, or your browser" }
        if !settings.hideSongTitleExtras && !media.track.album.isEmpty && !compact {
            return "\(media.track.artist) — \(media.track.album)"
        }
        return media.track.artist.isEmpty ? media.track.sourceAppName : media.track.artist
    }

    @ViewBuilder
    private var titleBadge: some View {
        switch settings.songTitleBadge {
        case .none:
            EmptyView()
        case .explicit:
            if media.track.isExplicit {
                Text("E")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 3.5)
                    .padding(.vertical, 0.5)
                    .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 3))
            }
        case .format:
            if media.track.isDolbyAtmos {
                Text("ATMOS")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(OrielColors.sky)
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 1)
                    .background(OrielColors.sky.opacity(0.20), in: Capsule())
            } else if media.track.isLossless {
                Image(systemName: "hifispeaker.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.8))
            } else if media.track.isExplicit {
                Text("E")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 3.5)
                    .padding(.vertical, 0.5)
                    .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 3))
            }
        }
    }

    private var extraControlSymbol: String {
        switch settings.controlChoice {
        case .like: return media.track.isLoved ? "heart.fill" : "heart"
        case .favorite: return media.track.isLoved ? "star.fill" : "star"
        case .shuffle: return "shuffle"
        case .repeating: return media.track.repeatMode == 1 ? "repeat.1" : "repeat"
        case .copyLink: return "link"
        }
    }

    private var extraControlActive: Bool {
        switch settings.controlChoice {
        case .like, .favorite: return media.track.isLoved
        case .shuffle: return media.track.isShuffled
        case .repeating: return media.track.repeatMode > 0
        case .copyLink: return false
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct MediaProgressSlider: View {
    let value: Double
    let tint: Color
    let isEnabled: Bool
    let onDrag: (Double) -> Void
    let onCommit: (Double) -> Void

    @State private var isDragging = false
    @State private var isHovering = false

    var body: some View {
        let active = isDragging || isHovering
        GeometryReader { geo in
            let filledW = max(0, geo.size.width * min(1, max(0, value)))
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.15))
                    .frame(height: active ? 6.5 : 4.5)

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.88), .white.opacity(0.95)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: filledW, height: active ? 6.5 : 4.5)

                if active && isEnabled {
                    Circle()
                        .fill(.white)
                        .frame(width: isDragging ? 12 : 10, height: isDragging ? 12 : 10)
                        .offset(x: max(0, min(geo.size.width - 12, filledW - 5.5)))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .animation(.spring(duration: 0.16, bounce: 0.12), value: active)
            .onHover { isHovering = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard isEnabled, geo.size.width > 0 else { return }
                        isDragging = true
                        let ratio = min(1, max(0, Double(gesture.location.x / geo.size.width)))
                        onDrag(ratio)
                    }
                    .onEnded { gesture in
                        isDragging = false
                        guard isEnabled, geo.size.width > 0 else { return }
                        let ratio = min(1, max(0, Double(gesture.location.x / geo.size.width)))
                        onCommit(ratio)
                    }
            )
        }
        .frame(height: 14)
    }
}

// MARK: - Calendar View

struct ExpandedCalendarView: View {
    var compact: Bool = false
    var revealed: Bool = true

    @ObservedObject private var calendar = CalendarManager.shared
    @ObservedObject private var weather = WeatherManager.shared
    @ObservedObject private var settings = AppSettings.shared

    private var hasCalendarAccess: Bool {
        calendar.authorizationStatus == .fullAccess || calendar.authorizationStatus == .authorized
    }

    var body: some View {
        HStack(spacing: 10) {
            if !compact {
                LiquidGlassCard(cornerRadius: 13, tint: OrielColors.orange, darkModePanel: true) {
                    if settings.alwaysShowMonthView {
                        monthMiniGrid
                            .padding(8)
                    } else {
                        dateHeroTile
                            .padding(10)
                    }
                }
                .frame(width: settings.alwaysShowMonthView ? 156 : 112)
                .liquidReveal(visible: revealed, delay: 0.0)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(compact ? headerDateString : "Today's Schedule")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    if hasCalendarAccess {
                        Button("Open") {
                            calendar.openInCalendar()
                        }
                        .buttonStyle(LiquidPressButtonStyle())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.74))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(Color.white.opacity(0.09), in: Capsule())
                    }
                }

                if !hasCalendarAccess {
                    calendarPermissionCard
                } else if calendar.todayEvents.isEmpty && calendar.tomorrowEvents.isEmpty {
                    emptyDayGlassCard
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(calendar.todayEvents.prefix(compact ? 3 : 4)) { ev in
                                HoverCalendarEventRow(
                                    event: ev,
                                    tint: settings.useCalendarColor ? OrielColors.color(fromHex: ev.colorHex) : OrielColors.orange,
                                    accent: settings.accentColor,
                                    timeRangeText: timeRange(for: ev)
                                ) {
                                    calendar.openInCalendar(event: ev)
                                }
                            }
                            if !calendar.tomorrowEvents.isEmpty && !compact {
                                Text("Tomorrow")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.5))
                                ForEach(calendar.tomorrowEvents.prefix(2)) { ev in
                                    HoverCalendarEventRow(
                                        event: ev,
                                        tint: settings.useCalendarColor ? OrielColors.color(fromHex: ev.colorHex) : OrielColors.orange,
                                        accent: settings.accentColor,
                                        timeRangeText: timeRange(for: ev)
                                    ) {
                                        calendar.openInCalendar(event: ev)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .liquidReveal(visible: revealed, delay: 0.03)
        }
    }

    private var dateHeroTile: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(weekdayString.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(OrielColors.orange)

            Text(dayNumberString)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(monthYearString)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))

            Spacer(minLength: 2)

            if let w = weather.weather {
                HStack(spacing: 4) {
                    Image(systemName: w.symbolName)
                        .font(.system(size: 11))
                        .symbolRenderingMode(.multicolor)
                    Text("\(Int(round(w.temperatureCelsius)))°")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(Color.white.opacity(0.09), in: Capsule())
            } else {
                Text("\(calendar.todayEvents.count) \(calendar.todayEvents.count == 1 ? "event" : "events")")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var calendarPermissionCard: some View {
        LiquidGlassCard(cornerRadius: 12, tint: settings.accentColor, darkModePanel: true) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(settings.accentColor)
                    Text("Connect Calendar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text("See upcoming events, meeting links, and departure alerts.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)
                Button("Enable Access") {
                    calendar.requestAccess()
                }
                .buttonStyle(LiquidPressButtonStyle())
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(settings.accentColor, in: Capsule())
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var emptyDayGlassCard: some View {
        LiquidGlassCard(cornerRadius: 12, tint: .clear, darkModePanel: true) {
            HStack(spacing: 10) {
                if settings.showWeatherOnEmptyDay, let w = weather.weather {
                    Image(systemName: w.symbolName)
                        .font(.system(size: 22))
                        .symbolRenderingMode(.multicolor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(round(w.temperatureCelsius)))°C • \(w.conditionDescription)")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Nothing else scheduled today.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.white.opacity(0.62))
                    }
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 30, height: 30)
                        Image(systemName: "sparkles")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(settings.accentColor)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Clear Day")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("No upcoming events today.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.white.opacity(0.62))
                    }
                }
                Spacer()
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var monthMiniGrid: some View {
        let cal = Calendar.current
        let now = Date()
        let day = cal.component(.day, from: now)
        let range = cal.range(of: .day, in: .month, for: now) ?? 1..<31
        let days = Array(range)

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 2) {
            ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, wd in
                Text(wd)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            ForEach(days, id: \.self) { d in
                Text("\(d)")
                    .font(.system(size: 8.5, weight: d == day ? .bold : .regular))
                    .foregroundStyle(d == day ? .black : .white.opacity(0.84))
                    .frame(width: 15, height: 13)
                    .background(d == day ? OrielColors.orange : Color.clear, in: Circle())
            }
        }
    }

    private var headerDateString: String {
        let df = DateFormatter()
        df.dateFormat = "EEE, d MMM"
        return df.string(from: Date()).capitalized
    }

    private var weekdayString: String {
        let df = DateFormatter()
        df.dateFormat = "EEEE"
        return df.string(from: Date())
    }

    private var dayNumberString: String {
        let df = DateFormatter()
        df.dateFormat = "d"
        return df.string(from: Date())
    }

    private var monthYearString: String {
        let df = DateFormatter()
        df.dateFormat = "MMMM"
        return df.string(from: Date()).capitalized
    }

    private func timeRange(for ev: CalendarEventItem) -> String {
        if ev.isAllDay { return "All day" }
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return "\(df.string(from: ev.startDate)) – \(df.string(from: ev.endDate))"
    }
}

private struct HoverCalendarEventRow: View {
    let event: CalendarEventItem
    let tint: Color
    let accent: Color
    let timeRangeText: String
    let onOpen: () -> Void

    @State private var hovered = false

    var body: some View {
        HStack(spacing: 8) {
            Capsule(style: .continuous)
                .fill(tint)
                .frame(width: 3, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(timeRangeText)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()

            if let url = event.meetingURL {
                Button("Join") {
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(LiquidPressButtonStyle())
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(accent, in: Capsule())
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Color.white.opacity(hovered ? 0.115 : 0.065), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.white.opacity(hovered ? 0.24 : 0.10), lineWidth: 0.6)
        )
        .scaleEffect(hovered ? 1.012 : 1.0)
        .animation(.spring(duration: 0.18, bounce: 0.10), value: hovered)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture(perform: onOpen)
    }
}

// MARK: - Compact Liquid Glass File Tray View

struct ExpandedFileTrayView: View {
    var isDropTargeted: Bool = false
    @ObservedObject private var tray = FileTrayManager.shared

    var body: some View {
        VStack(spacing: 6) {
            if tray.items.isEmpty {
                LiquidGlassCard(cornerRadius: 13, tint: OrielColors.teal, darkModePanel: true) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(OrielColors.teal.opacity(isDropTargeted ? 0.34 : 0.18))
                                .frame(width: 38, height: 38)
                                .scaleEffect(isDropTargeted ? 1.12 : 1.0)
                            Image(systemName: "tray.and.arrow.down.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(OrielColors.teal)
                        }
                        .animation(OrielMotion.elasticTap, value: isDropTargeted)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(isDropTargeted ? "Drop to add to File Tray" : "Drag files onto the Notch")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Keep screenshots, PDFs, or folders handy for AirDrop and Finder.")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.white.opacity(0.62))
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                HStack {
                    Text("\(tray.items.count) \(tray.items.count == 1 ? "item" : "items") in Tray")
                        .font(.system(size: 11, weight: .semibold))
                        .contentTransition(.numericText())
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Button("Clear") {
                        withAnimation(OrielMotion.fluidTab) {
                            tray.clear()
                        }
                    }
                    .buttonStyle(LiquidPressButtonStyle())
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(OrielColors.lowBattery)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2.5)
                    .background(OrielColors.lowBattery.opacity(0.14), in: Capsule())
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tray.items) { item in
                            LiquidGlassCard(cornerRadius: 11, tint: .clear, darkModePanel: true) {
                                VStack(spacing: 4) {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 28, height: 28)
                                    Text(item.name)
                                        .font(.system(size: 9.5, weight: .medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .frame(width: 68)
                                    HStack(spacing: 7) {
                                        Button {
                                            tray.shareViaAirDrop(item)
                                        } label: {
                                            Image(systemName: "airplayaudio")
                                                .font(.system(size: 9.5, weight: .semibold))
                                                .foregroundStyle(OrielColors.teal)
                                        }
                                        .buttonStyle(LiquidPressButtonStyle())
                                        .help("AirDrop")

                                        Button {
                                            NSWorkspace.shared.activateFileViewerSelecting([item.url])
                                        } label: {
                                            Image(systemName: "folder")
                                                .font(.system(size: 9.5, weight: .semibold))
                                                .foregroundStyle(.white.opacity(0.75))
                                        }
                                        .buttonStyle(LiquidPressButtonStyle())
                                        .help("Finder")

                                        Button {
                                            withAnimation(OrielMotion.fluidTab) {
                                                tray.remove(item)
                                            }
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(.white.opacity(0.55))
                                        }
                                        .buttonStyle(LiquidPressButtonStyle())
                                        .help("Remove")
                                    }
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 6)
                            }
                            .transition(.scale(scale: 0.88).combined(with: .opacity))
                        }
                    }
                }
            }
        }
    }
}

public extension Notification.Name {
    static let orielSettings = Notification.Name("com.oriel.openSettings")
    static let orielOnboarding = Notification.Name("com.oriel.openOnboarding")
}
