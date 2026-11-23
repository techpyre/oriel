import AppKit
import SwiftUI
import OrielCore

public struct OnboardingView: View {
    public let onFinish: () -> Void

    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var mediaKeys = MediaKeyManager.shared
    @ObservedObject private var calendar = CalendarManager.shared
    @ObservedObject private var weather = WeatherManager.shared
    @ObservedObject private var audio = AudioManager.shared
    @ObservedObject private var connectivity = ConnectivityManager.shared

    @State private var step: Int = 0

    public init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    public var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.68),
                    settings.accentColor.opacity(0.14),
                    Color.black.opacity(0.80)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                if step == 0 {
                    welcomeStep
                } else {
                    permissionsStep
                }
            }
            .padding(28)
        }
        .frame(width: 580, height: 500)
    }

    private var welcomeStep: some View {
        VStack(spacing: 18) {
            Spacer()

            let previewShape = NotchShape(topCornerRadius: 12, bottomCornerRadius: 18)
            ZStack {
                LiquidNotchSurface(
                    shape: previewShape,
                    notchWidth: 120,
                    notchHeight: 28,
                    hasPhysicalNotch: true,
                    isExpanded: false,
                    isCompactOverlay: true,
                    accentTint: settings.accentColor,
                    showOutline: true
                )
                HStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(settings.accentColor.gradient)
                        .frame(width: 20, height: 20)
                    Spacer()
                    WaveformView(levels: [0.4, 0.8, 0.6, 0.9, 0.5, 0.3], isPlaying: true, tint: settings.accentColor, barWidth: 2.1, spacing: 1.7, maxHeight: 15)
                }
                .padding(.horizontal, 22)
            }
            .frame(width: 268, height: 42)
            .shadow(color: settings.accentColor.opacity(0.28), radius: 22, y: 8)

            Text("Welcome to Oriel")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)

            Text("Dynamic Island live activities, HUD controls, Lock Screen widgets, Calendar, and File Tray around your MacBook notch.")
                .font(.system(size: 13.5))
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            Spacer()

            HStack {
                Button("Open Settings Later") {
                    settings.hasCompletedOnboarding = true
                    onFinish()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.6))

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        step = 1
                    }
                } label: {
                    Text("Configure Permissions")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(OrielColors.accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Permissions & Integrations")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Text("Grant only what you want to use daily. Every feature works seamlessly once enabled.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.65))
            }

            VStack(spacing: 8) {
                permissionRow(
                    icon: "keyboard.badge.ellipsis",
                    color: OrielColors.amber,
                    title: "Accessibility (Volume & Brightness HUD)",
                    subtitle: "Intercepts hardware media, volume, and brightness keys cleanly.",
                    granted: mediaKeys.isAccessibilityAuthorized
                ) {
                    mediaKeys.promptAccessibilityPermission()
                }

                permissionRow(
                    icon: "calendar",
                    color: OrielColors.orange,
                    title: "Calendar",
                    subtitle: "Shows upcoming meetings, Join links, and Time-to-Leave alerts.",
                    granted: calendar.authorizationStatus == .fullAccess || calendar.authorizationStatus == .authorized
                ) {
                    calendar.requestAccess()
                }

                permissionRow(
                    icon: "waveform",
                    color: OrielColors.coral,
                    title: "Screen / System Audio Capture",
                    subtitle: "Powers the real-time 6-bar FFT audio spectrum.",
                    granted: audio.authorizationStatus == .authorized
                ) {
                    audio.requestPermission()
                }

                permissionRow(
                    icon: "cloud.sun.fill",
                    color: OrielColors.sky,
                    title: "Location (Weather)",
                    subtitle: "Fetches local Open-Meteo conditions for empty calendar days and Lock Screen.",
                    granted: weather.authorizationStatus == .authorizedAlways || weather.authorizationStatus == .authorized
                ) {
                    weather.requestPermission()
                }

                permissionRow(
                    icon: "airpodspro",
                    color: OrielColors.teal,
                    title: "Bluetooth",
                    subtitle: "Detects AirPods and wireless headphones connection notifications.",
                    granted: connectivity.bluetoothAuthorized == .allowedAlways
                ) {
                    connectivity.requestBluetoothPermission()
                }
            }

            Spacer()

            HStack {
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: {
                        settings.launchAtLogin = $0
                        LaunchAtLoginManager.setEnabled($0)
                    }
                ))
                .toggleStyle(.switch)
                .foregroundStyle(.white)

                Spacer()

                Button {
                    settings.hasCompletedOnboarding = true
                    onFinish()
                } label: {
                    Text("Start Using Oriel")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(OrielColors.accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func permissionRow(
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        granted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.2))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            if granted {
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(OrielColors.charging)
            } else {
                Button("Allow", action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(OrielColors.accent)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.7)
        )
    }
}
