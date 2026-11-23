import AppKit
import EventKit
import SwiftUI
import OrielCore

public struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var controller = NotchController.shared
    @ObservedObject private var screens = ScreenManager.shared
    @ObservedObject private var calendar = CalendarManager.shared
    @ObservedObject private var focus = FocusManager.shared
    @ObservedObject private var mediaKeys = MediaKeyManager.shared
    @ObservedObject private var media = MediaManager.shared
    @ObservedObject private var audio = AudioManager.shared
    @ObservedObject private var weather = WeatherManager.shared
    @ObservedObject private var connectivity = ConnectivityManager.shared
    @ObservedObject private var tray = FileTrayManager.shared
    @ObservedObject private var volume = VolumeManager.shared
    @ObservedObject private var brightness = BrightnessManager.shared

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: SettingsTab = .general

    private let accentPresets: [(name: String, hex: String)] = [
        ("Teal", "#2DD4BF"),
        ("Sky", "#38BDF8"),
        ("Indigo", "#818CF8"),
        ("Purple", "#A855F7"),
        ("Rose", "#FB7185"),
        ("Amber", "#FBBF24"),
        ("Green", "#4ADE80"),
        ("White", "#FFFFFF")
    ]

    public init() {}

    public var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section("Core & Appearance") {
                    sidebarRow(.general).tag(SettingsTab.general)
                    sidebarRow(.display).tag(SettingsTab.display)
                    sidebarRow(.sound).tag(SettingsTab.sound)
                }

                Section("Live Activities & Widgets") {
                    sidebarRow(.nowPlaying).tag(SettingsTab.nowPlaying)
                    sidebarRow(.calendar).tag(SettingsTab.calendar)
                    sidebarRow(.focus).tag(SettingsTab.focus)
                    sidebarRow(.connectivity).tag(SettingsTab.connectivity)
                    sidebarRow(.battery).tag(SettingsTab.battery)
                    sidebarRow(.fileTray).tag(SettingsTab.fileTray)
                    sidebarRow(.lockScreen).tag(SettingsTab.lockScreen)
                }

                Section {
                    sidebarRow(.about).tag(SettingsTab.about)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(
                VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                    .ignoresSafeArea()
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 236, max: 256)
        } detail: {
            ZStack {
                VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        (selectedTab == .general ? settings.accentColor : selectedTab.iconColor).opacity(colorScheme == .dark ? 0.16 : 0.10),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 460
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        headerBanner

                        if !mediaKeys.isAccessibilityAuthorized {
                            accessibilityHeroCard
                        }

                        liveNotchPreviewCard

                        tabBody
                            .id(selectedTab)
                            .transition(.opacity.combined(with: .offset(y: 6)))
                    }
                    .animation(.spring(response: 0.28, dampingFraction: 0.86), value: selectedTab)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(minWidth: 840, minHeight: 620)
    }

    @ViewBuilder
    private func sidebarRow(_ tab: SettingsTab) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tab == .general ? settings.accentColor.gradient : tab.iconColor.gradient)
                    .frame(width: 22, height: 22)
                Image(systemName: tab.symbolName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(tab.title)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            if (tab == .display || tab == .sound) && !mediaKeys.isAccessibilityAuthorized {
                Circle()
                    .fill(OrielColors.amber)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 2)
    }

    private var headerBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill((selectedTab == .general ? settings.accentColor : selectedTab.iconColor).gradient)
                    .frame(width: 42, height: 42)
                    .shadow(color: (selectedTab == .general ? settings.accentColor : selectedTab.iconColor).opacity(0.35), radius: 8, y: 3)
                Image(systemName: selectedTab.symbolName)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(selectedTab.title)
                    .font(.system(size: 22, weight: .bold))
                Text(subtitle(for: selectedTab))
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                controller.toggleExpanded()
            } label: {
                Label(controller.isExpanded ? "Close Notch" : "Open Notch", systemImage: controller.isExpanded ? "chevron.up.circle.fill" : "macbook")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }

    private var accessibilityHeroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(OrielColors.amber.opacity(0.18))
                        .frame(width: 38, height: 38)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(OrielColors.amber)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Permissions: Accessibility permission is inactive")
                        .font(.system(size: 13.5, weight: .semibold))
                    Text("Oriel is installed at /Applications/Oriel.app with \(mediaKeys.signingSummary) signing. Remove any old Oriel entries with \"−\", add /Applications/Oriel.app in System Settings > Privacy & Security > Accessibility, then click Restart App.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 14) {
                permissionPill(label: "Accessibility", active: mediaKeys.axTrusted, detail: mediaKeys.axTrusted ? "Active" : "Required")
                permissionPill(label: "HUD Keys", active: mediaKeys.isMonitoring, detail: mediaKeys.activeTapMode)
                permissionPill(label: "Signature", active: !mediaKeys.signingSummary.contains("Ad-Hoc"), detail: mediaKeys.signingSummary)
            }

            HStack(spacing: 8) {
                Button("Open Settings") {
                    mediaKeys.promptAccessibilityPermission()
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(OrielColors.amber)
                .foregroundStyle(.black)

                Button("Reveal in Finder") {
                    let appURL = Bundle.main.bundleURL.resolvingSymlinksInPath()
                    NSWorkspace.shared.activateFileViewerSelecting([appURL])
                }
                .buttonStyle(.bordered)

                Button("Restart App") {
                    relaunchCurrentApp()
                }
                .buttonStyle(.bordered)

                Button("Copy Reset Command") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("tccutil reset Accessibility com.oriel.app && tccutil reset AppleEvents com.oriel.app", forType: .string)
                }
                .buttonStyle(.bordered)
                .help("Copy the Terminal command to clear stale TCC records")

                Spacer()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(OrielColors.amber.opacity(colorScheme == .dark ? 0.12 : 0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(OrielColors.amber.opacity(0.35), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func permissionPill(label: String, active: Bool, detail: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(active ? OrielColors.charging : OrielColors.amber)
                .frame(width: 7, height: 7)
            Text("\(label): \(detail)")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.primary.opacity(0.85))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }

    private func relaunchCurrentApp() {
        mediaKeys.relaunchApplication(reopenSettings: true)
    }

    private var liveNotchPreviewCard: some View {
        LiquidGlassCard(cornerRadius: 16, tint: settings.accentColor) {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Label("Live Notch Preview", systemImage: "sparkles")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 6) {
                        Button("Test Volume") {
                            controller.showNotification(.didChangeVolume(level: volume.volume, isMuted: volume.isMuted, deviceName: volume.outputDeviceName, deviceSymbol: volume.outputDeviceSymbol), duration: settings.volumeDuration)
                        }
                        .controlSize(.mini)
                        .buttonStyle(.bordered)

                        Button("Test Brightness") {
                            controller.showNotification(.didChangeBrightness(level: brightness.currentBrightness, isExternal: brightness.isExternalDisplay), duration: settings.brightnessDuration)
                        }
                        .controlSize(.mini)
                        .buttonStyle(.bordered)

                        Button("Test AirPods") {
                            controller.showNotification(.didConnectAirPods(name: "AirPods Pro", symbol: "airpodspro", battery: 92), duration: settings.connectivityDuration)
                        }
                        .controlSize(.mini)
                        .buttonStyle(.bordered)
                    }
                }

                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    settings.accentColor.opacity(0.32),
                                    OrielColors.indigo.opacity(0.24),
                                    Color.black.opacity(0.42)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 68)
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.7)
                        )

                    let previewShape = NotchShape(topCornerRadius: 10, bottomCornerRadius: 15)
                    ZStack {
                        LiquidNotchSurface(
                            shape: previewShape,
                            notchWidth: 148,
                            notchHeight: 28,
                            hasPhysicalNotch: true,
                            isExpanded: false,
                            isCompactOverlay: true,
                            accentTint: selectedTab == .display ? OrielColors.amber : settings.accentColor,
                            showOutline: true
                        )

                        HStack(spacing: 0) {
                            HStack(spacing: 5) {
                                Image(systemName: selectedTab == .display ? "sun.max.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(selectedTab == .display ? OrielColors.amber : .white)
                                Text(selectedTab == .display ? "Brightness" : volume.outputDeviceName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.94))
                                    .lineLimit(1)
                            }
                            .frame(width: 108 + CGFloat(settings.notchWingPadding), alignment: .leading)
                            .clipped()

                            // Simulated black hardware MacBook camera housing
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.black)
                                .frame(width: 146, height: 24)
                                .overlay(
                                    HStack(spacing: 5) {
                                        Circle()
                                            .fill(Color.white.opacity(0.14))
                                            .frame(width: 5, height: 5)
                                        Text("NOTCH")
                                            .font(.system(size: 7.5, weight: .bold))
                                            .tracking(1)
                                            .foregroundStyle(.white.opacity(0.28))
                                    }
                                )

                            HStack(spacing: 5) {
                                HUDProgressBar(
                                    value: selectedTab == .display ? Double(brightness.currentBrightness) : Double(volume.volume),
                                    style: selectedTab == .display ? settings.brightnessProgressStyle : settings.volumeProgressStyle,
                                    tint: selectedTab == .display ? OrielColors.amber : settings.accentColor,
                                    isMuted: false
                                )
                                .frame(width: 64)
                            }
                            .frame(width: 108 + CGFloat(settings.notchWingPadding), alignment: .trailing)
                            .clipped()
                        }
                        .padding(.horizontal, 18)
                    }
                    .frame(width: 416 + CGFloat(settings.notchWingPadding) * 2, height: 36)
                    .shadow(color: .black.opacity(0.45), radius: 12, y: 5)
                }
            }
            .padding(14)
        }
    }

    @ViewBuilder
    private var tabBody: some View {
        switch selectedTab {
        case .general: generalTab
        case .battery: batteryTab
        case .connectivity: connectivityTab
        case .focus: focusTab
        case .display: displayTab
        case .sound: soundTab
        case .nowPlaying: nowPlayingTab
        case .calendar: calendarTab
        case .fileTray: fileTrayTab
        case .lockScreen: lockScreenTab
        case .about: aboutTab
        }
    }

    // MARK: - General

    private var generalTab: some View {
        VStack(spacing: 14) {
            SettingsCard("Quick Presets & Responsiveness", icon: "bolt.fill", tint: settings.accentColor) {
                HStack(spacing: 8) {
                    presetButton("Responsive (Recommended)", icon: "hare.fill") {
                        settings.animationSpeed = .fast
                        settings.volumeSpeed = .fast
                        settings.brightnessSpeed = .fast
                        settings.expandNotchOnHover = true
                        settings.hoverDuration = 0.12
                    }
                    presetButton("Instant", icon: "bolt.fill") {
                        settings.animationSpeed = .instant
                        settings.volumeSpeed = .instant
                        settings.brightnessSpeed = .instant
                        settings.expandNotchOnHover = true
                        settings.hoverDuration = 0.05
                    }
                    presetButton("HUD Only", icon: "rectangle.topthird.inset.filled") {
                        settings.idleActivity = .none
                        settings.forceEnableActivity = false
                        settings.expandNotchOnHover = false
                    }
                    presetButton("Full Glass", icon: "sparkles") {
                        settings.animationSpeed = .smooth
                        settings.nowPlayingStyle = .glass
                        settings.idleActivity = .duo
                        settings.expandNotchOnHover = true
                        settings.hoverDuration = 0.15
                    }
                }
                Divider()
                HStack {
                    SettingLabel("Notch animation speed", caption: "Adjusts how fast the notch opens and settles", icon: "speedometer", tint: settings.accentColor)
                    Spacer()
                    Picker("", selection: $settings.animationSpeed) {
                        ForEach(HUDSpeed.allCases) { speed in
                            Text(speed.title).tag(speed)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }

            SettingsCard("Theme & Accent Color", icon: "paintpalette.fill", tint: settings.accentColor) {
                HStack {
                    SettingLabel("Primary accent color", caption: "Used for progress bars, buttons, and badges", icon: "circle.lefthalf.filled", tint: settings.accentColor)
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(accentPresets, id: \.hex) { preset in
                            let selected = settings.customAccentHex.caseInsensitiveCompare(preset.hex) == .orderedSame
                            Button {
                                settings.customAccentHex = preset.hex
                            } label: {
                                Circle()
                                    .fill(OrielColors.color(fromHex: preset.hex))
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(.white.opacity(selected ? 0.95 : 0.25), lineWidth: selected ? 2.5 : 1)
                                    )
                                    .scaleEffect(selected ? 1.15 : 1.0)
                            }
                            .buttonStyle(.plain)
                            .help(preset.name)
                        }
                    }
                }
                Divider()
                ToggleRow("High-contrast outline", caption: "Subtle light border around the notch perimeter", icon: "square.dashed", tint: .secondary, isOn: $settings.contrastOutline)
                Divider()
                ToggleRow("Trackpad haptics", caption: "Gentle tap when opening or swiping", icon: "hand.tap.fill", tint: .secondary, isOn: $settings.enableHaptics)
            }

            SettingsCard("Hover, Gestures & Size", icon: "cursorarrow.motionlines", tint: OrielColors.sky) {
                ToggleRow("Expand on hover", caption: "Open the notch when moving the pointer over the camera", icon: "cursorarrow.click.badge.clock", tint: OrielColors.sky, isOn: $settings.expandNotchOnHover)
                if settings.expandNotchOnHover {
                    Divider()
                    sliderRow("Hover open delay", value: $settings.hoverDuration, range: 0.02...0.60, step: 0.02, suffix: "s")
                }
                Divider()
                ToggleRow("Natural trackpad direction", icon: "hand.draw.fill", tint: OrielColors.teal, isOn: $settings.naturalMovement)
                Divider()
                ToggleRow("Vertical swipe to open / close", icon: "arrow.up.arrow.down", tint: OrielColors.teal, isOn: $settings.swipeToToggle)
                Divider()
                ToggleRow("Swipe down to switch view", icon: "rectangle.stack", tint: OrielColors.teal, isOn: $settings.swipeToCycleActivity)
                Divider()
                ToggleRow("Horizontal swipe to change track", icon: "forward.end.fill", tint: OrielColors.teal, isOn: $settings.swipeToSkip)
                Divider()
                sliderRow("HUD wing spacing", value: $settings.notchWingPadding, range: -10...40, step: 2, suffix: "pt")
                Divider()
                sliderRow("Notch width", value: $settings.notchAdjustedWidth, range: -30...80, suffix: "pt")
                Divider()
                sliderRow("Notch height", value: $settings.notchAdjustedHeight, range: -6...16, suffix: "pt")
                if settings.notchAdjustedWidth != 0 || settings.notchAdjustedHeight != 0 || settings.notchWingPadding != 0 {
                    Divider()
                    HStack {
                        Spacer()
                        Button("Reset default geometry") {
                            settings.notchAdjustedWidth = 0
                            settings.notchAdjustedHeight = 0
                            settings.notchWingPadding = 0
                        }
                        .controlSize(.small)
                    }
                }
            }

            SettingsCard("Display & System Visibility", icon: "macdisplay.and.arrow.down", tint: OrielColors.indigo) {
                Picker("Show on display", selection: $settings.showOnDisplay) {
                    ForEach(DisplayType.allCases) { d in
                        Text(d.title).tag(d)
                    }
                }
                if settings.showOnDisplay == .specificDisplay {
                    Divider()
                    Picker("Select display", selection: $settings.showOnDisplayUUID) {
                        ForEach(screens.availableScreens, id: \.localizedName) { scr in
                            Text(scr.localizedName).tag(ScreenManager.displayUUID(for: scr))
                        }
                    }
                }
                Divider()
                ToggleRow("Launch at login", icon: "power", tint: OrielColors.green, isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: {
                        settings.launchAtLogin = $0
                        LaunchAtLoginManager.setEnabled($0)
                    }
                ))
                Divider()
                ToggleRow("Simulate notch on external displays", icon: "display", tint: .secondary, isOn: $settings.forceSimulatedNotch)
                Divider()
                ToggleRow("Hide in fullscreen apps", icon: "arrow.up.left.and.arrow.down.right", tint: .secondary, isOn: $settings.hideWhileInFullscreen)
                Divider()
                ToggleRow("Hide while gaming", icon: "gamecontroller.fill", tint: .secondary, isOn: $settings.hideWhileGaming)
                Divider()
                ToggleRow("Hide from screen capture", icon: "record.circle", tint: .secondary, isOn: $settings.hideFromScreenCapture)
                Divider()
                ToggleRow("Hide menu bar icon", icon: "menubar.rectangle", tint: .secondary, isOn: $settings.hideMenuBarIcon)
                Divider()
                Picker("Default expanded tab", selection: $settings.idleActivity) {
                    ForEach(IdleActivityMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            }
        }
    }

    // MARK: - Battery

    private var batteryTab: some View {
        VStack(spacing: 14) {
            SettingsCard("Battery & Power Alerts", icon: "battery.100percent.bolt", tint: OrielColors.green) {
                ToggleRow("Enable battery notifications", icon: "bolt.fill", tint: OrielColors.green, isOn: $settings.enableBattery)
                Divider()
                sliderRow("Notification duration", value: $settings.batteryDuration, range: 1.0...6.0, step: 0.5, suffix: "s")
                Divider()
                ToggleRow("Notify on Low Power Mode", icon: "leaf.fill", tint: OrielColors.amber, isOn: $settings.notifyOnLowPowerMode)
                Divider()
                ToggleRow("Notify on low battery", icon: "battery.25percent", tint: OrielColors.lowBattery, isOn: $settings.warnOnLowBattery)
                if settings.warnOnLowBattery {
                    Divider()
                    sliderRow("Low battery threshold", value: $settings.lowBatteryThreshold, range: 5...40, step: 5, suffix: "%")
                    Divider()
                    ToggleRow("Play alert sound", icon: "speaker.wave.2.fill", tint: OrielColors.amber, isOn: $settings.playSoundOnLowBattery)
                }
            }

            SettingsCard("Appearance & Privacy", icon: "eye.fill", tint: .secondary) {
                ToggleRow("Hide text label", icon: "textformat", tint: .secondary, isOn: $settings.hideBatteryLabel)
                Divider()
                ToggleRow("Hide percentage", icon: "percent", tint: .secondary, isOn: $settings.hideBatteryPercentage)
                Divider()
                ToggleRow("Allow during Focus", icon: "moon.fill", tint: OrielColors.indigo, isOn: $settings.allowBatteryWhenFocused)
                Divider()
                ToggleRow("Allow on Lock Screen", icon: "lock.fill", tint: OrielColors.purple, isOn: $settings.allowBatteryWhenLocked)
                Divider()
                HStack {
                    Button("Preview Charging") {
                        controller.showNotification(.isCharging(level: BatteryManager.shared.batteryLevel), duration: settings.batteryDuration)
                    }
                    Button("Preview Low Battery") {
                        controller.showNotification(.isLowBattery(level: Int(settings.lowBatteryThreshold)), duration: settings.batteryDuration)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Connectivity

    private var connectivityTab: some View {
        VStack(spacing: 14) {
            SettingsCard("AirPods & Bluetooth Audio", icon: "airpodspro", tint: OrielColors.sky) {
                ToggleRow("Enable Bluetooth connection banner", icon: "wave.3.right", tint: OrielColors.sky, isOn: $settings.enableConnectivity)
                Divider()
                sliderRow("Banner duration", value: $settings.connectivityDuration, range: 1.5...7.0, step: 0.5, suffix: "s")
                Divider()
                Picker("Icon style", selection: $settings.connectivityModel) {
                    ForEach(ConnectivityModel.allCases) { m in
                        Text(m.title).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                Divider()
                ToggleRow("Low headphone battery alert", icon: "battery.25percent", tint: OrielColors.lowBattery, isOn: $settings.warnOnLowConnectBattery)
                if settings.warnOnLowConnectBattery {
                    Divider()
                    sliderRow("Low AirPods threshold", value: $settings.lowConnectBatteryThreshold, range: 5...35, step: 5, suffix: "%")
                }
            }

            SettingsCard("Bluetooth Status & Permissions", icon: "antenna.radiowaves.left.and.right", tint: OrielColors.sky) {
                HStack {
                    Text("Bluetooth access")
                    Spacer()
                    if connectivity.bluetoothAuthorized == .allowedAlways {
                        Label("Authorized", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(OrielColors.charging)
                    } else {
                        Button("Authorize Bluetooth") {
                            connectivity.requestBluetoothPermission()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                Divider()
                ToggleRow("Allow during Focus", icon: "moon.fill", tint: OrielColors.indigo, isOn: $settings.allowConnectivityWhenFocused)
                Divider()
                ToggleRow("Allow on Lock Screen", icon: "lock.fill", tint: OrielColors.purple, isOn: $settings.allowConnectivityWhenLocked)
            }
        }
    }

    // MARK: - Focus

    private var focusTab: some View {
        VStack(spacing: 14) {
            SettingsCard("Focus Notifications", icon: "moon.fill", tint: OrielColors.indigo) {
                ToggleRow("Show banner when Focus changes", icon: "moon.stars.fill", tint: OrielColors.indigo, isOn: $settings.enableFocus)
                Divider()
                sliderRow("Notification duration", value: $settings.focusDuration, range: 1.0...6.0, step: 0.5, suffix: "s")
                Divider()
                ToggleRow("Gentle sound when Sleep activates", icon: "bed.double.fill", tint: OrielColors.teal, isOn: $settings.playSoundOnSleepFocus)
                Divider()
                ToggleRow("Hide Focus mode name", icon: "textformat", tint: .secondary, isOn: $settings.hideFocusLabel)
                Divider()
                ToggleRow("Allow on Lock Screen", icon: "lock.fill", tint: OrielColors.purple, isOn: $settings.allowFocusWhenLocked)
            }

            SettingsCard("Waveform Indicator", icon: "waveform", tint: OrielColors.indigo) {
                ToggleRow("Replace waveform with Focus icon", caption: "Show the active Focus icon next to the track", icon: "sparkles", tint: OrielColors.indigo, isOn: $settings.replaceWaveformDuringFocus)
                if settings.replaceWaveformDuringFocus {
                    Divider()
                    Picker("Apply for mode", selection: $settings.replaceWaveformDuringFocusModeIdentifier) {
                        Text("Any active Focus").tag("")
                        ForEach(focus.knownModes) { mode in
                            Text(mode.name).tag(mode.identifier)
                        }
                    }
                }
                Divider()
                HStack {
                    Button("Preview Focus On") {
                        let sample = focus.knownModes.first ?? FocusMode(identifier: "dnd", name: "Do Not Disturb", symbol: "moon.fill", tintColor: OrielColors.indigo)
                        controller.showNotification(.isFocus(mode: sample, active: true), duration: settings.focusDuration)
                    }
                    Button("Preview Focus Off") {
                        let sample = focus.knownModes.first ?? FocusMode(identifier: "dnd", name: "Do Not Disturb", symbol: "moon.fill", tintColor: OrielColors.indigo)
                        controller.showNotification(.isFocus(mode: sample, active: false), duration: settings.focusDuration)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Display (Brightness HUD)

    private var displayTab: some View {
        VStack(spacing: 14) {
            SettingsCard("Brightness HUD (Display)", icon: "sun.max.fill", tint: OrielColors.amber) {
                ToggleRow("Replace macOS brightness HUD", caption: "Intercept F1/F2 keys to hide the built-in overlay", icon: "display", tint: OrielColors.amber, isOn: $settings.enableBrightness)
                Divider()
                sliderRow("HUD duration", value: $settings.brightnessDuration, range: 0.6...4.0, step: 0.2, suffix: "s")
                Divider()
                HStack {
                    Text("Bar style")
                    Spacer()
                    Picker("", selection: $settings.brightnessProgressStyle) {
                        ForEach(HUDProgressStyle.brightnessCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                }
                Divider()
                HStack {
                    Text("HUD responsiveness")
                    Spacer()
                    Picker("", selection: $settings.brightnessSpeed) {
                        ForEach(HUDSpeed.allCases) { speed in
                            Text(speed.title).tag(speed)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
                Divider()
                ToggleRow("Show numeric percentage", icon: "percent", tint: OrielColors.amber, isOn: $settings.showBrightnessPercentage)
                Divider()
                ToggleRow("Hide text label", caption: "Show only the sun icon and bar for a minimal look", icon: "eye.slash", tint: .secondary, isOn: $settings.hideBrightnessLabel)
            }

            SettingsCard("Behavior & Lock Screen", icon: "lock.shield", tint: OrielColors.amber) {
                accessibilityStatusRow
                Divider()
                ToggleRow("Allow during Focus", icon: "moon.fill", tint: OrielColors.indigo, isOn: $settings.allowBrightnessWhenFocused)
                Divider()
                ToggleRow("Allow on Lock Screen", icon: "lock.fill", tint: OrielColors.purple, isOn: $settings.allowBrightnessWhenLocked)
            }
        }
    }

    // MARK: - Sound (Volume HUD)

    private var soundTab: some View {
        VStack(spacing: 14) {
            SettingsCard("Volume HUD (Audio)", icon: "speaker.wave.2.fill", tint: OrielColors.rose) {
                ToggleRow("Replace macOS volume HUD", caption: "Intercept volume and mute keys to hide the built-in overlay", icon: "speaker.wave.3.fill", tint: OrielColors.rose, isOn: $settings.enableVolume)
                Divider()
                sliderRow("HUD duration", value: $settings.volumeDuration, range: 0.6...4.0, step: 0.2, suffix: "s")
                Divider()
                HStack {
                    Text("Bar style")
                    Spacer()
                    Picker("", selection: $settings.volumeProgressStyle) {
                        ForEach(HUDProgressStyle.volumeCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 270)
                }
                Divider()
                HStack {
                    Text("HUD responsiveness")
                    Spacer()
                    Picker("", selection: $settings.volumeSpeed) {
                        ForEach(HUDSpeed.allCases) { speed in
                            Text(speed.title).tag(speed)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
                Divider()
                Picker("Device icon & name", selection: $settings.volumeOutputDevice) {
                    ForEach(VolumeOutputDeviceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Divider()
                ToggleRow("Show numeric percentage", icon: "percent", tint: OrielColors.rose, isOn: $settings.showVolumePercentage)
                Divider()
                ToggleRow("Hide text label", caption: "Leaves more room around the notch cutout", icon: "eye.slash", tint: .secondary, isOn: $settings.hideVolumeLabel)
            }

            SettingsCard("Permissions & Visibility", icon: "lock.shield", tint: OrielColors.rose) {
                accessibilityStatusRow
                Divider()
                ToggleRow("Allow during Focus", icon: "moon.fill", tint: OrielColors.indigo, isOn: $settings.allowVolumeWhenFocused)
                Divider()
                ToggleRow("Allow on Lock Screen", icon: "lock.fill", tint: OrielColors.purple, isOn: $settings.allowVolumeWhenLocked)
            }
        }
    }

    // MARK: - Now Playing

    private var nowPlayingTab: some View {
        VStack(spacing: 14) {
            SettingsCard("Playback Source", icon: "music.note", tint: OrielColors.coral) {
                ToggleRow("Enable Now Playing Live Activity", icon: "play.circle.fill", tint: OrielColors.coral, isOn: $settings.enableNowPlaying)
                Divider()
                ToggleRow("Auto-detect media player", caption: "Supports Spotify, Apple Music, Safari, Chrome, and more", icon: "sparkles", tint: OrielColors.coral, isOn: $settings.automaticMusicApp)
                if !settings.automaticMusicApp {
                    Divider()
                    Picker("Preferred player", selection: $settings.musicApp) {
                        ForEach(NowPlayingMusicApp.allCases) { app in
                            Text(app.title).tag(app)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Divider()
                sliderRow("Hide after pause", value: $settings.idleDuration, range: 3...60, step: 1, suffix: "s")
                Divider()
                ToggleRow("Hide when player is active", icon: "macwindow", tint: .secondary, isOn: $settings.hideWhileSourceIsActive)
            }

            SettingsCard("Appearance & Controls", icon: "waveform", tint: OrielColors.coral) {
                ToggleRow("Live audio spectrum (6 bands)", icon: "waveform.path.ecg", tint: OrielColors.accent, isOn: $settings.useLiveWaveform)
                Divider()
                ToggleRow("Hide waveform when collapsed", icon: "pause.circle", tint: .secondary, isOn: $settings.disableWaveform)
                Divider()
                Picker("Spectrum color", selection: $settings.waveformColorStyle) {
                    ForEach(NowPlayingColorStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                Divider()
                ToggleRow("Disable 3D artwork tilt", icon: "photo", tint: .secondary, isOn: $settings.disableAlbumArtFlip)
                Divider()
                Picker("Title badge", selection: $settings.songTitleBadge) {
                    ForEach(NowPlayingTitleBadge.allCases) { badge in
                        Text(badge.title).tag(badge)
                    }
                }
                .pickerStyle(.segmented)
                Divider()
                Picker("Extra player button", selection: $settings.controlChoice) {
                    ForEach(NowPlayingControlChoice.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
                Divider()
                ToggleRow("Show remaining time", icon: "clock", tint: .secondary, isOn: $settings.showRemainingTime)
            }

            SettingsCard("Quick Peek & Audio Capture", icon: "rectangle.and.text.magnifyingglass", tint: OrielColors.coral) {
                ToggleRow("Enable Quick Peek banner", icon: "bell.badge.fill", tint: OrielColors.coral, isOn: $settings.enableQuickPeek)
                Divider()
                ToggleRow("Show banner on track change", icon: "forward.fill", tint: OrielColors.coral, isOn: $settings.whenSongChanges)
                Divider()
                sliderRow("Quick Peek duration", value: $settings.peekDuration, range: 1.5...8.0, step: 0.5, suffix: "s")
                Divider()
                HStack {
                    Text("System Audio Capture")
                    Spacer()
                    if audio.authorizationStatus == .authorized {
                        Label("Active", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(OrielColors.charging)
                    } else {
                        Button("Enable Live Spectrum") {
                            audio.requestPermission()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            SettingsCard("Player Automation (Spotify & Music)", icon: "lock.shield", tint: OrielColors.teal) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spotify Control")
                            .font(.system(size: 12.5, weight: .medium))
                        Text("Needed to read track, position, and cover art during Spotify playback")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !media.spotifyAutomationDenied {
                        Label("Authorized", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(OrielColors.charging)
                    } else {
                        Button("Authorize Spotify") {
                            media.requestAutomationPermission(for: "com.spotify.client")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Music Control")
                            .font(.system(size: 12.5, weight: .medium))
                        Text("Allows direct Music control when MediaRemote is restricted")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !media.musicAutomationDenied {
                        Label("Authorized", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(OrielColors.charging)
                    } else {
                        Button("Authorize Music") {
                            media.requestAutomationPermission(for: "com.apple.Music")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                Divider()
                HStack {
                    Spacer()
                    Button("Open Privacy > Automation") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .onAppear {
                media.refreshAutomationStatusAsync()
            }
        }
    }

    // MARK: - Calendar

    private var calendarTab: some View {
        VStack(spacing: 14) {
            SettingsCard("Calendar in Notch", icon: "calendar", tint: OrielColors.orange) {
                ToggleRow("Enable Calendar integration", icon: "calendar.badge.clock", tint: OrielColors.orange, isOn: $settings.enableCalendar)
                Divider()
                HStack {
                    Text("Calendar access")
                    Spacer()
                    if calendar.authorizationStatus == .fullAccess || calendar.authorizationStatus == .authorized {
                        Label("Authorized", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(OrielColors.charging)
                    } else {
                        Button("Grant Access") {
                            calendar.requestAccess()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                Divider()
                sliderRow("Event reminder lead time", value: $settings.timeBeforeEvent, range: 60...3600, step: 60, suffix: "s")
                Divider()
                ToggleRow("Always show month grid", icon: "calendar.circle", tint: OrielColors.orange, isOn: $settings.alwaysShowMonthView)
                Divider()
                ToggleRow("Show weather on free days", icon: "cloud.sun.fill", tint: OrielColors.sky, isOn: $settings.showWeatherOnEmptyDay)
                Divider()
                ToggleRow("Hourly chime sound", icon: "bell.fill", tint: OrielColors.amber, isOn: $settings.playHourlyChime)
            }

            SettingsCard("Time to Leave & Quick Peek", icon: "car.fill", tint: OrielColors.sky) {
                ToggleRow("Warn when it's time to leave", icon: "location.fill", tint: OrielColors.sky, isOn: $settings.notifyWhenTimeToLeave)
                if settings.notifyWhenTimeToLeave {
                    Divider()
                    Picker("Default travel mode", selection: $settings.defaultTransportType) {
                        ForEach(TransportType.allCases) { t in
                            Text(t.title).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Divider()
                ToggleRow("Quick Peek upcoming events", icon: "video.fill", tint: OrielColors.accent, isOn: $settings.enableCalendarQuickPeek)
            }

            if !calendar.calendars.isEmpty {
                SettingsCard("Included Calendars", icon: "checklist", tint: OrielColors.orange) {
                    ForEach(calendar.calendars, id: \.calendarIdentifier) { cal in
                        let included = !settings.excludedCalendars.contains(cal.calendarIdentifier)
                        Toggle(isOn: Binding(
                            get: { included },
                            set: { shouldInclude in
                                if shouldInclude {
                                    settings.excludedCalendars.removeAll { $0 == cal.calendarIdentifier }
                                } else if !settings.excludedCalendars.contains(cal.calendarIdentifier) {
                                    settings.excludedCalendars.append(cal.calendarIdentifier)
                                }
                                calendar.reloadCalendarsAndEvents()
                            }
                        )) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(nsColor: cal.color))
                                    .frame(width: 9, height: 9)
                                Text(cal.title)
                            }
                        }
                        if cal.calendarIdentifier != calendar.calendars.last?.calendarIdentifier {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - File Tray

    private var fileTrayTab: some View {
        VStack(spacing: 14) {
            SettingsCard("Notch File Tray", icon: "tray.fill", tint: OrielColors.teal) {
                ToggleRow("Enable drag & drop File Tray", caption: "Drop files, screenshots, or folders onto the notch", icon: "tray.and.arrow.down.fill", tint: OrielColors.teal, isOn: $settings.enableFileTray)
                Divider()
                HStack {
                    Text("Currently stored files: \(tray.items.count)")
                    Spacer()
                    if !tray.items.isEmpty {
                        Button("Clear") { tray.clear() }
                    }
                    Button("Open File Tray") {
                        controller.setExpanded(true, activity: .fileTray)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(OrielColors.teal)
                    .foregroundStyle(.black)
                }
            }
        }
    }

    // MARK: - Lock Screen

    private var lockScreenTab: some View {
        VStack(spacing: 14) {
            SettingsCard("Lock Screen Widgets", icon: "lock.fill", tint: OrielColors.purple) {
                ToggleRow("Enable Lock Screen widgets", icon: "lock.display", tint: OrielColors.purple, isOn: $settings.enableLockScreen)
                Divider()
                Picker("Widget material", selection: $settings.nowPlayingStyle) {
                    ForEach(LockScreenNowPlayingStyle.allCases) { s in
                        Text(s.title).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                Divider()
                ToggleRow("Inline volume slider", icon: "speaker.wave.2", tint: OrielColors.purple, isOn: $settings.showVolumeControlOnLockScreen)
                Divider()
                sliderRow("Vertical widget offset", value: $settings.nowPlayingWidgetOffset, range: -140...120, step: 4, suffix: "pt")
                if settings.nowPlayingWidgetOffset != 0 {
                    HStack {
                        Spacer()
                        Button("Reset position above profile photo") {
                            settings.nowPlayingWidgetOffset = 0
                        }
                        .controlSize(.small)
                    }
                }
                Divider()
                ToggleRow("Also show on Screen Saver", icon: "photo.on.rectangle", tint: .secondary, isOn: $settings.showOnScreenSaver)
                Divider()
                ToggleRow("Keep screen awake while charging", icon: "bolt.shield", tint: OrielColors.green, isOn: $settings.keepAwake)
            }

            SettingsCard("Enabled Widgets", icon: "square.grid.2x2.fill", tint: OrielColors.purple) {
                ToggleRow("Now Playing", icon: "music.note", tint: OrielColors.coral, isOn: $settings.allowNowPlayingWidgetWhenLocked)
                Divider()
                ToggleRow("Weather", icon: "cloud.sun.fill", tint: OrielColors.sky, isOn: $settings.allowWeatherWidgetWhenLocked)
                if settings.allowWeatherWidgetWhenLocked {
                    Divider()
                    Picker("Weather display mode", selection: $settings.weatherStyle) {
                        ForEach(WeatherStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    Divider()
                    HStack {
                        Text("Location access")
                        Spacer()
                        if weather.authorizationStatus == .authorizedAlways || weather.authorizationStatus == .authorized {
                            Label("Active", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(OrielColors.charging)
                        } else {
                            Button("Enable Location") {
                                weather.requestPermission()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                Divider()
                ToggleRow("Calendar", icon: "calendar", tint: OrielColors.orange, isOn: $settings.allowCalendarWidgetWhenLocked)
                Divider()
                ToggleRow("Focus", icon: "moon.fill", tint: OrielColors.indigo, isOn: $settings.allowFocusWidgetWhenLocked)
                Divider()
                ToggleRow("Connectivity", icon: "airpodspro", tint: OrielColors.sky, isOn: $settings.allowConnectivityWidgetWhenLocked)
                Divider()
                ToggleRow("Battery", icon: "battery.75percent", tint: OrielColors.green, isOn: $settings.allowBatteryWidgetWhenLocked)
            }
        }
    }

    // MARK: - About

    private var aboutTab: some View {
        VStack(spacing: 14) {
            SettingsCard("Oriel", icon: "info.circle.fill", tint: OrielColors.slate) {
                HStack(spacing: 14) {
                    NotchShape(topCornerRadius: 10, bottomCornerRadius: 14)
                        .fill(Color.black)
                        .frame(width: 96, height: 24)
                        .overlay(
                            NotchShape(topCornerRadius: 10, bottomCornerRadius: 14)
                                .strokeBorder(settings.accentColor, lineWidth: 1)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Oriel 1.0")
                            .font(.system(size: 15, weight: .bold))
                        Text("Native macOS notch utility with volume and brightness HUDs, Calendar, File Tray, and Lock Screen widgets.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Divider()
                HStack {
                    Button("Open Notch") {
                        controller.setExpanded(true)
                    }
                    Button("Reset Onboarding") {
                        settings.hasCompletedOnboarding = false
                        NotificationCenter.default.post(name: .orielOnboarding, object: nil)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Reusable Setting Rows

    private var accessibilityStatusRow: some View {
        HStack {
            SettingLabel("Key Interception (Accessibility)", caption: "Required to suppress built-in macOS volume and brightness overlays", icon: "keyboard.badge.ellipsis", tint: OrielColors.amber)
            Spacer()
            if mediaKeys.isAccessibilityAuthorized {
                Label("Active (\(mediaKeys.activeTapMode))", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(OrielColors.charging)
            } else {
                HStack(spacing: 6) {
                    Button("Restart App") {
                        relaunchCurrentApp()
                    }
                    .buttonStyle(.bordered)
                    Button("Grant Accessibility") {
                        mediaKeys.promptAccessibilityPermission()
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(OrielColors.amber)
                    .foregroundStyle(.black)
                }
            }
        }
    }

    @ViewBuilder
    private func presetButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(settings.accentColor)
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.7)
            )
        }
        .buttonStyle(LiquidPressButtonStyle(pressedScale: 0.94))
    }

    private func sliderRow(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1.0,
        suffix: String
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Slider(value: value, in: range, step: step)
                .frame(width: 170)
            Text(step < 1 ? String(format: "%.2f%@", value.wrappedValue, suffix) : "\(Int(round(value.wrappedValue)))\(suffix)")
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .trailing)
        }
    }

    private func subtitle(for tab: SettingsTab) -> String {
        switch tab {
        case .general: return "Quick presets, accent colors, animation speed, hover zone, and size."
        case .battery: return "Charging, Low Power Mode, and low battery alerts."
        case .connectivity: return "AirPods and Bluetooth audio connection banners."
        case .focus: return "Focus banners and waveform indicator options."
        case .display: return "Compact brightness overlay replacing the default macOS HUD."
        case .sound: return "Compact volume overlay replacing the default macOS HUD."
        case .nowPlaying: return "Spotify, Apple Music, 6-band spectrum, and Quick Peek."
        case .calendar: return "Upcoming events, meeting links, weather, and Time to Leave."
        case .fileTray: return "Drag-and-drop shelf directly inside the notch."
        case .lockScreen: return "Glass, Frosted, and Clear widgets on the Lock Screen."
        case .about: return "Version, quick actions, and setup assistant."
        }
    }
}

struct SettingLabel: View {
    let title: String
    let caption: String?
    let icon: String
    let tint: Color

    init(_ title: String, caption: String? = nil, icon: String, tint: Color) {
        self.title = title
        self.caption = caption
        self.icon = icon
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 26, height: 26)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                if let caption {
                    Text(caption)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ToggleRow: View {
    let title: String
    let caption: String?
    let icon: String
    let tint: Color
    @Binding var isOn: Bool

    init(_ title: String, caption: String? = nil, icon: String, tint: Color, isOn: Binding<Bool>) {
        self.title = title
        self.caption = caption
        self.icon = icon
        self.tint = tint
        self._isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            SettingLabel(title, caption: caption, icon: icon, tint: tint)
        }
        .toggleStyle(.switch)
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    init(_ title: String, icon: String = "slider.horizontal.3", tint: Color = .secondary, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            LiquidGlassCard(cornerRadius: 16, tint: .clear) {
                VStack(alignment: .leading, spacing: 10) {
                    content()
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
