# CLAUDE.md — unstray

A macOS menu-bar app that notices when the Mac has hidden something from you,
brings it back, and explains what happened in words a person who has barely used
a computer can understand.

For product context see [SPEC.md](SPEC.md). For architecture see [PLAN.md](PLAN.md).
The voice rules are binding: [docs/plain-language.md](docs/plain-language.md).
Launch strategy and copy are kept out of the public repo, in `.internal/`.

## Run and build

```bash
./build.sh                  # -> build/unstray.app
open build/unstray.app
```

```bash
./run-tests.sh              # 40 core logic tests, ~1 second
./build.sh --notarize       # release build; needs the `unstray` keychain profile
```

**Releasing:** notarize BEFORE zipping, and verify the ticket survives the zip
round-trip. `build/` is disposable — anything that rebuilds it (a fresh-clone
test, a plain `./build.sh`) drops the stapled ticket, and v0.1 was briefly
published un-notarized for exactly that reason. Always `xcrun stapler validate`
the extracted zip before uploading.

No Xcode project — `swiftc` straight to a bundle. A menu-bar app does not need
more, and the repo stays readable. **New source files must be added to
`build.sh` by hand**; there is no target to fall back on.

Requires Accessibility permission (System Settings → Privacy & Security →
Accessibility). Without it, settings checks still run; only window rescue is
gated.

## Architecture

```
unstray/Core/
  Finding.swift          Finding + Verdict. Every user-facing string lives here.
  SettingsCheck.swift    The three load-bearing macOS settings.
  WindowScan.swift       Finds windows no screen can reach.
  WindowRescue.swift     Moves them back. AX + the Carbon shim.
  LegacyActivation.{h,c} C shim for SetFrontProcessWithOptions.
  RepairLog.swift        JSONL to ~/.unstray/events.jsonl (local only).
  Lifecycle.swift        Launch at login; macOS-update detection.
unstray/UI/
  Design.swift           Palette, type, the one button style.
  ScreenDiagram.swift    The signature element: your real screens, to scale.
  VerdictView.swift      Healthy and problem panels.
  PermissionPanel.swift  Asking for Accessibility without frightening anyone.
unstray/App.swift        Menu bar, hotkey, VerdictModel.
assets/                  App icon (gpt-image-2 via Codex's native image_gen).
                         unstray-1024.png is the master; .icns is built from it.
```

## Icon

Regenerate with Codex's **native `image_gen`** tool (gpt-image-2, runs on the
ChatGPT OAuth, no API key). Never the imagegen skill's `image_gen.py` CLI, and
never hand-rolled SVG/CSS art. After generating, rebuild:

```bash
iconutil -c icns assets/unstray.iconset -o assets/unstray.icns && ./build.sh
```

Direction: dark-matte squircle, deep blue-slate, warm amber thin-line screens
with one rectangle apart being drawn back — same palette as the app itself.
Motif should fill ~80–85% of the tile. Check legibility at 32px.

## The three settings this app watches

All three silently flip during macOS updates. That is the recurring job.

| Setting | Want | Symptom when wrong |
|---|---|---|
| `com.apple.spaces spans-displays` | `0` | Other screens go black on fullscreen |
| `NSGlobalDomain AppleSpacesSwitchOnActivate` | `1` | Click an app, land on an empty screen |
| `com.apple.dock minimize-to-application` | `0` | Shrunk windows vanish with no way back |

## Gotchas

- **Swift cannot import `SetFrontProcessWithOptions`.** Pre-10.9 Carbon symbols
  are unavailable to Swift entirely, not merely deprecated. Hence the C shim.
  Do not "modernise" it: `NSRunningApplication.activate` silently fails from a
  background app (Apple's FB21087054) and `.activateAllWindows` has been broken
  since 10.15 (Apple's FB11974786).
- **AX sees only the current Space; CGWindowList sees all Spaces but cannot
  move anything.** Any real work needs both, correlated.
- **There is no public API to move a window to another Space.** yabai's
  scripting addition needs SIP off plus an NVRAM boot-arg on Tahoe/arm64;
  `hs.spaces.moveWindowToSpace` has been broken upstream since Sonoma 14.5.
  We move the *person* to the window, never the reverse.
- **macOS never tells an app it has been granted Accessibility.** Poll for it.
- **The popover is not a standard AX window** (layer 25), so `System Events`
  cannot click it and synthetic clicks are blocked. Verify UI by screenshot:
  find the frame via CGWindowList, then `screencapture -D 1` + `sips -c`.
- **Menu-bar helpers have `activationPolicy != .regular`.** Filter them or the
  scan reports false positives — an early version flagged eight non-problems.
- **A hidden menu-bar icon is parked off every screen, and still says it is
  visible.** Bartender (and macOS's own overflow) move a hidden `NSStatusItem`'s
  window to x ≈ -10094 while `statusItem.isVisible` stays `true`. Read too early
  the same frame is `(0, 0, 28, 0)` — zero height, corner inside the primary
  screen, so `contains()` says yes. Never hang a popover off that window and
  never pick a screen from it without `PanelPlacement.isUsableAnchor`. This was
  the third and real cause of the panel appearing in the wrong place.
- **An NSPopover window is 13pt bigger than its panel on every side** (406x656
  around 380x630). Clamp the panel, not the window, or a correctly placed panel
  gets nudged on every open.
- **An app that is opening is indistinguishable from a broken one.** No window,
  not answering, no menu bar — that is a launch, a relaunch, and an in-app
  updater's "Restart to Update", as much as it is the bug. Only elapsed time
  tells them apart, so every path that accuses an app must consult
  `Usability.isStillStartingUp` and `app.isTerminated` first. This has now been
  got wrong twice, on two different branches of the same switch.

## House rules that bite here

- Every user-facing string passes `docs/plain-language.md`. No coordinates, no
  error codes, no Feedback numbers on screen — those go in the log.
- Dark theme, Outfit (100 large / 200 medium / 300 small).
- No private APIs, no SIP disabling. Surviving macOS 27 is the point.
- Every UI element delivers what its label promises. No stubs.

## Deprecation notes

Nothing deprecated or shimmed yet beyond `LegacyActivation.c`, which is
deliberate and documented in its own header.
