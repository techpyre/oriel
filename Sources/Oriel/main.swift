import AppKit
import Combine
import OrielCore

@MainActor
final class OrielAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Default to menu bar accessory app so Dock stays clean unless Settings/Onboarding open
        NSApp.setActivationPolicy(.accessory)

        // Warm up singletons & monitors
        _ = SoundManager.shared
        _ = HapticFeedback.shared
        _ = BatteryManager.shared
        _ = ConnectivityManager.shared
        _ = FocusManager.shared
        _ = VolumeManager.shared
        _ = BrightnessManager.shared
        _ = MediaManager.shared
        _ = AudioManager.shared
        _ = CalendarManager.shared
        _ = WeatherManager.shared
        _ = GameManager.shared
        _ = ScreenManager.shared
        _ = LockManager.shared
        _ = NotchController.shared

        MediaKeyManager.shared.start()
        WindowCoordinator.shared.start()
        setupStatusBarMenu()
        observeUIRequests()

        if !AppSettings.shared.hasCompletedOnboarding {
            WindowCoordinator.shared.showOnboarding()
        } else if UserDefaults.standard.bool(forKey: MediaKeyManager.reopenSettingsDefaultsKey) {
            UserDefaults.standard.removeObject(forKey: MediaKeyManager.reopenSettingsDefaultsKey)
            WindowCoordinator.shared.showSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MediaKeyManager.shared.stop()
    }

    private func observeUIRequests() {
        NotificationCenter.default.publisher(for: .orielSettings)
            .sink { _ in
                WindowCoordinator.shared.showSettings()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .orielOnboarding)
            .sink { _ in
                WindowCoordinator.shared.showOnboarding()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)
            .sink { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let hasVisibleRegularWindow = NSApp.windows.contains {
                        $0.isVisible && !($0 is NSPanel)
                    }
                    if !hasVisibleRegularWindow {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
            }
            .store(in: &cancellables)

        AppSettings.shared.$hideMenuBarIcon
            .sink { [weak self] hidden in
                if hidden {
                    self?.removeStatusBarItem()
                } else {
                    self?.setupStatusBarMenu()
                }
            }
            .store(in: &cancellables)
    }

    private func setupStatusBarMenu() {
        guard !AppSettings.shared.hideMenuBarIcon else { return }
        if statusItem != nil { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let img = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "Oriel")
            img?.isTemplate = true
            button.image = img
        }

        let menu = NSMenu()

        let openNotch = NSMenuItem(title: "Toggle Notch", action: #selector(toggleNotch), keyEquivalent: "n")
        openNotch.target = self
        menu.addItem(openNotch)

        let cycle = NSMenuItem(title: "Switch Notch Activity", action: #selector(cycleActivity), keyEquivalent: "k")
        cycle.target = self
        menu.addItem(cycle)

        menu.addItem(NSMenuItem.separator())

        let mediaItem = NSMenuItem(title: "Now Playing", action: #selector(openNowPlaying), keyEquivalent: "1")
        mediaItem.target = self
        menu.addItem(mediaItem)

        let calItem = NSMenuItem(title: "Calendar", action: #selector(openCalendar), keyEquivalent: "2")
        calItem.target = self
        menu.addItem(calItem)

        let duoItem = NSMenuItem(title: "Duo View", action: #selector(openDuo), keyEquivalent: "3")
        duoItem.target = self
        menu.addItem(duoItem)

        let trayItem = NSMenuItem(title: "File Tray", action: #selector(openFileTray), keyEquivalent: "4")
        trayItem.target = self
        menu.addItem(trayItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let onboardingItem = NSMenuItem(title: "Onboarding…", action: #selector(openOnboarding), keyEquivalent: "")
        onboardingItem.target = self
        menu.addItem(onboardingItem)

        let accessItem = NSMenuItem(title: "Check Accessibility Permission", action: #selector(checkAccessibility), keyEquivalent: "")
        accessItem.target = self
        menu.addItem(accessItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Oriel", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        self.statusItem = item
    }

    private func removeStatusBarItem() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    @objc private func toggleNotch() {
        NotchController.shared.toggleExpanded()
    }

    @objc private func cycleActivity() {
        if !NotchController.shared.isExpanded {
            NotchController.shared.setExpanded(true)
        } else {
            NotchController.shared.cycleExpandedActivity()
        }
    }

    @objc private func openNowPlaying() {
        NotchController.shared.setExpanded(true, activity: .nowPlaying)
    }

    @objc private func openCalendar() {
        NotchController.shared.setExpanded(true, activity: .calendar)
    }

    @objc private func openDuo() {
        NotchController.shared.setExpanded(true, activity: .duo)
    }

    @objc private func openFileTray() {
        NotchController.shared.setExpanded(true, activity: .fileTray)
    }

    @objc private func openSettings() {
        WindowCoordinator.shared.showSettings()
    }

    @objc private func openOnboarding() {
        WindowCoordinator.shared.showOnboarding()
    }

    @objc private func checkAccessibility() {
        MediaKeyManager.shared.promptAccessibilityPermission()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
MainActor.assumeIsolated {
    let delegate = OrielAppDelegate()
    app.delegate = delegate
    app.run()
}
