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
./run-tests.sh              # 103 core logic tests, ~1 second
./build.sh --notarize       # release build; needs the `unstray` keychain profile
```

**Releasing:** `./tag-release.sh` runs the checks and creates the tag. It does
local work only — it never pushes and never publishes, and it prints the
remaining steps in order. Bump `CFBundleShortVersionString` and `CFBundleVersion`
in `build.sh` first, and **date the changelog heading** — `## 0.2 — unreleased`
becomes `## 0.2 — YYYY-MM-DD`. That heading stayed "unreleased" for three weeks after
v0.1 shipped, so a later entry landed inside a version that was already out.
The README deliberately says "Download unstray" with no number; do not put one
back, because it points at `releases/latest` and would be wrong between the bump
and the upload.

**Tags are annotated and must be ancestors of `main`; `tag-release.sh` enforces
both.** `v0.1` is neither. It was tagged on a commit that a later history
rewrite replaced, so it sits on a parallel line and `git log v0.1..main` lists
the whole project — a report built on that range was wrong by 34 commits. The
real v0.1 release point on `main` is `17c30cf`, identical tree, different sha.
**Leave that tag alone.** Deleting or force-moving a tag that carries a
published GitHub release converts the release to a draft, and `v0.1` has a live
asset with real downloads. It stops mattering the moment `v0.2` is tagged
correctly.

Notarize BEFORE zipping, and verify the ticket survives the zip
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
  ProblemFate.swift      Is a problem we already reported still true? Pure.
  OpenProblems.swift     Re-checks problems the watcher has already reported.
  SettingsCheck.swift    The three load-bearing macOS settings.
  ScreenSpace.swift      Converts coordinates and works with rectangles.
  WindowUse.swift        Decides whether a person can use one window where it is.
  WindowScan.swift       Finds windows beyond or mostly past a screen edge.
  WindowRescue.swift     Moves them back. AX + the Carbon shim.
  LegacyActivation.{h,c} C shim for SetFrontProcessWithOptions.
  WindowlessByDesign.swift  Apps started with --headless. Never accuse these.
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

`assets/unstray-1024.png` is the master. Everything else is built from it:

```bash
./assets/make-icns.sh && ./build.sh
```

Regenerate the master with Codex's **native `image_gen`** tool (gpt-image-2, runs
on the ChatGPT OAuth, no API key). Never the imagegen skill's `image_gen.py` CLI,
and never hand-rolled SVG/CSS art.

**Direction:** the house lane shared with VoiceMac, StayZero and EavesJam —
dark-matte squircle, near-black with a soft vignette, and a motif in sculpted
warm gold with a bevel, a champagne-to-amber gradient, an inner glow and a soft
drop shadow. Not flat outlines. The subject is one large screen and one small
stray screen being drawn back along a curved trail. Motif fills ~70–75% of the
tile.

**One dominant silhouette, and check it at 32px.** Every icon in that lane is a
single strong shape — one M, one O, one bookmark — which is why they survive in
the Dock. The first attempt here used three rectangles of similar weight that
merged into a lump at 32px, and Codex reported them as "distinct" when they were
not. Downscale it and look yourself; a generator's own legibility check is a
claim, not a result.

**The build fails if the icns is missing, on purpose.** `Info.plist` names the
file, so a bundle without it gets a blank Dock tile and macOS says nothing. That
guard used to be `if [ -f ... ]`, which skipped silently — and **v0.1 shipped
publicly with no icon at all** because the assets were still named `foremac`
after the project was renamed and nothing ever complained.

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
  Do not "modernise" it. Three measured reasons, not one:
  `NSRunningApplication.activate` silently fails from a background app (Apple's
  FB21087054); `.activateAllWindows` has been broken since 10.15 (Apple's
  FB11974786); and — measured 2026-08-14 — **the Carbon call ignores
  `AppleSpacesSwitchOnActivate`, while the modern call obeys it.** With that
  setting off, modern activation left us behind (never carried, 2s), and the
  Carbon path carried us over in 382ms and completed the rescue. So the rescue
  keeps working on a Mac whose settings are in the exact broken state this app
  exists to report. Swapping in the modern call would silently couple the fix
  to the bug.
- **Writing `AppleSpacesSwitchOnActivate` takes effect at once.** No logout, no
  Dock restart — measured in both directions on 2026-08-14 with nothing
  restarted. So `checkAppsWontComeForward`'s `costWarning: nil` is honest, and
  its repair really is done when the button returns. Do not add a logout warning
  to it by analogy with `spans-displays`, which genuinely needs one.
- **AX sees only the current Space; CGWindowList sees all Spaces but cannot
  move anything.** Any real work needs both, correlated.
- **Window and screen rectangles use opposite vertical coordinates.**
  CGWindowList and AX measure down from the primary top-left. NSScreen measures
  up from the primary bottom-left. Every comparison must go through
  `ScreenSpace`.
- **The app has twice shipped a check that accepted an unusable window.**
  CotEditor left a 26pt strip, and Epson left a 40pt sliver. `WindowUse` is the
  only place that answers "can a person use this". Route each new check through
  it rather than beside it.
- **Never report a window you cannot move.** Because AX reaches only the current
  Space, an edge-pushed window one screenful over is untouchable, and offering
  "Slide it back" for it puts a button on screen that does nothing forever —
  the exact failure this app exists to remove. `kCGWindowIsOnscreen` is the test
  that separates them. Read it as "AX can reach this", never as a claim about
  pixels — a window sitting squarely in the middle of the screen can report
  `false`, and one with 40pt of 509 showing can report `true`. Do not try to
  predict it either: creating a second, unrelated window in the same app flipped
  the first from `true` to `false` while it had not moved a point. What has held
  in every measurement, in both directions, is the only thing the code relies on:
  `true` exactly when the accessibility layer can see and move the window.
  Confirmed again on 2026-08-14 from the far end: a window parked at x = -12000,
  off every screen, still reported `true` while it sat on the current screenful,
  and `false` the moment a fullscreen window put a different screenful in front.
  Applied to the edge case only. **The stranded scan deliberately does not use
  it, and that is not an oversight** — see the next entry.
- **Bringing an app forward is what carries the person to its screenful, and
  that takes about a third of a second.** Two things were measured on
  2026-08-14 that the code had assumed the opposite of:
  - The accessibility layer answers for an app that is **not** frontmost, as
    long as the window is on the current screenful. Activation is not what
    makes a window visible to AX; being on this screenful is.
  - When the window is one screenful away, activation moves the person there,
    and AX returns *nothing at all* until that move finishes. First answer at
    350ms. At the 120ms the rescue used to wait, five runs out of five saw no
    windows; a further 148–498ms saw the window every time.

  So a fixed wait is a race, and losing it is silent: no windows, nothing moved,
  nothing said. `WindowRescue.reachableWindows` waits for the windows instead of
  for the clock. This is also why the stranded scan reports a window one
  screenful away and is right to — the button brings the person to it. Measured:
  the real "Bring it back" repair, pressed while a fullscreen window held the
  screen, moved a window from x = -12000 back to the middle of the display.
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
- **A headless browser is not a broken one.** `activationPolicy` is the filter
  for menu-bar helpers and it does not catch this: a Chrome started with
  `--headless` gets a Dock icon, takes the menu bar when something activates it,
  and has no window ever. Both repairs then have to fail — the reopen event is
  accepted and ignored, and `make new document` errors because Chrome has no
  documents — so unstray reported a working browser as broken and offered a
  button that could not work. Worse, the policy is not even stable: a headless
  Chrome reads non-`.regular` for its first seconds and `.regular` afterwards,
  so the false alarm came and went. The reliable signal is the command line, read
  via `KERN_PROCARGS2`. Only true headless flags count — `--no-startup-window`
  means "no window at launch", not "no window ever", and such an app does open
  one when asked, so suppressing it would hide the real bug.
- **Anything that launches a headless Chrome hijacks link clicks.** It registers
  as `com.google.Chrome`, so macOS hands it every `open -a "Google Chrome"` and
  every clicked link, and they vanish. Diagnosed 2026-08-13: an automation script
  in another repo left one running, a link went nowhere, and a Chrome update
  produced a second Dock icon because the running process held the old bundle.
- **An app that is opening is indistinguishable from a broken one.** No window,
  not answering, no menu bar — that is a launch, a relaunch, and an in-app
  updater's "Restart to Update", as much as it is the bug. Only elapsed time
  tells them apart, so every path that accuses an app must consult
  `Usability.isStillStartingUp` and `app.isTerminated` first. This has now been
  got wrong twice, on two different branches of the same switch.
- **The money link never shares a panel with a problem.** The support link sits
  in the footer and is drawn only for the all-clear verdict. On the problem
  panel it would read as a price on the repair, and the permission panel is
  spending its whole height earning trust. `VerdictView.showsSupportLink` is
  the one place that decides this.
- **A payment link must be opened and seen before it ships.** The destination is
  `https://ko-fi.com/initiatorworks?app=unstray`, checked live on 2026-08-20.
  **Check that the tip form renders, never the page title** — Douglas renamed
  the page from "Douglas" to "Douglas Baker" mid-week, so a title match would
  have failed on a page that was working perfectly. The earlier
  `ko-fi.com/initiator1` never existed and shipped dead inside another app.
  `curl` is not the check: Ko-fi answers 403 to it from Cloudflare whether the
  page exists or not. Load it in a browser.
- **`app=unstray` is the same in every link in this repo.** One Ko-fi page
  collects for four apps and cannot otherwise tell which one sent a visitor.
  A second spelling in a second file makes the counts wrong rather than absent,
  so change every link together or none. Nothing reads this yet: Ko-fi exposes
  it only through Google Analytics 4, which needs a paid Contributor account.
- **`recheck()` is the only producer of the verdict.** Anything that notices a
  problem records it and asks `recheck()` to decide what to show. It never writes
  the verdict itself. Two authors of one verdict caused three separate bugs.

## House rules that bite here

- Every user-facing string passes `docs/plain-language.md`. No coordinates, no
  error codes, no Feedback numbers on screen — those go in the log.
- Dark theme, Outfit (100 large / 200 medium / 300 small).
- No private APIs, no SIP disabling. Surviving macOS 27 is the point.
- Every UI element delivers what its label promises. No stubs.

## Deprecation notes

Nothing deprecated or shimmed yet beyond `LegacyActivation.c`, which is
deliberate and documented in its own header.
