#!/usr/bin/env bash
set -euo pipefail

PACKAGE_ONLY=false
if [[ "${1:-}" == "--package-only" ]]; then
    PACKAGE_ONLY=true
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
APP_NAME="Oriel"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
XPC_BUNDLE="${APP_BUNDLE}/Contents/XPCServices/OrielHelper.xpc"
ASSETS_DIR="${ROOT_DIR}/Resources"

mkdir -p "${BUILD_DIR}" "${ASSETS_DIR}/Sounds"

echo "==> Generating AppIcon.icns..."
ICONSET_DIR="${BUILD_DIR}/AppIcon.iconset"
rm -rf "${ICONSET_DIR}"
mkdir -p "${ICONSET_DIR}"

BASE_ICON_PNG="${BUILD_DIR}/icon_1024.png"
swift - <<'SWIFT' "${BASE_ICON_PNG}"
import AppKit
import Foundation

let outPath = CommandLine.arguments[1]
let size = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let rect = NSRect(x: 0, y: 0, width: size, height: size)
let squircle = NSBezierPath(roundedRect: rect.insetBy(dx: 56, dy: 56), xRadius: 215, yRadius: 215)

// Dark smoked background gradient
let bgGrad = NSGradient(colors: [
    NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.15, alpha: 1.0),
    NSColor(calibratedRed: 0.03, green: 0.03, blue: 0.04, alpha: 1.0)
])!
bgGrad.draw(in: squircle, angle: -90)

NSColor(calibratedWhite: 1.0, alpha: 0.14).setStroke()
squircle.lineWidth = 6
squircle.stroke()

// Signature Notch Silhouette centered near upper third
let notchRect = NSRect(x: 222, y: 540, width: 580, height: 150)
let notchPath = NSBezierPath(roundedRect: notchRect, xRadius: 48, yRadius: 48)
NSColor.black.setFill()
notchPath.fill()

NSColor(calibratedRed: 0.18, green: 0.83, blue: 0.75, alpha: 0.75).setStroke()
notchPath.lineWidth = 5
notchPath.stroke()

// Album dot on left & 6-bar teal waveform on right
let artRect = NSRect(x: 266, y: 575, width: 80, height: 80)
let artPath = NSBezierPath(roundedRect: artRect, xRadius: 18, yRadius: 18)
let artGrad = NSGradient(colors: [
    NSColor(calibratedRed: 0.18, green: 0.83, blue: 0.75, alpha: 1.0),
    NSColor(calibratedRed: 0.35, green: 0.65, blue: 0.98, alpha: 1.0)
])!
artGrad.draw(in: artPath, angle: 45)

let heights: [CGFloat] = [28, 56, 40, 74, 52, 32]
for (idx, h) in heights.enumerated() {
    let bx = CGFloat(624 + idx * 24)
    let by = 615.0 - h / 2.0
    let bar = NSBezierPath(roundedRect: NSRect(x: bx, y: by, width: 14, height: h), xRadius: 7, yRadius: 7)
    NSColor(calibratedRed: 0.18, green: 0.83, blue: 0.75, alpha: 1.0).setFill()
    bar.fill()
}

NSGraphicsContext.restoreGraphicsState()
if let data = rep.representation(using: .png, properties: [:]) {
    try? data.write(to: URL(fileURLWithPath: outPath))
}
SWIFT

for sz in 16 32 128 256 512; do
    sips -z $sz $sz "${BASE_ICON_PNG}" --out "${ICONSET_DIR}/icon_${sz}x${sz}.png" >/dev/null
    dbl=$((sz * 2))
    sips -z $dbl $dbl "${BASE_ICON_PNG}" --out "${ICONSET_DIR}/icon_${sz}x${sz}@2x.png" >/dev/null
done

iconutil -c icns "${ICONSET_DIR}" -o "${ASSETS_DIR}/AppIcon.icns"

echo "==> Synthesizing UI sounds..."
python3 - <<'PY' "${ASSETS_DIR}/Sounds"
import math, os, struct, sys, wave

out_dir = sys.argv[1]
sr = 44100

def write_tone(name, notes, duration=0.14, gain=0.22):
    path = os.path.join(out_dir, f"{name}.wav")
    total_samples = int(sr * duration)
    buf = []
    for i in range(total_samples):
        t = i / sr
        env = math.sin(math.pi * min(1.0, t / 0.012)) * math.exp(-5.5 * (t / duration))
        val = 0.0
        for idx, (freq, amp) in enumerate(notes):
            val += amp * math.sin(2.0 * math.pi * freq * t)
        sample = max(-1.0, min(1.0, val * env * gain))
        buf.append(struct.pack("<h", int(sample * 32767)))
    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        wf.writeframes(b"".join(buf))

write_tone("chime", [(880, 0.6), (1318.5, 0.4)], duration=0.35, gain=0.20)
write_tone("event", [(659.25, 0.55), (987.77, 0.45)], duration=0.28, gain=0.20)
write_tone("haptic", [(180, 0.8), (320, 0.2)], duration=0.04, gain=0.12)
write_tone("lock", [(523.25, 0.7), (392.0, 0.3)], duration=0.12, gain=0.18)
write_tone("unlock", [(523.25, 0.4), (783.99, 0.6)], duration=0.14, gain=0.18)
write_tone("low-battery", [(330.0, 0.7), (261.63, 0.3)], duration=0.24, gain=0.22)
write_tone("low-power", [(392.0, 0.6), (329.63, 0.4)], duration=0.20, gain=0.18)
write_tone("sleep", [(440.0, 0.5), (554.37, 0.5)], duration=0.32, gain=0.16)
write_tone("volume", [(740.0, 0.85), (1480.0, 0.15)], duration=0.055, gain=0.14)
write_tone("directions", [(587.33, 0.5), (880.0, 0.5)], duration=0.28, gain=0.20)
PY

echo "==> Building release targets with SwiftPM..."
cd "${ROOT_DIR}"
SDK_FLAGS=()
if [[ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" ]]; then
    export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
    SDK_FLAGS=(--sdk "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk")
fi
swift build -c release "${SDK_FLAGS[@]}"

BIN_DIR="$(swift build -c release "${SDK_FLAGS[@]}" --show-bin-path)"

echo "==> Assembling ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" \
         "${APP_BUNDLE}/Contents/Resources" \
         "${XPC_BUNDLE}/Contents/MacOS"

cp "${BIN_DIR}/Oriel" "${APP_BUNDLE}/Contents/MacOS/Oriel"
cp "${BIN_DIR}/OrielHelper" "${XPC_BUNDLE}/Contents/MacOS/OrielHelper"
cp "${ASSETS_DIR}/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
cp "${ASSETS_DIR}/Sounds/"*.wav "${APP_BUNDLE}/Contents/Resources/"

cat > "${APP_BUNDLE}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Oriel</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.oriel.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Oriel</string>
    <key>CFBundleDisplayName</key>
    <string>Oriel</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>100</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Oriel uses Automation to control Music, Spotify, and browser media playback.</string>
    <key>NSAudioCaptureUsageDescription</key>
    <string>Oriel uses system audio capture to display the live 6-band music spectrum.</string>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>Oriel uses Bluetooth to show headphone and AirPods connection banners.</string>
    <key>NSCalendarsUsageDescription</key>
    <string>Oriel reads your calendars to display upcoming events and meeting join links in the notch.</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>Oriel reads your calendars to display upcoming events and meeting join links in the notch.</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>Oriel uses your location for local weather and time-to-leave estimates.</string>
</dict>
</plist>
PLIST

cat > "${XPC_BUNDLE}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>OrielHelper</string>
    <key>CFBundleIdentifier</key>
    <string>com.oriel.app.helper</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>OrielHelper</string>
    <key>CFBundlePackageType</key>
    <string>XPC!</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>XPCService</key>
    <dict>
        <key>ServiceType</key>
        <string>Application</string>
    </dict>
</dict>
</plist>
PLIST

chmod +x "${APP_BUNDLE}/Contents/MacOS/Oriel" "${XPC_BUNDLE}/Contents/MacOS/OrielHelper"

if [[ "${PACKAGE_ONLY}" == "true" ]]; then
    echo "==> Applying distributable ad-hoc signature for public archive..."
    codesign --force --sign - "${XPC_BUNDLE}"
    codesign --force --sign - "${APP_BUNDLE}"
else
    echo "==> Ensuring persistent local code signing identity..."
    SIGN_IDENTITY="${ORIEL_SIGN_IDENTITY:-Oriel Local Signing}"
    "${ROOT_DIR}/scripts/setup_signing_cert.sh" || true

    if security find-certificate -c "${SIGN_IDENTITY}" "${HOME}/Library/Keychains/login.keychain-db" >/dev/null 2>&1; then
        echo "==> Code signing bundle with persistent identity '${SIGN_IDENTITY}'..."
        codesign --force --sign "${SIGN_IDENTITY}" "${XPC_BUNDLE}"
        codesign --force --sign "${SIGN_IDENTITY}" "${APP_BUNDLE}"
    else
        echo "==> Falling back to ad-hoc signing..."
        codesign --force --sign - "${XPC_BUNDLE}"
        codesign --force --sign - "${APP_BUNDLE}"
    fi
fi

# Package distributable .zip and .dmg
DMG_STAGING="${BUILD_DIR}/dmg_staging"
DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"
ZIP_PATH="${BUILD_DIR}/${APP_NAME}.zip"
rm -rf "${DMG_STAGING}" "${DMG_PATH}" "${ZIP_PATH}"
mkdir -p "${DMG_STAGING}"
ditto "${APP_BUNDLE}" "${DMG_STAGING}/${APP_NAME}.app"
ln -s /Applications "${DMG_STAGING}/Applications"

echo "==> Packaging ${ZIP_PATH} & ${DMG_PATH}..."
ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_STAGING}" -ov -format UDZO "${DMG_PATH}" >/dev/null
rm -rf "${DMG_STAGING}"

if [[ "${PACKAGE_ONLY}" == "true" ]]; then
    echo "==> Package ready: ${DMG_PATH} & ${ZIP_PATH}"
    exit 0
fi

INSTALL_BUNDLE="/Applications/${APP_NAME}.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

echo "==> Installing canonical app bundle to ${INSTALL_BUNDLE}..."
if [[ -x "${LSREGISTER}" ]]; then
    "${LSREGISTER}" -u "${APP_BUNDLE}" >/dev/null 2>&1 || true
fi

rm -rf "${INSTALL_BUNDLE}"
ditto "${APP_BUNDLE}" "${INSTALL_BUNDLE}"
rm -rf "${APP_BUNDLE}"
ln -s "${INSTALL_BUNDLE}" "${APP_BUNDLE}"

if [[ -x "${LSREGISTER}" ]]; then
    "${LSREGISTER}" -f "${INSTALL_BUNDLE}" >/dev/null 2>&1 || true
fi

echo "==> Built & Installed: ${INSTALL_BUNDLE} (symlinked at ${APP_BUNDLE})"
