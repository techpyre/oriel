<div align="center">
  <h1>O R I E L</h1>
  <p>
    <strong>Native Obsidian Liquid Glass Island &amp; Lock Screen Overlay for macOS</strong>
  </p>

  <p>
    <a href="https://github.com/techpyre/oriel/releases/latest/download/Oriel.dmg"><strong>Download Oriel.dmg (v1.0.0) ↓</strong></a>
    &nbsp;·&nbsp;
    <a href="https://github.com/techpyre/oriel/releases/latest/download/Oriel.zip">Oriel.zip</a>
    &nbsp;·&nbsp;
    <a href="https://oriel-web-liart.vercel.app"><strong>Website ↗</strong></a>
  </p>

  <p>
    <img src="https://img.shields.io/badge/macOS-15%20%2F%2026%20Tahoe-111111?style=flat-square&labelColor=f4ead4&color=321b1b" alt="macOS 15 / 26" />
    <img src="https://img.shields.io/badge/Swift-6.0-111111?style=flat-square&labelColor=8ad8c3&color=321b1b" alt="Swift 6" />
    <img src="https://img.shields.io/badge/AppKit%20%2B%20SwiftUI-120Hz-111111?style=flat-square&labelColor=f4ead4&color=321b1b" alt="AppKit SwiftUI" />
    <img src="https://img.shields.io/badge/License-MIT-111111?style=flat-square&labelColor=8ad8c3&color=321b1b" alt="MIT License" />
  </p>
</div>

---

**Oriel** turns the hardware camera notch and the macOS Lock Screen into a native 120Hz **Obsidian Liquid Glass** instrument — built from scratch in Swift, AppKit, and SwiftUI with zero Electron overhead.

## Direct Download

1. Download **[Oriel.dmg](https://github.com/techpyre/oriel/releases/latest/download/Oriel.dmg)** *(or [Oriel.zip](https://github.com/techpyre/oriel/releases/latest/download/Oriel.zip))*.
2. Open the disk image and drag **Oriel.app** into **Applications**.
3. Since Oriel is unsigned/self-signed for free open-source distribution, allow it on first launch:
   ```bash
   xattr -cr /Applications/Oriel.app && open /Applications/Oriel.app
   ```
   *(Or Right-Click `Oriel.app` → **Open**).*

---

## Core Capabilities

| Subsystem | What It Does | Implementation |
| :--- | :--- | :--- |
| **Seamless Notch Shell** | Fuses pure black top hardware bezel seamlessly into `NSGlassEffectView` with matched-geometry tab transitions and zero idle CPU thrashing. | `NotchView.swift` · `NotchShapeAndEffects.swift` · `NotchController.swift` |
| **Now Playing & Spectrum** | Concurrent Spotify, Apple Music, and browser stream detection with async Spotify oEmbed + iTunes 600px artwork caching and an isolated 6-band CoreAudio FFT `Canvas`. | `MediaManager.swift` · `AudioManager.swift` · `OrielHelper.xpc` |
| **Tactile Brightness & Volume HUD** | Intercepts hardware media/brightness/volume keys cleanly via `CGEventTap` (`NX_SYSDEFINED` only), replacing stock HUD boxes with elastic `0%`/`100%` recoil bars. | `MediaKeyManager.swift` · `VolumeManager.swift` · `BrightnessManager.swift` |
| **Lock Screen Overlay** | Renders weather, calendar, Focus, battery, AirPods, and Now Playing cards on `CGShieldingWindowLevel` with dynamic bottom clearance `max(276pt, 30%)` so your Mac avatar & password box stay clear. | `LockScreenView.swift` · `LockManager.swift` |
| **Calendar Quick Peek & File Tray** | Month grid, upcoming meeting links (Zoom, Meet, Teams), time-to-leave ETA, Focus banners, Bluetooth battery banners, and drag-and-drop File Tray inside the notch. | `CalendarManager.swift` · `FocusManager.swift` · `ConnectivityManager.swift` |
| **TCC-Resilient Local Signing** | `setup_signing_cert.sh` provisions a 10-year local Keychain code-signing identity (`Oriel Local Signing`) when building from source so Accessibility & Automation grants survive rebuilds. | `scripts/setup_signing_cert.sh` · `scripts/build_app.sh` |

---

## Build from Source

Requires Swift 6 / Xcode Command Line Tools on macOS 15+.

```bash
git clone https://github.com/techpyre/oriel.git
cd oriel

# Run Swift Testing core unit suite
swift test --disable-xctest --enable-swift-testing

# Provision persistent local code-signing identity & install to /Applications/Oriel.app
bash scripts/build_app.sh
```

To build a distributable `.dmg` / `.zip` inside `build/` without touching `/Applications`:

```bash
bash scripts/build_app.sh --package-only
```

---

## Project Layout

```text
Oriel/
├── Package.swift
├── Resources/
│   ├── AppIcon.icns
│   └── Sounds/*.wav
├── Sources/
│   ├── Oriel/
│   │   ├── Views/        # NotchView, LockScreenView, SettingsView, OnboardingView
│   │   ├── Windows/      # NotchWindowController, NotchPanel, LockPanel
│   │   └── main.swift
│   ├── OrielCore/
│   │   ├── Managers/     # Media, Audio FFT, MediaKey HID, Calendar, Focus, Lock, Battery, Weather
│   │   ├── Models/       # AppSettings, NotchModels
│   │   ├── SPI/          # Dynamic macOS CoreDisplay / CoreAudio / MediaRemote bridges
│   │   ├── Services/     # XPCMediaBridge
│   │   └── Theme/        # OrielColors
│   └── OrielHelper/      # Sandboxed XPC helper companion
├── Tests/
│   └── OrielTests/       # Swift Testing unit suite
└── scripts/
    ├── setup_signing_cert.sh
    └── build_app.sh
```

---

<div align="center">
  <sub>Released under the MIT License</sub>
</div>
