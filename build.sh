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
  foremac/UI/Design.swift \
  foremac/UI/ScreenDiagram.swift \
  foremac/UI/PermissionPanel.swift \
  foremac/UI/VerdictView.swift \
  foremac/App.swift

# Bundle Outfit so the app looks right on a Mac that does not have it installed.
if [ -f "$HOME/Library/Fonts/Outfit-VariableFont_wght.ttf" ]; then
  cp "$HOME/Library/Fonts/Outfit-VariableFont_wght.ttf" "$APP/Contents/Resources/"
  /usr/libexec/PlistBuddy -c "Add :ATSApplicationFontsPath string ." "$APP/Contents/Info.plist" 2>/dev/null || true
fi

codesign --force --deep --sign - "$APP" 2>/dev/null || true
echo "built: $APP"
