import AppKit
import Combine
import SwiftUI
import OrielCore

// MARK: - Borderless Floating Notch NSPanel

@MainActor
public final class NotchPanel: NSPanel {
    public let targetScreen: NSScreen
    private let hostingView: NSHostingView<NotchView>
    private var shrinkWorkItem: DispatchWorkItem?

    public init(screen: NSScreen) {
        self.targetScreen = screen
        self.hostingView = NSHostingView(rootView: NotchView())

        let initialRect = Self.collapsedFrame(for: screen, controller: NotchController.shared)
        super.init(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isFloatingPanel = true
        hidesOnDeactivate = false
        // Default click-through so underlying apps never lose clicks;
        // NotchInteractionMonitor flips this to false ONLY while cursor is over the visible pill.
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = true
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        // Use assistiveTechHighWindow (1500) rather than CGShieldingWindowLevel() + N which
        // overflows 32-bit Int32 window levels in WindowServer into Int32.min (-2147483648).
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow)))

        hostingView.sizingOptions = []
        hostingView.frame = NSRect(origin: .zero, size: initialRect.size)
        hostingView.autoresizingMask = [.width, .height]
        contentView = hostingView
        updateScreenCaptureSharing()
    }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }

    public func updateScreenCaptureSharing() {
        sharingType = AppSettings.shared.hideFromScreenCapture ? .none : .readOnly
    }

    public static func notchMidX(for screen: NSScreen) -> CGFloat {
        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea,
           screen.safeAreaInsets.top > 0 {
            return (left.maxX + right.minX) * 0.5
        }
        return screen.frame.midX
    }

    /// Computes the exact clickable rect of the currently visible notch silhouette.
    public func activeClickRect(controller: NotchController) -> NSRect {
        let sf = targetScreen.frame
        let midX = Self.notchMidX(for: targetScreen)
        let settings = AppSettings.shared

        if controller.isHidden && !controller.isExpanded {
            return .zero
        }

        if controller.isExpanded || controller.quickPeek != .none || controller.notification != .none {
            let w = controller.currentWidth
            let h = controller.currentHeight
            // +12pt top overhang so pointer at exact top bezel (point.y == sf.maxY) passes half-open NSRect.contains
            return NSRect(x: midX - w / 2, y: sf.maxY - h, width: w, height: h + 12)
        }

        let hasClosedWings = controller.liveActivity != .none
            || controller.metrics.isSimulated
            || settings.forceSimulatedNotch
        let w = (hasClosedWings ? controller.currentWidth : controller.metrics.notchWidth) + 8
        let h = controller.metrics.notchHeight + 2
        return NSRect(x: midX - w / 2, y: sf.maxY - h, width: w, height: h + 12)
    }

    /// Generous hover-trigger zone covering the notch, closed wings, and immediate neighboring rim
    /// ("aree limitrofe"). Extends past sf.maxY so slamming pointer to top edge never exits hover.
    public func hoverTriggerRect(controller: NotchController) -> NSRect {
        let sf = targetScreen.frame
        let midX = Self.notchMidX(for: targetScreen)
        if controller.isHidden && !controller.isExpanded {
            return .zero
        }
        if controller.isExpanded {
            let w = controller.currentWidth + 36
            let h = controller.currentHeight + 18
            return NSRect(x: midX - w / 2, y: sf.maxY - h, width: w, height: h + 14)
        }
        let baseW = max(controller.currentWidth, controller.metrics.notchWidth)
        let padX: CGFloat = controller.isHovered ? 48 : 38
        let padY: CGFloat = controller.isHovered ? 24 : 18
        let w = baseW + padX * 2
        let h = controller.metrics.notchHeight + padY
        return NSRect(x: midX - w / 2, y: sf.maxY - h, width: w, height: h + 14)
    }

    /// Synchronously enlarges the NSWindow backing canvas right BEFORE SwiftUI mutates expansion/HUD state
    /// so spring animations are never cropped inside a collapsed 34pt window.
    public func ensureExpandedCanvasImmediately() {
        shrinkWorkItem?.cancel()
        shrinkWorkItem = nil
        let rect = Self.expandedCanvasFrame(for: targetScreen)
        if frame != rect {
            setFrame(rect, display: true)
        }
        orderFrontRegardless()
        ignoresMouseEvents = false
    }

    public func syncGeometry(controller: NotchController) {
        shrinkWorkItem?.cancel()
        let needsTallCanvas = controller.isExpanded
            || controller.quickPeek != .none
            || controller.notification != .none

        if needsTallCanvas {
            let rect = Self.expandedCanvasFrame(for: targetScreen)
            if frame != rect {
                setFrame(rect, display: true)
            }
            orderFrontRegardless()
        } else {
            let compact = Self.collapsedFrame(for: targetScreen, controller: controller)
            if frame.height > compact.height + 2 {
                let item = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    let c = NotchController.shared
                    guard !c.isExpanded && c.quickPeek == .none && c.notification == .none else { return }
                    let target = Self.collapsedFrame(for: self.targetScreen, controller: c)
                    if self.frame != target {
                        self.setFrame(target, display: true)
                    }
                    self.updateMousePassthrough(cursorPoint: NSEvent.mouseLocation, controller: c)
                }
                shrinkWorkItem = item
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.42, execute: item)
            } else if frame != compact {
                setFrame(compact, display: true)
            }
        }
        updateMousePassthrough(cursorPoint: NSEvent.mouseLocation, controller: controller)
    }

    public func updateMousePassthrough(cursorPoint: NSPoint, controller: NotchController) {
        let hitRect = activeClickRect(controller: controller)
        let shouldCapture = !hitRect.isEmpty && hitRect.contains(cursorPoint)
        if ignoresMouseEvents == shouldCapture {
            ignoresMouseEvents = !shouldCapture
        }
    }

    public static func expandedCanvasFrame(for screen: NSScreen) -> NSRect {
        let canvasWidth: CGFloat = 660
        let canvasHeight: CGFloat = 214
        let sf = screen.frame
        let x = notchMidX(for: screen) - canvasWidth / 2
        let y = sf.maxY - canvasHeight
        return NSRect(x: x, y: y, width: canvasWidth, height: canvasHeight)
    }

    public static func collapsedFrame(for screen: NSScreen, controller: NotchController) -> NSRect {
        let w = max(controller.currentWidth + 24, controller.metrics.notchWidth + 24)
        let h = controller.metrics.notchHeight + 2
        let sf = screen.frame
        return NSRect(x: notchMidX(for: screen) - w / 2, y: sf.maxY - h, width: w, height: h)
    }
}

// MARK: - Lock Screen Overlay Panel

@MainActor
public final class LockPanel: NSPanel {
    public init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle
        ]
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))

        let host = NSHostingView(rootView: LockScreenView())
        host.frame = NSRect(origin: .zero, size: screen.frame.size)
        host.autoresizingMask = [.width, .height]
        contentView = host
        sharingType = AppSettings.shared.hideFromScreenCapture ? .none : .readOnly
    }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}

// MARK: - Zero-Permission Cursor Tracker, Hover Halo, Outside-Click Collapse & Swipes

@MainActor
public final class NotchInteractionMonitor {
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var cursorPollTimer: Timer?
    private var lastPolledPoint: NSPoint = .zero
    private var accumulatedX: CGFloat = 0
    private var accumulatedY: CGFloat = 0
    private var gestureTriggered = false
    private var onCursorEvaluated: ((NSPoint) -> Bool)?

    public init() {}

    public func start(onCursorEvaluated: @escaping @MainActor (NSPoint) -> Bool) {
        stop()
        self.onCursorEvaluated = onCursorEvaluated

        // Zero-permission 30Hz NSEvent.mouseLocation tracker so hover works reliably
        // regardless of TCC global-mouseMoved restrictions or menu-bar tracking modes.
        lastPolledPoint = NSEvent.mouseLocation
        let timer = Timer(timeInterval: 0.032, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let loc = NSEvent.mouseLocation
                guard abs(loc.x - self.lastPolledPoint.x) > 0.5 || abs(loc.y - self.lastPolledPoint.y) > 0.5 else {
                    return
                }
                self.lastPolledPoint = loc
                let inHoverZone = self.onCursorEvaluated?(loc) ?? false
                NotchController.shared.handleHoverChanged(inHoverZone)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        cursorPollTimer = timer

        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .scrollWheel, .leftMouseDown]
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.processEvent(event)
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in
                self?.processEvent(event)
            }
        }
    }

    public func stop() {
        cursorPollTimer?.invalidate()
        cursorPollTimer = nil
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        onCursorEvaluated = nil
    }

    private func processEvent(_ event: NSEvent) {
        let loc = NSEvent.mouseLocation
        lastPolledPoint = loc
        let inHoverZone = onCursorEvaluated?(loc) ?? false
        let controller = NotchController.shared

        if event.type == .mouseMoved || event.type == .leftMouseDragged {
            controller.handleHoverChanged(inHoverZone)
            return
        }

        if event.type == .leftMouseDown {
            if controller.isExpanded && !inHoverZone {
                controller.setExpanded(false)
            }
            return
        }

        if event.type == .scrollWheel {
            handleScroll(event, inZone: inHoverZone)
        }
    }

    private func handleScroll(_ event: NSEvent, inZone: Bool) {
        let controller = NotchController.shared
        guard (controller.isHovered || controller.isExpanded), inZone else { return }

        if event.phase == .began {
            accumulatedX = 0
            accumulatedY = 0
            gestureTriggered = false
        }

        accumulatedX += event.scrollingDeltaX
        accumulatedY += event.scrollingDeltaY

        if !gestureTriggered {
            controller.updateSwipeGesturePreview(deltaX: accumulatedX, deltaY: accumulatedY)
            if abs(accumulatedY) > abs(accumulatedX), abs(accumulatedY) > 20 {
                gestureTriggered = true
                controller.resetSwipeGesturePreview()
                controller.handleVerticalSwipe(deltaY: accumulatedY)
            } else if abs(accumulatedX) > abs(accumulatedY), abs(accumulatedX) > 26 {
                gestureTriggered = true
                controller.resetSwipeGesturePreview()
                controller.handleHorizontalSwipe(deltaX: accumulatedX)
            }
        }

        if event.phase == .ended || event.phase == .cancelled {
            accumulatedX = 0
            accumulatedY = 0
            gestureTriggered = false
            controller.resetSwipeGesturePreview()
        }
    }
}

// MARK: - Window Coordinator (Notch + Lock + Settings + Onboarding)

@MainActor
public final class WindowCoordinator {
    public static let shared = WindowCoordinator()

    private var notchPanels: [NotchPanel] = []
    private var lockPanels: [LockPanel] = []
    private let elevatedSpace = SpaceManager(level: 400)
    private let interactionMonitor = NotchInteractionMonitor()

    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var cancellables: Set<AnyCancellable> = []

    private init() {}

    public func start() {
        rebuildNotchPanels()

        // Ensure AppKit NSWindow grows synchronously BEFORE SwiftUI mutates expansion state
        NotchController.shared.onBeforeExpandOrOverlay = { [weak self] in
            guard let self else { return }
            for panel in self.notchPanels {
                panel.ensureExpandedCanvasImmediately()
            }
        }

        interactionMonitor.start { [weak self] cursorPoint in
            guard let self else { return false }
            let controller = NotchController.shared
            var inAnyHoverZone = false
            for panel in self.notchPanels {
                panel.updateMousePassthrough(cursorPoint: cursorPoint, controller: controller)
                if panel.hoverTriggerRect(controller: controller).contains(cursorPoint) {
                    inAnyHoverZone = true
                }
            }
            return inAnyHoverZone
        }

        LockManager.shared.onLockStateChanged = { [weak self] locked in
            self?.handleLockChange(locked: locked)
            NotchController.shared.recomputeLiveActivity()
        }

        let nc = NotchController.shared
        Publishers.CombineLatest4(nc.$isExpanded, nc.$notification, nc.$quickPeek, nc.$liveActivity)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.syncNotchPanelsGeometry()
                }
            }
            .store(in: &cancellables)

        nc.$isHidden
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.syncNotchPanelsGeometry()
                }
            }
            .store(in: &cancellables)

        AppSettings.shared.objectWillChange
            .debounce(for: .milliseconds(120), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncSettingsChanges()
            }
            .store(in: &cancellables)

        ScreenManager.shared.$availableScreens
            .sink { [weak self] _ in
                self?.rebuildNotchPanels()
            }
            .store(in: &cancellables)
    }

    public func rebuildNotchPanels() {
        for panel in notchPanels {
            elevatedSpace.detach(window: panel)
            panel.orderOut(nil)
        }
        notchPanels.removeAll()

        let controller = NotchController.shared
        let targets = ScreenManager.shared.targetScreens(for: AppSettings.shared)
        controller.updateMetrics(for: targets.first)

        for screen in targets {
            let panel = NotchPanel(screen: screen)
            panel.orderFrontRegardless()
            elevatedSpace.attach(window: panel)
            panel.syncGeometry(controller: controller)
            notchPanels.append(panel)
        }
    }

    private func syncNotchPanelsGeometry() {
        let controller = NotchController.shared
        for panel in notchPanels {
            panel.syncGeometry(controller: controller)
        }
    }

    private func syncSettingsChanges() {
        let targets = ScreenManager.shared.targetScreens(for: AppSettings.shared)
        if targets.count != notchPanels.count ||
            zip(targets, notchPanels).contains(where: { ScreenManager.displayUUID(for: $0) != ScreenManager.displayUUID(for: $1.targetScreen) }) {
            rebuildNotchPanels()
            return
        }
        let controller = NotchController.shared
        controller.updateMetrics(for: targets.first)
        for panel in notchPanels {
            panel.syncGeometry(controller: controller)
            panel.updateScreenCaptureSharing()
        }
    }

    private func handleLockChange(locked: Bool) {
        for lp in lockPanels {
            elevatedSpace.detach(window: lp)
            lp.orderOut(nil)
        }
        lockPanels.removeAll()

        let shouldShow = AppSettings.shared.enableLockScreen &&
            (locked || (LockManager.shared.isScreensaverActive && AppSettings.shared.showOnScreenSaver))
        guard shouldShow else { return }

        for screen in ScreenManager.shared.targetScreens(for: AppSettings.shared) {
            let panel = LockPanel(screen: screen)
            panel.orderFrontRegardless()
            elevatedSpace.attach(window: panel)
            lockPanels.append(panel)
        }
    }

    public func showSettings() {
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView())
            let win = NSWindow(contentViewController: host)
            win.title = "Oriel Settings"
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.isOpaque = false
            win.backgroundColor = .clear
            win.toolbarStyle = .unified
            win.setContentSize(NSSize(width: 860, height: 650))
            win.center()
            win.isReleasedWhenClosed = false
            settingsWindow = win
        }
        NSApp.setActivationPolicy(.regular)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func showOnboarding() {
        if onboardingWindow == nil {
            let view = OnboardingView { [weak self] in
                self?.onboardingWindow?.close()
            }
            let host = NSHostingController(rootView: view)
            let win = NSWindow(contentViewController: host)
            win.title = "Welcome to Oriel"
            win.styleMask = [.titled, .closable, .fullSizeContentView]
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.isOpaque = false
            win.backgroundColor = .clear
            win.setContentSize(NSSize(width: 580, height: 500))
            win.center()
            win.isReleasedWhenClosed = false
            onboardingWindow = win
        }
        NSApp.setActivationPolicy(.regular)
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
