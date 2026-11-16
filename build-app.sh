#!/bin/bash
# Packages the SPM release build into a proper macOS .app bundle.
# Usage: ./build-app.sh
set -euo pipefail

cd "$(dirname "$0")"

echo "→ Building release binary…"
swift build -c release

APP="build/ByeBye Bytes.app"
BIN="$(swift build -c release --show-bin-path)/ByeByeBytes"

# Regenerate the icon if sources exist but the .icns is missing.
if [ ! -f Resources/AppIcon.icns ] && [ -f Scripts/generate-icon.swift ]; then
    echo "→ Generating AppIcon"
    swift Scripts/generate-icon.swift
fi

echo "→ Assembling bundle at $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ByeBye Bytes"
cp App.Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

# Try to compile the Liquid Glass Assets.xcassets (Tahoe dark/tinted/clear).
# Requires Xcode's actool, which needs:  sudo xcodebuild -license accept && sudo xcodebuild -runFirstLaunch
if [ -d Resources/Assets.xcassets ] && [ -d /Applications/Xcode.app ]; then
    ACTOOL="/Applications/Xcode.app/Contents/Developer/usr/bin/actool"
    if [ -x "$ACTOOL" ]; then
        echo "→ Compiling Assets.xcassets (Liquid Glass)…"
        if DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer "$ACTOOL" \
                --compile "$APP/Contents/Resources" \
                --platform macosx \
                --minimum-deployment-target 14.0 \
                --app-icon AppIcon \
                --output-partial-info-plist /tmp/byebyebytes-partial.plist \
                Resources/Assets.xcassets > /tmp/byebyebytes-actool.log 2>&1; then
            echo "  ✓ Assets.car emitted"
        else
            echo "  ⚠ actool failed — falling back to flat .icns"
            echo "    To enable Tahoe Liquid Glass icons, run once:"
            echo "      sudo xcodebuild -license accept"
            echo "      sudo xcodebuild -runFirstLaunch"
            echo "    Then rebuild. (log: /tmp/byebyebytes-actool.log)"
        fi
    fi
fi

PLIST="$APP/Contents/Info.plist"
plutil -replace CFBundleDevelopmentRegion -string "en"                "$PLIST"
plutil -replace CFBundleExecutable         -string "ByeBye Bytes"     "$PLIST"
plutil -replace CFBundleIdentifier         -string "com.byebyebytes.app" "$PLIST"
plutil -replace CFBundleShortVersionString -string "1.0.1"            "$PLIST"
plutil -replace CFBundleVersion            -string "1"                "$PLIST"
plutil -replace LSMinimumSystemVersion     -string "14.0"             "$PLIST"

echo "→ Ad-hoc signing with entitlements…"
codesign --force --deep --sign - \
    --entitlements ByeByeBytes.entitlements \
    --options runtime \
    "$APP" >/dev/null

echo "→ Verifying…"
codesign --verify --deep --strict "$APP"
echo "✓ Built $APP"
