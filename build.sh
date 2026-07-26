#!/bin/bash
# Builds foremac.app. No Xcode project — swiftc straight to a bundle, which is
# enough for a menu-bar app and keeps the repo readable.
set -e
APP="build/foremac.app"
rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>foremac</string>
  <key>CFBundleDisplayName</key><string>foremac</string>
  <key>CFBundleIdentifier</key><string>com.db1.foremac</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>foremac</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>CFBundleIconFile</key><string>foremac</string>
  <key>NSHumanReadableCopyright</key><string>Personal utility</string>
</dict></plist>
PLIST

echo "#import \"LegacyActivation.h\"" > build/bridge.h

swiftc -O \
  -o "$APP/Contents/MacOS/foremac" \
  -import-objc-header build/bridge.h \
  -I foremac/Core \
  -framework Cocoa -framework SwiftUI -framework Carbon -framework ApplicationServices \
  foremac/Core/LegacyActivation.c \
  foremac/Core/Finding.swift \
  foremac/Core/SettingsCheck.swift \
  foremac/Core/WindowScan.swift \
  foremac/Core/WindowRescue.swift \
  foremac/Core/RepairLog.swift \
  foremac/Core/Lifecycle.swift \
  foremac/UI/Design.swift \
  foremac/UI/ScreenDiagram.swift \
  foremac/UI/PermissionPanel.swift \
  foremac/UI/VerdictView.swift \
  foremac/App.swift

# App icon (generated with gpt-image-2 via Codex's native image_gen).
if [ -f assets/foremac.icns ]; then
  cp assets/foremac.icns "$APP/Contents/Resources/foremac.icns"
fi

# Bundle Outfit so the app looks right on a Mac that does not have it installed.
if [ -f "$HOME/Library/Fonts/Outfit-VariableFont_wght.ttf" ]; then
  cp "$HOME/Library/Fonts/Outfit-VariableFont_wght.ttf" "$APP/Contents/Resources/"
  /usr/libexec/PlistBuddy -c "Add :ATSApplicationFontsPath string ." "$APP/Contents/Info.plist" 2>/dev/null || true
fi

# Sign with a stable identity, not ad-hoc.
#
# An ad-hoc signature gives the app a NEW code identity on every rebuild, so
# macOS quietly revokes the Accessibility permission each time and the app
# silently stops being able to move anything — the precise failure mode this
# app exists to fix. Signing with Developer ID keeps one identity forever, so
# the permission is granted once and stays granted.
SIGN_ID="${FOREMAC_SIGN_ID:-Developer ID Application: Douglas Baker (MDWFZC6396)}"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_ID"; then
  codesign --force --deep --options runtime --sign "$SIGN_ID" "$APP"
  echo "signed with: $SIGN_ID"
else
  codesign --force --deep --sign - "$APP" 2>/dev/null || true
  echo "WARNING: signed ad-hoc — Accessibility permission will be revoked on every rebuild"
fi
echo "built: $APP"
