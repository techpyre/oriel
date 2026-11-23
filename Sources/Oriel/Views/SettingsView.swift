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
                Section("Core & Aspetto") {
                    sidebarRow(.general).tag(SettingsTab.general)
                    sidebarRow(.display).tag(SettingsTab.display)
                    sidebarRow(.sound).tag(SettingsTab.sound)
                }

                Section("Live Activities & Widget") {
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
                Label(controller.isExpanded ? "Chiudi Notch" : "Apri Notch", systemImage: controller.isExpanded ? "chevron.up.circle.fill" : "macbook")
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
                    Text("Centro Permessi: Accessibilità (Controllo Dispositivi) non attiva")
                        .font(.system(size: 13.5, weight: .semibold))
                    Text("Oriel è installata in /Applications/Oriel.app con firma stabile (\(mediaKeys.signingSummary)). Rimuovi eventuali vecchie voci di Oriel con \"−\", trascina o aggiungi /Applications/Oriel.app in Impostazioni > Controllo dispositivi e accesso dati, poi premi Riavvia App.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 14) {
                permissionPill(label: "Accessibilità", active: mediaKeys.axTrusted, detail: mediaKeys.axTrusted ? "Attiva" : "Richiesta")
                permissionPill(label: "Tasti HUD", active: mediaKeys.isMonitoring, detail: mediaKeys.activeTapMode)
                permissionPill(label: "Firma", active: !mediaKeys.signingSummary.contains("Ad-Hoc"), detail: mediaKeys.signingSummary)
            }

            HStack(spacing: 8) {
                Button("Apri Impostazioni") {
                    mediaKeys.promptAccessibilityPermission()
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(OrielColors.amber)
                .foregroundStyle(.black)

                Button("Mostra App nel Finder") {
                    let appURL = Bundle.main.bundleURL.resolvingSymlinksInPath()
                    NSWorkspace.shared.activateFileViewerSelecting([appURL])
                }
                .buttonStyle(.bordered)

                Button("Riavvia App") {
                    relaunchCurrentApp()
                }
                .buttonStyle(.bordered)

                Button("Copia Reset") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("tccutil reset Accessibility com.oriel.app && tccutil reset AppleEvents com.oriel.app", forType: .string)
                }
                .buttonStyle(.bordered)
                .help("Copia il comando Terminale per rimuovere vecchi record TCC bloccati")

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
                    Label("Anteprima Live Liquid Notch", systemImage: "sparkles")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 6) {
                        Button("Test Volume") {
                            controller.showNotification(.didChangeVolume(level: volume.volume, isMuted: volume.isMuted, deviceName: volume.outputDeviceName, deviceSymbol: volume.outputDeviceSymbol), duration: settings.volumeDuration)
                        }
                        .controlSize(.mini)
                        .buttonStyle(.bordered)

                        Button("Test Luminosità") {
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
            SettingsCard("Profili Rapidi & Reattività", icon: "bolt.fill", tint: settings.accentColor) {
                HStack(spacing: 8) {
                    presetButton("Reattivo (Consigliato)", icon: "hare.fill") {
                        settings.animationSpeed = .fast
                        settings.volumeSpeed = .fast
                        settings.brightnessSpeed = .fast
                        settings.expandNotchOnHover = true
                        settings.hoverDuration = 0.12
                    }
                    presetButton("Istantaneo", icon: "bolt.fill") {
                        settings.animationSpeed = .instant
                        settings.volumeSpeed = .instant
                        settings.brightnessSpeed = .instant
                        settings.expandNotchOnHover = true
                        settings.hoverDuration = 0.05
                    }
                    presetButton("Solo HUD", icon: "rectangle.topthird.inset.filled") {
                        settings.idleActivity = .none
                        settings.forceEnableActivity = false
                        settings.expandNotchOnHover = false
                    }
                    presetButton("Glass Completo", icon: "sparkles") {
                        settings.animationSpeed = .smooth
                        settings.nowPlayingStyle = .glass
                        settings.idleActivity = .duo
                        settings.expandNotchOnHover = true
                        settings.hoverDuration = 0.15
                    }
                }
                Divider()
                HStack {
                    SettingLabel("Velocità animazioni Notch", caption: "Controlla la rapidità di apertura e risposta del sistema", icon: "speedometer", tint: settings.accentColor)
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

            SettingsCard("Tema & Colore Accento", icon: "paintpalette.fill", tint: settings.accentColor) {
                HStack {
                    SettingLabel("Colore accento principale", caption: "Applicato a barre progresso, pulsanti e badge", icon: "circle.lefthalf.filled", tint: settings.accentColor)
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
                ToggleRow("Contorno a contrasto", caption: "Bordo sottile luminoso attorno alla silhouette nera", icon: "square.dashed", tint: .secondary, isOn: $settings.contrastOutline)
                Divider()
                ToggleRow("Feedback aptico (Trackpad)", caption: "Leggera vibrazione tattile all'apertura e nei gesti", icon: "hand.tap.fill", tint: .secondary, isOn: $settings.enableHaptics)
            }

            SettingsCard("Hover, Gesture & Dimensioni", icon: "cursorarrow.motionlines", tint: OrielColors.sky) {
                ToggleRow("Espandi al passaggio del mouse (Hover)", caption: "Apri il Notch passando il cursore sopra la fotocamera", icon: "cursorarrow.click.badge.clock", tint: OrielColors.sky, isOn: $settings.expandNotchOnHover)
                if settings.expandNotchOnHover {
                    Divider()
                    sliderRow("Ritardo apertura hover", value: $settings.hoverDuration, range: 0.02...0.60, step: 0.02, suffix: "s")
                }
                Divider()
                ToggleRow("Movimento naturale trackpad", icon: "hand.draw.fill", tint: OrielColors.teal, isOn: $settings.naturalMovement)
                Divider()
                ToggleRow("Swipe verticale per aprire / chiudere", icon: "arrow.up.arrow.down", tint: OrielColors.teal, isOn: $settings.swipeToToggle)
                Divider()
                ToggleRow("Swipe verso il basso per cambiare vista", icon: "rectangle.stack", tint: OrielColors.teal, isOn: $settings.swipeToCycleActivity)
                Divider()
                ToggleRow("Swipe orizzontale per cambiare traccia", icon: "forward.end.fill", tint: OrielColors.teal, isOn: $settings.swipeToSkip)
                Divider()
                sliderRow("Margine extra ali HUD", value: $settings.notchWingPadding, range: -10...40, step: 2, suffix: "pt")
                Divider()
                sliderRow("Larghezza Notch", value: $settings.notchAdjustedWidth, range: -30...80, suffix: "pt")
                Divider()
                sliderRow("Altezza Notch", value: $settings.notchAdjustedHeight, range: -6...16, suffix: "pt")
                if settings.notchAdjustedWidth != 0 || settings.notchAdjustedHeight != 0 || settings.notchWingPadding != 0 {
                    Divider()
                    HStack {
                        Spacer()
                        Button("Ripristina geometria predefinita") {
                            settings.notchAdjustedWidth = 0
                            settings.notchAdjustedHeight = 0
                            settings.notchWingPadding = 0
                        }
                        .controlSize(.small)
                    }
                }
            }

            SettingsCard("Schermo & Visibilità Sistema", icon: "macdisplay.and.arrow.down", tint: OrielColors.indigo) {
                Picker("Mostra su schermo", selection: $settings.showOnDisplay) {
                    ForEach(DisplayType.allCases) { d in
                        Text(d.title).tag(d)
                    }
                }
                if settings.showOnDisplay == .specificDisplay {
                    Divider()
                    Picker("Seleziona monitor", selection: $settings.showOnDisplayUUID) {
                        ForEach(screens.availableScreens, id: \.localizedName) { scr in
                            Text(scr.localizedName).tag(ScreenManager.displayUUID(for: scr))
                        }
                    }
                }
                Divider()
                ToggleRow("Avvia al login", icon: "power", tint: OrielColors.green, isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: {
                        settings.launchAtLogin = $0
                        LaunchAtLoginManager.setEnabled($0)
                    }
                ))
                Divider()
                ToggleRow("Simula Notch su monitor esterni", icon: "display", tint: .secondary, isOn: $settings.forceSimulatedNotch)
                Divider()
                ToggleRow("Nascondi in modalità a tutto schermo", icon: "arrow.up.left.and.arrow.down.right", tint: .secondary, isOn: $settings.hideWhileInFullscreen)
                Divider()
                ToggleRow("Nascondi durante il gaming", icon: "gamecontroller.fill", tint: .secondary, isOn: $settings.hideWhileGaming)
                Divider()
                ToggleRow("Nascondi da registrazione schermo", icon: "record.circle", tint: .secondary, isOn: $settings.hideFromScreenCapture)
                Divider()
                ToggleRow("Nascondi icona barra dei menu", icon: "menubar.rectangle", tint: .secondary, isOn: $settings.hideMenuBarIcon)
                Divider()
                Picker("Vista espansa predefinita", selection: $settings.idleActivity) {
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
            SettingsCard("Avvisi Batteria & Alimentazione", icon: "battery.100percent.bolt", tint: OrielColors.green) {
                ToggleRow("Abilita notifiche batteria", icon: "bolt.fill", tint: OrielColors.green, isOn: $settings.enableBattery)
                Divider()
                sliderRow("Durata notifica", value: $settings.batteryDuration, range: 1.0...6.0, step: 0.5, suffix: "s")
                Divider()
                ToggleRow("Notifica modalità Risparmio Energia", icon: "leaf.fill", tint: OrielColors.amber, isOn: $settings.notifyOnLowPowerMode)
                Divider()
                ToggleRow("Avvisa quando batteria scarica", icon: "battery.25percent", tint: OrielColors.lowBattery, isOn: $settings.warnOnLowBattery)
                if settings.warnOnLowBattery {
                    Divider()
                    sliderRow("Soglia batteria scarica", value: $settings.lowBatteryThreshold, range: 5...40, step: 5, suffix: "%")
                    Divider()
                    ToggleRow("Riproduci suono di avviso", icon: "speaker.wave.2.fill", tint: OrielColors.amber, isOn: $settings.playSoundOnLowBattery)
                }
            }

            SettingsCard("Aspetto & Privacy", icon: "eye.fill", tint: .secondary) {
                ToggleRow("Nascondi etichetta testo", icon: "textformat", tint: .secondary, isOn: $settings.hideBatteryLabel)
                Divider()
                ToggleRow("Nascondi percentuale", icon: "percent", tint: .secondary, isOn: $settings.hideBatteryPercentage)
                Divider()
                ToggleRow("Consenti durante Full Immersion", icon: "moon.fill", tint: OrielColors.indigo, isOn: $settings.allowBatteryWhenFocused)
                Divider()
                ToggleRow("Consenti su schermo bloccato", icon: "lock.fill", tint: OrielColors.purple, isOn: $settings.allowBatteryWhenLocked)
                Divider()
                HStack {
                    Button("Anteprima Ricarica") {
                        controller.showNotification(.isCharging(level: BatteryManager.shared.batteryLevel), duration: settings.batteryDuration)
                    }
                    Button("Anteprima Batteria Scarica") {
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
            SettingsCard("AirPods & Cuffie Bluetooth", icon: "airpodspro", tint: OrielColors.sky) {
                ToggleRow("Abilita banner connessione Bluetooth", icon: "wave.3.right", tint: OrielColors.sky, isOn: $settings.enableConnectivity)
                Divider()
                sliderRow("Durata banner", value: $settings.connectivityDuration, range: 1.5...7.0, step: 0.5, suffix: "s")
                Divider()
                Picker("Stile icona", selection: $settings.connectivityModel) {
                    ForEach(ConnectivityModel.allCases) { m in
                        Text(m.title).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                Divider()
                ToggleRow("Avvisa batteria cuffie scarica", icon: "battery.25percent", tint: OrielColors.lowBattery, isOn: $settings.warnOnLowConnectBattery)
                if settings.warnOnLowConnectBattery {
                    Divider()
                    sliderRow("Soglia minima AirPods", value: $settings.lowConnectBatteryThreshold, range: 5...35, step: 5, suffix: "%")
                }
            }

            SettingsCard("Stato & Permessi Bluetooth", icon: "antenna.radiowaves.left.and.right", tint: OrielColors.sky) {
                HStack {
                    Text("Accesso Bluetooth")
                    Spacer()
                    if connectivity.bluetoothAuthorized == .allowedAlways {
                        Label("Autorizzato", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(OrielColors.charging)
                    } else {
                        Button("Autorizza Bluetooth") {
                            connectivity.requestBluetoothPermission()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                Divider()
                ToggleRow("Consenti durante Full Immersion", icon: "moon.fill", tint: OrielColors.indigo, isOn: $settings.allowConnectivityWhenFocused)
                Divider()
                ToggleRow("Consenti su schermo bloccato", icon: "lock.fill", tint: OrielColors.purple, isOn: $settings.allowConnectivityWhenLocked)
            }
        }
    }

    // MARK: - Focus

    private var focusTab: some View {
        VStack(spacing: 14) {
            SettingsCard("Notifiche Full Immersion", icon: "moon.fill", tint: OrielColors.indigo) {
                ToggleRow("Mostra banner cambio Full Immersion", icon: "moon.stars.fill", tint: OrielColors.indigo, isOn: $settings.enableFocus)
                Divider()
                sliderRow("Durata notifica", value: $settings.focusDuration, range: 1.0...6.0, step: 0.5, suffix: "s")
                Divider()
                ToggleRow("Suono dolce attivando Sonno", icon: "bed.double.fill", tint: OrielColors.teal, isOn: $settings.playSoundOnSleepFocus)
                Divider()
                ToggleRow("Nascondi etichetta nome Focus", icon: "textformat", tint: .secondary, isOn: $settings.hideFocusLabel)
                Divider()
                ToggleRow("Consenti su schermo bloccato", icon: "lock.fill", tint: OrielColors.purple, isOn: $settings.allowFocusWhenLocked)
            }

            SettingsCard("Indicatore Spettro", icon: "waveform", tint: OrielColors.indigo) {
                ToggleRow("Sostituisci waveform con icona Focus", caption: "Mostra l'icona del Focus attivo accanto al brano", icon: "sparkles", tint: OrielColors.indigo, isOn: $settings.replaceWaveformDuringFocus)
                if settings.replaceWaveformDuringFocus {
                    Divider()
                    Picker("Applica per modalità", selection: $settings.replaceWaveformDuringFocusModeIdentifier) {
                        Text("Qualsiasi Focus attivo").tag("")
                        ForEach(focus.knownModes) { mode in
                            Text(mode.name).tag(mode.identifier)
                        }
                    }
                }
                Divider()
                HStack {
                    Button("Anteprima Focus On") {
                        let sample = focus.knownModes.first ?? FocusMode(identifier: "dnd", name: "Do Not Disturb", symbol: "moon.fill", tintColor: OrielColors.indigo)
                        controller.showNotification(.isFocus(mode: sample, active: true), duration: settings.focusDuration)
                    }
                    Button("Anteprima Focus Off") {
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
            SettingsCard("HUD Luminosità (Display)", icon: "sun.max.fill", tint: OrielColors.amber) {
                ToggleRow("Sostituisci HUD Luminosità macOS", caption: "Intercetta tasti F1/F2 nascondendo il riquadro standard", icon: "display", tint: OrielColors.amber, isOn: $settings.enableBrightness)
                Divider()
                sliderRow("Durata HUD", value: $settings.brightnessDuration, range: 0.6...4.0, step: 0.2, suffix: "s")
                Divider()
                HStack {
                    Text("Stile barra")
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
                    Text("Reattività HUD")
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
                ToggleRow("Mostra percentuale numerica", icon: "percent", tint: OrielColors.amber, isOn: $settings.showBrightnessPercentage)
                Divider()
                ToggleRow("Nascondi etichetta testo", caption: "Mostra solo icona sole e barra per un look minimale", icon: "eye.slash", tint: .secondary, isOn: $settings.hideBrightnessLabel)
            }

            SettingsCard("Permessi & Comportamento", icon: "lock.shield", tint: OrielColors.amber) {
                accessibilityStatusRow
                Divider()
                ToggleRow("Consenti durante Full Immersion", icon: "moon.fill", tint: OrielColors.indigo, isOn: $settings.allowBrightnessWhenFocused)
                Divider()
                ToggleRow("Consenti su schermo bloccato", icon: "lock.fill", tint: OrielColors.purple, isOn: $settings.allowBrightnessWhenLocked)
            }
        }
    }

    // MARK: - Sound (Volume HUD)

    private var soundTab: some View {
        VStack(spacing: 14) {
            SettingsCard("HUD Volume (Audio)", icon: "speaker.wave.2.fill", tint: OrielColors.rose) {
                ToggleRow("Sostituisci HUD Volume macOS", caption: "Intercetta i tasti volume/muto sostituendo l'HUD di sistema", icon: "speaker.wave.3.fill", tint: OrielColors.rose, isOn: $settings.enableVolume)
                Divider()
                sliderRow("Durata HUD", value: $settings.volumeDuration, range: 0.6...4.0, step: 0.2, suffix: "s")
                Divider()
                HStack {
                    Text("Stile barra")
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
                    Text("Reattività HUD")
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
                Picker("Icona & Nome dispositivo", selection: $settings.volumeOutputDevice) {
                    ForEach(VolumeOutputDeviceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Divider()
                ToggleRow("Mostra percentuale numerica", icon: "percent", tint: OrielColors.rose, isOn: $settings.showVolumePercentage)
                Divider()
                ToggleRow("Nascondi etichetta testo", caption: "Utile per lasciare ancora più spazio attorno al Notch", icon: "eye.slash", tint: .secondary, isOn: $settings.hideVolumeLabel)
            }

            SettingsCard("Permessi & Visibilità", icon: "lock.shield", tint: OrielColors.rose) {
                accessibilityStatusRow
                Divider()
                ToggleRow("Consenti durante Full Immersion", icon: "moon.fill", tint: OrielColors.indigo, isOn: $settings.allowVolumeWhenFocused)
                Divider()
                ToggleRow("Consenti su schermo bloccato", icon: "lock.fill", tint: OrielColors.purple, isOn: $settings.allowVolumeWhenLocked)
            }
        }
    }

    // MARK: - Now Playing

    private var nowPlayingTab: some View {
        VStack(spacing: 14) {
            SettingsCard("Sorgente Riproduzione", icon: "music.note", tint: OrielColors.coral) {
                ToggleRow("Abilita Live Activity Now Playing", icon: "play.circle.fill", tint: OrielColors.coral, isOn: $settings.enableNowPlaying)
                Divider()
                ToggleRow("Rileva automaticamente l'app multimediale", caption: "Supporta Spotify, Apple Music, Safari, Chrome e altri", icon: "sparkles", tint: OrielColors.coral, isOn: $settings.automaticMusicApp)
                if !settings.automaticMusicApp {
                    Divider()
                    Picker("App preferita", selection: $settings.musicApp) {
                        ForEach(NowPlayingMusicApp.allCases) { app in
                            Text(app.title).tag(app)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Divider()
                sliderRow("Nascondi dopo pausa", value: $settings.idleDuration, range: 3...60, step: 1, suffix: "s")
                Divider()
                ToggleRow("Nascondi quando il player è in primo piano", icon: "macwindow", tint: .secondary, isOn: $settings.hideWhileSourceIsActive)
            }

            SettingsCard("Stile Grafico & Controlli", icon: "waveform", tint: OrielColors.coral) {
                ToggleRow("Spettro audio in tempo reale (6 bande)", icon: "waveform.path.ecg", tint: OrielColors.accent, isOn: $settings.useLiveWaveform)
                Divider()
                ToggleRow("Disabilita waveform da chiuso", icon: "pause.circle", tint: .secondary, isOn: $settings.disableWaveform)
                Divider()
                Picker("Colore spettro", selection: $settings.waveformColorStyle) {
                    ForEach(NowPlayingColorStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                Divider()
                ToggleRow("Disabilita animazione 3D copertina", icon: "photo", tint: .secondary, isOn: $settings.disableAlbumArtFlip)
                Divider()
                Picker("Badge titolo", selection: $settings.songTitleBadge) {
                    ForEach(NowPlayingTitleBadge.allCases) { badge in
                        Text(badge.title).tag(badge)
                    }
                }
                .pickerStyle(.segmented)
                Divider()
                Picker("Pulsante extra player", selection: $settings.controlChoice) {
                    ForEach(NowPlayingControlChoice.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
                Divider()
                ToggleRow("Mostra tempo rimanente", icon: "clock", tint: .secondary, isOn: $settings.showRemainingTime)
            }

            SettingsCard("Quick Peek & Audio Capture", icon: "rectangle.and.text.magnifyingglass", tint: OrielColors.coral) {
                ToggleRow("Abilita banner Quick Peek", icon: "bell.badge.fill", tint: OrielColors.coral, isOn: $settings.enableQuickPeek)
                Divider()
                ToggleRow("Mostra banner al cambio traccia", icon: "forward.fill", tint: OrielColors.coral, isOn: $settings.whenSongChanges)
                Divider()
                sliderRow("Durata Quick Peek", value: $settings.peekDuration, range: 1.5...8.0, step: 0.5, suffix: "s")
                Divider()
                HStack {
                    Text("Cattura Audio Sistema")
                    Spacer()
                    if audio.authorizationStatus == .authorized {
                        Label("Attiva", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(OrielColors.charging)
                    } else {
                        Button("Abilita Spettro Reale") {
                            audio.requestPermission()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            SettingsCard("Automazione Player (Spotify & Music)", icon: "lock.shield", tint: OrielColors.teal) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Controllo Spotify")
                            .font(.system(size: 12.5, weight: .medium))
                        Text("Necessario su macOS 27 per leggere traccia, tempo e copertina a riproduzione avviata")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !media.spotifyAutomationDenied {
                        Label("Autorizzato", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(OrielColors.charging)
                    } else {
                        Button("Autorizza Spotify") {
                            media.requestAutomationPermission(for: "com.spotify.client")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Controllo Apple Music")
                            .font(.system(size: 12.5, weight: .medium))
                        Text("Consente il controllo diretto di Music quando MediaRemote è bloccato")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !media.musicAutomationDenied {
                        Label("Autorizzato", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(OrielColors.charging)
                    } else {
                        Button("Autorizza Music") {
                            media.requestAutomationPermission(for: "com.apple.Music")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                Divider()
                HStack {
                    Spacer()
                    Button("Apri Privacy > Automazione") {
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
            SettingsCard("Calendario nel Notch", icon: "calendar", tint: OrielColors.orange) {
                ToggleRow("Abilita integrazione Calendario", icon: "calendar.badge.clock", tint: OrielColors.orange, isOn: $settings.enableCalendar)
                Divider()
                HStack {
                    Text("Permesso Calendario")
                    Spacer()
                    if calendar.authorizationStatus == .fullAccess || calendar.authorizationStatus == .authorized {
                        Label("Autorizzato", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(OrielColors.charging)
                    } else {
                        Button("Concedi Accesso") {
                            calendar.requestAccess()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                Divider()
                sliderRow("Anticipo notifica evento", value: $settings.timeBeforeEvent, range: 60...3600, step: 60, suffix: "s")
                Divider()
                ToggleRow("Griglia mese sempre visibile", icon: "calendar.circle", tint: OrielColors.orange, isOn: $settings.alwaysShowMonthView)
                Divider()
                ToggleRow("Mostra meteo nei giorni liberi", icon: "cloud.sun.fill", tint: OrielColors.sky, isOn: $settings.showWeatherOnEmptyDay)
                Divider()
                ToggleRow("Suono rintocco orario", icon: "bell.fill", tint: OrielColors.amber, isOn: $settings.playHourlyChime)
            }

            SettingsCard("Time to Leave & Quick Peek", icon: "car.fill", tint: OrielColors.sky) {
                ToggleRow("Avvisa quando è ora di partire", icon: "location.fill", tint: OrielColors.sky, isOn: $settings.notifyWhenTimeToLeave)
                if settings.notifyWhenTimeToLeave {
                    Divider()
                    Picker("Mezzo predefinito", selection: $settings.defaultTransportType) {
                        ForEach(TransportType.allCases) { t in
                            Text(t.title).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Divider()
                ToggleRow("Quick Peek prossimi eventi", icon: "video.fill", tint: OrielColors.accent, isOn: $settings.enableCalendarQuickPeek)
            }

            if !calendar.calendars.isEmpty {
                SettingsCard("Calendari Inclusi", icon: "checklist", tint: OrielColors.orange) {
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
                ToggleRow("Abilita vassoio file drag & drop", caption: "Trascina file, screenshot o cartelle direttamente sopra il Notch", icon: "tray.and.arrow.down.fill", tint: OrielColors.teal, isOn: $settings.enableFileTray)
                Divider()
                HStack {
                    Text("File attualmente salvati: \(tray.items.count)")
                    Spacer()
                    if !tray.items.isEmpty {
                        Button("Svuota") { tray.clear() }
                    }
                    Button("Apri File Tray") {
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
            SettingsCard("Widget Schermata di Blocco", icon: "lock.fill", tint: OrielColors.purple) {
                ToggleRow("Abilita widget su Lock Screen", icon: "lock.display", tint: OrielColors.purple, isOn: $settings.enableLockScreen)
                Divider()
                Picker("Materiale widget", selection: $settings.nowPlayingStyle) {
                    ForEach(LockScreenNowPlayingStyle.allCases) { s in
                        Text(s.title).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                Divider()
                ToggleRow("Slider volume integrato", icon: "speaker.wave.2", tint: OrielColors.purple, isOn: $settings.showVolumeControlOnLockScreen)
                Divider()
                sliderRow("Offset verticale widget", value: $settings.nowPlayingWidgetOffset, range: -140...120, step: 4, suffix: "pt")
                if settings.nowPlayingWidgetOffset != 0 {
                    HStack {
                        Spacer()
                        Button("Ripristina posizione sopra foto profilo") {
                            settings.nowPlayingWidgetOffset = 0
                        }
                        .controlSize(.small)
                    }
                }
                Divider()
                ToggleRow("Mostra anche su Salvaschermo", icon: "photo.on.rectangle", tint: .secondary, isOn: $settings.showOnScreenSaver)
                Divider()
                ToggleRow("Mantieni schermo attivo in carica", icon: "bolt.shield", tint: OrielColors.green, isOn: $settings.keepAwake)
            }

            SettingsCard("Widget Attivi", icon: "square.grid.2x2.fill", tint: OrielColors.purple) {
                ToggleRow("Now Playing", icon: "music.note", tint: OrielColors.coral, isOn: $settings.allowNowPlayingWidgetWhenLocked)
                Divider()
                ToggleRow("Meteo", icon: "cloud.sun.fill", tint: OrielColors.sky, isOn: $settings.allowWeatherWidgetWhenLocked)
                if settings.allowWeatherWidgetWhenLocked {
                    Divider()
                    Picker("Modalità meteo", selection: $settings.weatherStyle) {
                        ForEach(WeatherStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    Divider()
                    HStack {
                        Text("Permesso Posizione")
                        Spacer()
                        if weather.authorizationStatus == .authorizedAlways || weather.authorizationStatus == .authorized {
                            Label("Attivo", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(OrielColors.charging)
                        } else {
                            Button("Abilita Posizione") {
                                weather.requestPermission()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                Divider()
                ToggleRow("Calendario", icon: "calendar", tint: OrielColors.orange, isOn: $settings.allowCalendarWidgetWhenLocked)
                Divider()
                ToggleRow("Full Immersion", icon: "moon.fill", tint: OrielColors.indigo, isOn: $settings.allowFocusWidgetWhenLocked)
                Divider()
                ToggleRow("Connettività", icon: "airpodspro", tint: OrielColors.sky, isOn: $settings.allowConnectivityWidgetWhenLocked)
                Divider()
                ToggleRow("Batteria", icon: "battery.75percent", tint: OrielColors.green, isOn: $settings.allowBatteryWidgetWhenLocked)
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
                        Text("Dynamic Island nativa, HUD hardware a zero latenza, Calendario, File Tray e Widget Lock Screen.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Divider()
                HStack {
                    Button("Apri Notch") {
                        controller.setExpanded(true)
                    }
                    Button("Ripristina Onboarding") {
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
            SettingLabel("Intercettazione Tasti (Accessibilità)", caption: "Necessaria per nascondere le HUD standard di macOS", icon: "keyboard.badge.ellipsis", tint: OrielColors.amber)
            Spacer()
            if mediaKeys.isAccessibilityAuthorized {
                Label("Attivo (\(mediaKeys.activeTapMode))", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(OrielColors.charging)
            } else {
                HStack(spacing: 6) {
                    Button("Riavvia App") {
                        relaunchCurrentApp()
                    }
                    .buttonStyle(.bordered)
                    Button("Concedi Accessibilità") {
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
        case .general: return "Profili rapidi, colori, reattività animazioni, zona hover e dimensioni."
        case .battery: return "Avvisi di ricarica, risparmio energetico e batteria scarica."
        case .connectivity: return "Notifiche intelligenti AirPods e cuffie Bluetooth."
        case .focus: return "Banner Full Immersion e sostituzione dell'onda audio."
        case .display: return "Sostituzione istantanea dell'HUD Luminosità di macOS."
        case .sound: return "Sostituzione istantanea dell'HUD Volume di macOS."
        case .nowPlaying: return "Spotify, Apple Music, spettro 6 bande e Quick Peek."
        case .calendar: return "Eventi imminenti, link riunione, meteo e Time to Leave."
        case .fileTray: return "Vassoio rapido drag & drop direttamente sul Notch."
        case .lockScreen: return "Widget Glass, Frosted e Clear sulla schermata di blocco."
        case .about: return "Versione, azioni rapide e procedura guidata."
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
