import AppKit
import SwiftUI
import OrielCore

// MARK: - Animation Springs

public enum OrielMotion {
    /// Spring curve for expanding and collapsing the notch.
    public static let liquidMorph = Animation.spring(duration: 0.28, bounce: 0.14)
    /// Matched-geometry sliding glass tab capsule.
    public static let fluidTab = Animation.spring(duration: 0.24, bounce: 0.10)
    /// Short spring for button presses and boundary bounce.
    public static let elasticTap = Animation.spring(duration: 0.16, bounce: 0.22)
    /// Transform-only content reveal.
    public static let opticalReveal = Animation.spring(duration: 0.24, bounce: 0.08)
    /// Ambient album color crossfade.
    public static let ambientColor = Animation.easeInOut(duration: 0.50)
}

// MARK: - Oriel Notch Silhouette Shape

public struct NotchShape: InsettableShape {
    public var topCornerRadius: CGFloat
    public var bottomCornerRadius: CGFloat
    public var insetAmount: CGFloat = 0

    public init(topCornerRadius: CGFloat = 8, bottomCornerRadius: CGFloat = 16) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    public func inset(by amount: CGFloat) -> NotchShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    public func path(in rawRect: CGRect) -> Path {
        let rect = rawRect.insetBy(dx: insetAmount, dy: insetAmount)
        let topR = max(0, min(topCornerRadius, rect.width / 4))
        let botR = max(0, min(bottomCornerRadius, min(rect.width / 2 - topR, rect.height - 1)))

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topR, y: rect.minY + topR),
            control: CGPoint(x: rect.minX + topR, y: rect.minY)
        )

        path.addLine(to: CGPoint(x: rect.minX + topR, y: rect.maxY - botR))

        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topR + botR, y: rect.maxY),
            control: CGPoint(x: rect.minX + topR, y: rect.maxY)
        )

        path.addLine(to: CGPoint(x: rect.maxX - topR - botR, y: rect.maxY))

        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topR, y: rect.maxY - botR),
            control: CGPoint(x: rect.maxX - topR, y: rect.maxY)
        )

        path.addLine(to: CGPoint(x: rect.maxX - topR, y: rect.minY + topR))

        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topR, y: rect.minY)
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Glass Effect Backing

public struct NativeGlassView: NSViewRepresentable {
    public var cornerRadius: CGFloat
    public var tintAlpha: CGFloat
    public var styleRawValue: Int
    public var forceDarkAppearance: Bool

    public init(
        cornerRadius: CGFloat = 20,
        tintColor: NSColor? = nil,
        tintAlpha: CGFloat = 0.36,
        styleRawValue: Int = 0,
        forceDarkAppearance: Bool = true
    ) {
        self.cornerRadius = cornerRadius
        if let tintColor {
            self.tintAlpha = tintColor.alphaComponent
        } else {
            self.tintAlpha = tintAlpha
        }
        self.styleRawValue = styleRawValue
        self.forceDarkAppearance = forceDarkAppearance
    }

    public final class Coordinator {
        var appliedRadius: CGFloat = -1
        var appliedAlpha: CGFloat = -1
        var appliedStyle: Int = -1
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public func makeNSView(context: Context) -> NSView {
        if let glassClass = NSClassFromString("NSGlassEffectView") as? NSView.Type {
            let glass = glassClass.init(frame: .zero)
            glass.wantsLayer = true
            applyGlassProperties(to: glass, coordinator: context.coordinator)
            return glass
        }
        let fallback = NSVisualEffectView()
        fallback.material = .hudWindow
        fallback.blendingMode = .behindWindow
        fallback.state = .active
        fallback.wantsLayer = true
        fallback.layer?.cornerRadius = cornerRadius
        fallback.layer?.masksToBounds = true
        if forceDarkAppearance {
            fallback.appearance = NSAppearance(named: .darkAqua)
        }
        context.coordinator.appliedRadius = cornerRadius
        return fallback
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        let coord = context.coordinator
        guard coord.appliedRadius != cornerRadius
                || abs(coord.appliedAlpha - tintAlpha) > 0.01
                || coord.appliedStyle != styleRawValue else {
            return
        }
        if NSStringFromClass(type(of: nsView)) == "NSGlassEffectView" {
            applyGlassProperties(to: nsView, coordinator: coord)
        } else {
            nsView.layer?.cornerRadius = cornerRadius
            coord.appliedRadius = cornerRadius
        }
    }

    private func applyGlassProperties(to view: NSView, coordinator: Coordinator) {
        if forceDarkAppearance {
            view.appearance = NSAppearance(named: .darkAqua)
        }
        if coordinator.appliedRadius != cornerRadius {
            if view.responds(to: NSSelectorFromString("setCornerRadius:")) {
                view.setValue(cornerRadius, forKey: "cornerRadius")
            }
            view.layer?.cornerRadius = cornerRadius
            view.layer?.masksToBounds = true
            coordinator.appliedRadius = cornerRadius
        }
        if coordinator.appliedStyle != styleRawValue {
            if view.responds(to: NSSelectorFromString("setStyle:")) {
                view.setValue(styleRawValue, forKey: "style")
            }
            coordinator.appliedStyle = styleRawValue
        }
        if abs(coordinator.appliedAlpha - tintAlpha) > 0.01 {
            if view.responds(to: NSSelectorFromString("setTintColor:")) {
                view.setValue(NSColor(calibratedWhite: 0.02, alpha: tintAlpha), forKey: "tintColor")
            }
            coordinator.appliedAlpha = tintAlpha
        }
    }
}

/// Glass surface blended with the top display bezel without invalidating layers mid-spring.
public struct LiquidNotchSurface: View {
    public let shape: NotchShape
    public let notchWidth: CGFloat
    public let notchHeight: CGFloat
    public let hasPhysicalNotch: Bool
    public let isExpanded: Bool
    public let isCompactOverlay: Bool
    public let isHovered: Bool
    public let accentTint: Color
    public let blurredArtwork: NSImage?
    public let dominantColors: [Color]
    public let showOutline: Bool

    public init(
        shape: NotchShape,
        notchWidth: CGFloat,
        notchHeight: CGFloat,
        hasPhysicalNotch: Bool,
        isExpanded: Bool,
        isCompactOverlay: Bool,
        isHovered: Bool = false,
        accentTint: Color,
        blurredArtwork: NSImage? = nil,
        dominantColors: [Color] = [],
        showOutline: Bool = true
    ) {
        self.shape = shape
        self.notchWidth = notchWidth
        self.notchHeight = notchHeight
        self.hasPhysicalNotch = hasPhysicalNotch
        self.isExpanded = isExpanded
        self.isCompactOverlay = isCompactOverlay
        self.isHovered = isHovered
        self.accentTint = accentTint
        self.blurredArtwork = blurredArtwork
        self.dominantColors = dominantColors
        self.showOutline = showOutline
    }

    public var body: some View {
        ZStack(alignment: .top) {
            // 1. Keep NSGlassEffectView configuration stable during spring animations
            NativeGlassView(
                cornerRadius: 20,
                tintAlpha: 0.36,
                styleRawValue: 0,
                forceDarkAppearance: true
            )
            .allowsHitTesting(false)

            // 2. Dark tint vignette softening the edge under the black menu bar bezel
            LinearGradient(
                colors: isExpanded
                    ? [
                        Color.black.opacity(0.94),
                        Color.black.opacity(0.72),
                        Color.black.opacity(0.54),
                        Color.black.opacity(0.62)
                    ]
                    : [
                        Color.black.opacity(0.96),
                        Color.black.opacity(0.78)
                    ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // 3. Top cap matching the camera housing silhouette
            if hasPhysicalNotch {
                VStack(spacing: 0) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black)
                            .frame(width: notchWidth + 14, height: notchHeight + 2)

                        Capsule(style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.black.opacity(0.98),
                                        Color.black.opacity(0.76),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: notchWidth * 0.35,
                                    endRadius: notchWidth * 0.84
                                )
                            )
                            .frame(width: notchWidth * 1.7, height: notchHeight + 16)
                    }
                    .offset(y: -3)
                    Spacer(minLength: 0)
                }
                .allowsHitTesting(false)
            }

            // 4. Pre-blurred GPU texture ambient album glow (computed once off main thread!)
            if isExpanded {
                ArtworkCutoutBackdrop(
                    blurredArtwork: blurredArtwork,
                    dominantColors: dominantColors.isEmpty ? [accentTint] : dominantColors,
                    intensity: blurredArtwork != nil ? 0.50 : 0.24
                )
                .animation(OrielMotion.ambientColor, value: dominantColors)
                .allowsHitTesting(false)
            } else if isCompactOverlay {
                RadialGradient(
                    colors: [accentTint.opacity(0.20), Color.clear],
                    center: .bottom,
                    startRadius: 4,
                    endRadius: 145
                )
                .allowsHitTesting(false)
            }

            // 5. Internal top-to-bottom optical liquid sheen
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(isExpanded ? 0.05 : 0.03),
                    Color.clear,
                    Color.white.opacity(isExpanded ? 0.08 : (isHovered ? 0.07 : 0.04))
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .clipShape(shape)
        .overlay {
            if showOutline {
                shape
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.0), location: 0.0),
                                .init(color: Color.white.opacity(isExpanded ? 0.14 : (isHovered ? 0.18 : 0.10)), location: 0.24),
                                .init(color: Color.white.opacity(isExpanded ? 0.26 : (isHovered ? 0.30 : 0.18)), location: 0.68),
                                .init(color: Color.white.opacity(isExpanded ? 0.42 : (isHovered ? 0.40 : 0.25)), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: isExpanded ? 1.0 : 0.85
                    )
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Button Press Style & Content Reveal

public struct LiquidPressButtonStyle: ButtonStyle {
    public var pressedScale: CGFloat

    public init(pressedScale: CGFloat = 0.91) {
        self.pressedScale = pressedScale
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .brightness(configuration.isPressed ? 0.08 : 0.0)
            .animation(OrielMotion.elasticTap, value: configuration.isPressed)
    }
}

public struct LiquidOpticalReveal: ViewModifier {
    public let visible: Bool
    public let delay: Double

    public func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.96, anchor: .top)
            .offset(y: visible ? 0 : -5)
            .animation(
                OrielMotion.opticalReveal.delay(visible ? delay : 0),
                value: visible
            )
    }
}

public extension View {
    func liquidReveal(visible: Bool, delay: Double = 0) -> some View {
        modifier(LiquidOpticalReveal(visible: visible, delay: delay))
    }
}

// MARK: - Liquid Glass Floating Controls & Cards

public struct LiquidGlassCard<Content: View>: View {
    public var cornerRadius: CGFloat
    public var tint: Color
    public var darkModePanel: Bool
    public let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    public init(
        cornerRadius: CGFloat = 14,
        tint: Color = .clear,
        darkModePanel: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.darkModePanel = darkModePanel
        self.content = content
    }

    public var body: some View {
        let isDark = darkModePanel || colorScheme == .dark
        content()
            .background {
                ZStack {
                    if darkModePanel {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(0.068))
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(isDark ? Color.white.opacity(0.055) : Color.white.opacity(0.58))
                    }
                    if tint != .clear {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [tint.opacity(isDark ? 0.14 : 0.10), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isDark ? 0.24 : 0.78),
                                Color.white.opacity(isDark ? 0.08 : 0.25),
                                Color.white.opacity(isDark ? 0.16 : 0.45)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.85
                    )
                    .allowsHitTesting(false)
            }
    }
}

public struct LiquidGlassIconButton: View {
    public let systemName: String
    public var size: CGFloat = 24
    public var iconSize: CGFloat = 10.5
    public var tint: Color = .white
    public var prominent: Bool = false
    public var glowTint: Color = .clear
    public let action: () -> Void

    @State private var hovered = false

    public init(
        systemName: String,
        size: CGFloat = 24,
        iconSize: CGFloat = 10.5,
        tint: Color = .white,
        prominent: Bool = false,
        glowTint: Color = .clear,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.size = size
        self.iconSize = iconSize
        self.tint = tint
        self.prominent = prominent
        self.glowTint = glowTint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(tint.opacity(hovered || prominent ? 1.0 : 0.80))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size, height: size)
                .background {
                    Circle()
                        .fill(
                            prominent
                                ? Color.white.opacity(hovered ? 0.28 : 0.19)
                                : Color.white.opacity(hovered ? 0.19 : 0.085)
                        )
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(hovered ? 0.48 : 0.24),
                                            Color.white.opacity(0.06)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.8
                                )
                        }
                }
                .scaleEffect(hovered ? 1.07 : 1.0)
                .animation(.spring(duration: 0.18, bounce: 0.16), value: hovered)
        }
        .buttonStyle(LiquidPressButtonStyle(pressedScale: 0.88))
        .onHover { hovering in
            hovered = hovering
        }
    }
}

// MARK: - Marquee Text

public struct MarqueeText: View {
    public let text: String
    public let font: Font
    public let color: Color
    public var speed: CGFloat = 24
    public var pauseDuration: TimeInterval = 1.6

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offsetX: CGFloat = 0
    @State private var animationID = UUID()

    public init(
        _ text: String,
        font: Font = .system(size: 13, weight: .semibold),
        color: Color = .white,
        speed: CGFloat = 24,
        pauseDuration: TimeInterval = 1.6
    ) {
        self.text = text
        self.font = font
        self.color = color
        self.speed = speed
        self.pauseDuration = pauseDuration
    }

    private var needsScroll: Bool {
        textWidth > containerWidth + 2 && containerWidth > 10
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Text(text)
                    .font(font)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(
                        GeometryReader { textGeo in
                            Color.clear
                                .onAppear {
                                    textWidth = textGeo.size.width
                                    containerWidth = geo.size.width
                                    restartScroll()
                                }
                                .onChange(of: textGeo.size.width) { _, newVal in
                                    textWidth = newVal
                                    restartScroll()
                                }
                        }
                    )
                    .offset(x: needsScroll ? offsetX : 0)
            }
            .frame(width: geo.size.width, alignment: .leading)
            .clipped()
            .mask(
                HStack(spacing: 0) {
                    LinearGradient(
                        colors: [.clear, .black],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: needsScroll && offsetX < -2 ? 8 : 0)

                    Rectangle().fill(Color.black)

                    LinearGradient(
                        colors: [.black, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: needsScroll ? 10 : 0)
                }
            )
            .onChange(of: geo.size.width) { _, newWidth in
                containerWidth = newWidth
                restartScroll()
            }
            .onChange(of: text) { _, _ in
                offsetX = 0
                restartScroll()
            }
        }
        .frame(height: 17)
    }

    private func restartScroll() {
        let token = UUID()
        animationID = token
        offsetX = 0
        guard needsScroll else { return }

        let travel = textWidth - containerWidth + 10
        let duration = max(1.2, Double(travel / speed))

        Task { @MainActor in
            while !Task.isCancelled && animationID == token {
                try? await Task.sleep(for: .seconds(pauseDuration))
                guard animationID == token else { return }
                withAnimation(.linear(duration: duration)) {
                    offsetX = -travel
                }
                try? await Task.sleep(for: .seconds(duration + pauseDuration * 0.7))
                guard animationID == token else { return }
                withAnimation(.easeOut(duration: 0.45)) {
                    offsetX = 0
                }
            }
        }
    }
}

// MARK: - 6-Bar Audio Level Waveform

public struct LiveAudioWaveform: View {
    public let isPlaying: Bool
    public let useLiveLevels: Bool
    public let tint: Color
    public var barWidth: CGFloat = 2.1
    public var spacing: CGFloat = 1.7
    public var maxHeight: CGFloat = 14

    @ObservedObject private var audio = AudioManager.shared

    public init(
        isPlaying: Bool,
        useLiveLevels: Bool = true,
        tint: Color = OrielColors.accent,
        barWidth: CGFloat = 2.1,
        spacing: CGFloat = 1.7,
        maxHeight: CGFloat = 14
    ) {
        self.isPlaying = isPlaying
        self.useLiveLevels = useLiveLevels
        self.tint = tint
        self.barWidth = barWidth
        self.spacing = spacing
        self.maxHeight = maxHeight
    }

    public var body: some View {
        WaveformView(
            levels: useLiveLevels ? audio.liveLevels : [],
            isPlaying: isPlaying,
            tint: tint,
            barWidth: barWidth,
            spacing: spacing,
            maxHeight: maxHeight
        )
    }
}

public struct WaveformView: View {
    public let levels: [CGFloat]
    public let isPlaying: Bool
    public let tint: Color
    public var barWidth: CGFloat = 2.1
    public var spacing: CGFloat = 1.7
    public var maxHeight: CGFloat = 14

    public init(
        levels: [CGFloat],
        isPlaying: Bool,
        tint: Color = OrielColors.accent,
        barWidth: CGFloat = 2.1,
        spacing: CGFloat = 1.7,
        maxHeight: CGFloat = 14
    ) {
        self.levels = levels
        self.isPlaying = isPlaying
        self.tint = tint
        self.barWidth = barWidth
        self.spacing = spacing
        self.maxHeight = maxHeight
    }

    public var body: some View {
        let totalWidth = barWidth * 6 + spacing * 5
        TimelineView(.animation(minimumInterval: 1.0 / 18.0, paused: !isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let midY = size.height * 0.5
                for index in 0..<6 {
                    let norm = barHeight(index: index, time: t)
                    let h = max(2.5, norm * size.height)
                    let x = CGFloat(index) * (barWidth + spacing)
                    let rect = CGRect(x: x, y: midY - h * 0.5, width: barWidth, height: h)
                    let path = Path(roundedRect: rect, cornerRadius: barWidth * 0.5)
                    ctx.fill(path, with: .color(tint.opacity(0.92)))
                }
            }
            .frame(width: totalWidth, height: maxHeight)
        }
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        guard isPlaying else { return 0.18 }
        let liveValue = index < levels.count ? levels[index] : 0
        if liveValue > 0.04 {
            return min(1.0, max(0.18, liveValue))
        }
        let freq = 3.0 + Double(index) * 0.78
        let osc = 0.5 + 0.5 * sin(time * freq + Double(index) * 1.15)
        let secondary = 0.5 + 0.5 * cos(time * (freq * 0.52) + Double(index) * 0.45)
        return CGFloat(0.22 + 0.72 * (0.65 * osc + 0.35 * secondary))
    }
}

// MARK: - Cached Artwork Backdrop

public struct ArtworkCutoutBackdrop: View {
    public let blurredArtwork: NSImage?
    public let dominantColors: [Color]
    public var intensity: Double = 0.45

    public init(blurredArtwork: NSImage?, dominantColors: [Color], intensity: Double = 0.45) {
        self.blurredArtwork = blurredArtwork
        self.dominantColors = dominantColors
        self.intensity = intensity
    }

    public var body: some View {
        ZStack {
            if let blurredArtwork {
                Image(nsImage: blurredArtwork)
                    .resizable()
                    .interpolation(.low)
                    .scaledToFill()
                    .opacity(intensity * 0.52)
                    .allowsHitTesting(false)
            }
            if let primary = dominantColors.first {
                RadialGradient(
                    colors: [primary.opacity(intensity * 0.42), Color.clear],
                    center: .bottomLeading,
                    startRadius: 10,
                    endRadius: 210
                )
                .allowsHitTesting(false)
            }
            if dominantColors.count > 1 {
                RadialGradient(
                    colors: [dominantColors[1].opacity(intensity * 0.28), Color.clear],
                    center: .bottomTrailing,
                    startRadius: 8,
                    endRadius: 190
                )
                .allowsHitTesting(false)
            }
        }
        .clipped()
    }
}

// MARK: - NSVisualEffectView Wrapper & Lock Screen Glass Surface

public struct VisualEffectBlur: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    public var state: NSVisualEffectView.State = .active
    public var isEmphasized: Bool = false

    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active,
        isEmphasized: Bool = false
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
        self.isEmphasized = isEmphasized
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = isEmphasized
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        if nsView.material != material { nsView.material = material }
        if nsView.blendingMode != blendingMode { nsView.blendingMode = blendingMode }
        if nsView.state != state { nsView.state = state }
        if nsView.isEmphasized != isEmphasized { nsView.isEmphasized = isEmphasized }
    }
}

public struct LockScreenWidgetSurface<Content: View>: View {
    public let style: LockScreenNowPlayingStyle
    public var cornerRadius: CGFloat = 20
    public let content: () -> Content

    public init(
        style: LockScreenNowPlayingStyle,
        cornerRadius: CGFloat = 20,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.cornerRadius = cornerRadius
        self.content = content
    }

    public var body: some View {
        content()
            .background {
                switch style {
                case .clear:
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.black.opacity(0.32))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.32), Color.white.opacity(0.10)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                case .frosted:
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.black.opacity(0.24))
                        .background(
                            VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.34), Color.white.opacity(0.12)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                case .glass:
                    NativeGlassView(
                        cornerRadius: cornerRadius,
                        tintAlpha: 0.32,
                        styleRawValue: 0,
                        forceDarkAppearance: true
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.38), Color.white.opacity(0.12), Color.white.opacity(0.28)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.34), radius: 16, x: 0, y: 10)
    }
}

// MARK: - Liquid Glass HUD Progress Bar

public struct HUDProgressBar: View {
    public let value: Double // 0...1
    public let style: HUDProgressStyle
    public let tint: Color
    public var isMuted: Bool = false

    public init(value: Double, style: HUDProgressStyle, tint: Color = .white, isMuted: Bool = false) {
        self.value = min(1, max(0, value))
        self.style = style
        self.tint = tint
        self.isMuted = isMuted
    }

    public var body: some View {
        switch style {
        case .decibel:
            Text(isMuted ? "-∞ dB" : VolumeManager.decibelString(for: Float(value)))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(.white.opacity(0.92))
        case .white, .accent, .stylized, .glow:
            let barTint: Color = {
                switch style {
                case .white: return .white
                case .accent: return AppSettings.shared.accentColor
                case .stylized, .glow: return tint
                case .decibel: return .white
                }
            }()
            GeometryReader { geo in
                let fillWidth = max(value > 0 ? 6 : 0, geo.size.width * value)
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.15))

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [barTint.opacity(0.86), barTint, .white.opacity(0.94)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth)
                }
            }
            .frame(height: 6)
            .animation(.spring(duration: 0.14, bounce: 0.08), value: value)
        }
    }
}
