# Oriel

A native macOS notch utility and Lock Screen overlay written in Swift 6 and AppKit.

Download the latest release (`Oriel.dmg` or `Oriel.zip`) from the [Releases](https://github.com/techpyre/oriel/releases) page, or visit the [project page](https://oriel-web-liart.vercel.app).

## Install

1. Download **`Oriel.dmg`** from [Latest Release](https://github.com/techpyre/oriel/releases/latest).
2. Drag **`Oriel.app`** into **`Applications`**.
3. On first launch, right-click **`Oriel.app`** and choose **Open** once.

Because open-source GitHub releases are not notarized by Apple, Gatekeeper asks for confirmation once. Alternatively, clear quarantine from Terminal:

```bash
xattr -cr /Applications/Oriel.app && open /Applications/Oriel.app
```

## Features

- **Notch Workspace**: Hover or click near the MacBook camera housing (or top screen edge on external displays) to switch between Now Playing, Calendar, Duo View, and the File Tray.
- **Now Playing & Audio Meter**: Reads active playback from Spotify, Apple Music, Safari, and Chrome with album cover art and a six-band audio spectrum via CoreAudio Process Tap (`OrielHelper.xpc`).
- **Volume & Brightness Overlay**: Replaces macOS's default centered overlay using a lightweight `CGEventTap` (`NX_SYSDEFINED`) that stays tucked beside the notch.
- **Calendar & File Tray**: Shows today's EventKit schedule, meeting links, time-to-leave alerts, and a drag-and-drop shelf for temporarily holding files across Spaces.
- **Lock Screen Overlay**: Displays Now Playing, weather, calendar, Focus status, AirPods, and battery widgets positioned above the account login avatar.

## Build from Source

Requires macOS 15+ (macOS 26 recommended for native `NSGlassEffectView`) and Xcode or Apple Command Line Tools with Swift 6.

```bash
git clone https://github.com/techpyre/oriel.git
cd oriel

# Optional: create a local code-signing certificate in your login keychain
# so macOS Accessibility & Automation permissions persist across rebuilds
bash scripts/setup_signing_cert.sh

# Build Oriel.app, install to /Applications/Oriel.app, and generate DMG + ZIP
bash scripts/build_app.sh
```

Run tests:

```bash
swift test --disable-xctest --enable-swift-testing
```

On Command Line Tools setups without full Xcode, pass the active SDK path:

```bash
SDKROOT=$(xcrun --show-sdk-path)
swift test --disable-xctest --enable-swift-testing --sdk "$SDKROOT" \
  -Xswiftc -plugin-path -Xswiftc "$(dirname "$(dirname "$SDKROOT")")/usr/lib/swift/host/plugins/testing"
```

## Permissions

- **Accessibility**: Intercepts hardware volume and brightness keys so Oriel can replace macOS's built-in overlays.
- **Automation (Spotify / Music)**: Reads current track metadata when MediaRemote restricts third-party playback info.
- **Calendar**: Populates today's schedule and upcoming meeting links.
- **Location**: Fetches local forecast conditions via Open-Meteo for the Lock Screen and empty calendar days.
- **System Audio Capture**: Powers the live audio spectrum visualizer inside `OrielHelper.xpc`.

Running `scripts/setup_signing_cert.sh` signs builds with a stable local certificate (`Oriel Local Signing`) instead of an ad-hoc signature, keeping granted TCC permissions valid across updates.

## License

MIT — see [LICENSE](LICENSE).
