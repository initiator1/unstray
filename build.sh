#!/bin/bash
# Builds unstray.app. No Xcode project — swiftc straight to a bundle, which is
# enough for a menu-bar app and keeps the repo readable.
set -e
APP="build/unstray.app"
rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>unstray</string>
  <key>CFBundleDisplayName</key><string>unstray</string>
  <key>CFBundleIdentifier</key><string>llc.initiator.unstray</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>unstray</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>CFBundleIconFile</key><string>unstray</string>
  <key>NSHumanReadableCopyright</key><string>Personal utility</string>
  <!-- Required for the "ask an app to open a window" fallback. Without this key
       macOS silently blocks NSAppleScript and may terminate the app outright. -->
  <key>NSAppleEventsUsageDescription</key><string>unstray asks an app to open a window when you click it and nothing appears.</string>
</dict></plist>
PLIST

echo "#import \"LegacyActivation.h\"" > build/bridge.h

swiftc -O \
  -o "$APP/Contents/MacOS/unstray" \
  -import-objc-header build/bridge.h \
  -I unstray/Core \
  -framework Cocoa -framework SwiftUI -framework Carbon -framework ApplicationServices \
  unstray/Core/LegacyActivation.c \
  unstray/Core/Finding.swift \
  unstray/Core/SettingsCheck.swift \
  unstray/Core/ScreenSpace.swift \
  unstray/Core/WindowUse.swift \
  unstray/Core/WindowScan.swift \
  unstray/Core/WindowRescue.swift \
  unstray/Core/RepairLog.swift \
  unstray/Core/Lifecycle.swift \
  unstray/Core/ActivityWatch.swift \
  unstray/Core/PanelPlacement.swift \
  unstray/Core/WindowlessByDesign.swift \
  unstray/Core/Usability.swift \
  unstray/Core/EmptyAppPatience.swift \
  unstray/Core/EmptyAppWatch.swift \
  unstray/UI/Design.swift \
  unstray/UI/ScreenDiagram.swift \
  unstray/UI/PermissionPanel.swift \
  unstray/UI/VerdictView.swift \
  unstray/App.swift

# App icon (generated with gpt-image-2 via Codex's native image_gen).
if [ -f assets/unstray.icns ]; then
  cp assets/unstray.icns "$APP/Contents/Resources/unstray.icns"
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
# Which identity to sign with.
#
# A team can hold both a personal-name and an organisation certificate. The name
# in the certificate is what a stranger sees in Gatekeeper when they open the
# app, so prefer the organisation one and fall back to whatever exists.
# Override with UNSTRAY_SIGN_ID.
if [ -n "${UNSTRAY_SIGN_ID:-}" ]; then
  SIGN_ID="$UNSTRAY_SIGN_ID"
else
  ALL_IDS=$(security find-identity -v -p codesigning 2>/dev/null \
    | grep -o "Developer ID Application: .*" | sed 's/"$//')
  # An organisation certificate has no comma and is not a personal name; there is
  # no reliable flag for it, so prefer an explicit preference file if present.
  SIGN_ID=$(echo "$ALL_IDS" | grep -i "LLC\|Inc\|Ltd\|GmbH\|Corp" | head -1)
  [ -z "$SIGN_ID" ] && SIGN_ID=$(echo "$ALL_IDS" | head -1)
fi

if [ -n "$SIGN_ID" ] && security find-identity -v -p codesigning 2>/dev/null | grep -qF "$SIGN_ID"; then
  codesign --force --deep --options runtime --sign "$SIGN_ID" "$APP"
  echo "signed with: $SIGN_ID"
else
  # Ad-hoc fallback. Never swallow the failure: an unsigned bundle that reports
  # "built" is exactly the kind of silent failure this app exists to fix.
  if ! codesign --force --deep --sign - "$APP"; then
    echo "ERROR: code signing failed — refusing to ship an unsigned bundle" >&2
    exit 1
  fi
  echo "WARNING: signed ad-hoc — Accessibility permission will be revoked on every rebuild"
fi

# Prove it actually got signed rather than trusting the exit code alone.
if ! codesign --verify --deep --strict "$APP" 2>/dev/null; then
  echo "ERROR: signature verification failed" >&2
  exit 1
fi
echo "built: $APP"

# ---------------------------------------------------------------------------
# Notarization (optional, required for public distribution)
#
# Apple requires notarization for any app distributed outside the Mac App Store.
# Without it, macOS 26 shows a hard block and the only way in is System Settings
# > Privacy & Security > "Open Anyway" — the right-click bypass was removed in
# Sequoia. Homebrew also removes non-notarized casks from the official tap in
# September 2026.
#
# One-time setup (needs an app-specific password from appleid.apple.com):
#   xcrun notarytool store-credentials unstray \
#     --apple-id "you@example.com" --team-id TEAMID --password "app-specific-pw"
#
# Then:  ./build.sh --notarize
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--notarize" ]; then
  echo "==> notarizing (this takes a few minutes)"
  ZIP="build/unstray.zip"
  ditto -c -k --keepParent "$APP" "$ZIP"
  xcrun notarytool submit "$ZIP" --keychain-profile "unstray" --wait
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP" && echo "==> notarized and stapled"
  rm -f "$ZIP"
fi
