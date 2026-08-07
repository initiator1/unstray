# Panel placement — what was actually wrong

2026-08-05. Third attempt at "the panel appears in the wrong place / cut off".

## Method

Measure first. The two previous attempts each fixed a mechanism someone had
reasoned their way to, and both left the bug in place. This time nothing was
changed until real geometry had been dumped.

## What was measured

A probe was built that creates a real `NSStatusItem` and a real `NSPopover` of
the real panel size, then dumps `NSWindow.frame`, `CGWindowListCopyWindowInfo`
bounds, and every `NSScreen.frame` / `visibleFrame` side by side.

Four facts came out of it, all numbers, none of them guessed:

1. **The menu-bar icon is parked off every screen.** Bartender 6 has
   `llc.initiator.unstray-Item-0` in its `Hide` list. A hidden item's window sits
   at **x = -10094** (it drifts a little between runs: -10093, -10111, -10127) —
   8,000pt+ left of the leftmost display — while `statusItem.isVisible` still
   reports `true`.

2. **Read too early, the same frame is `(0, 0, 28, 0)`.** Zero height, and its
   corner is inside the primary screen, so a plain `frame.contains(origin)` says
   "yes, primary" with confidence.

3. **`popover.show(relativeTo:of:)` against that parked icon makes AppKit rescue
   the panel to the far edge of the display arrangement** — measured at x = 0 on
   a single display, i.e. hard against the left edge, nowhere near the menu bar.

4. **The popover window carries 13pt of transparent shadow on every side**
   (406x656 of window around 380x630 of panel). The old clamp treated that
   shadow as panel, so it shoved a correctly placed panel 3pt down the screen on
   every single open.

## Root cause

The clamp arithmetic was right. Its **input** was garbage.

`clampPanel()` passed `statusItem.button?.window?.frame.origin` to
`PanelPlacement.screen(forAnchor:)`, whose entire job was "the screen the
menu-bar icon is on". With the icon parked at x = -10094 no screen contains that
point, so the function silently fell through to its next rule: infer the screen
from the panel's own top-left corner. That is circular — the panel's position is
the thing that is wrong — and it means the clamp confidently clamped into
whichever screen the misplaced panel had already landed on, ratifying the
mistake instead of correcting it.

## The fix

- `PanelPlacement.isUsableAnchor` — an anchor must be non-empty and its centre
  must be on some display. Rejects both measured bad states.
- `PanelPlacement.targetDisplay` — icon (if usable), then the pointer, then the
  primary. The panel's own position is no longer consulted at all.
- `PanelPlacement.fallbackAnchor` — when the icon is hidden, the panel hangs
  from a point we choose: under the menu bar at the right of the screen the
  person is on.
- `App.panelAnchor()` — hangs the popover off a 1x1 invisible stand-in window at
  that point, so AppKit is never asked to rescue anything.
- `PanelPlacement.clamp` now takes the shadow inset, so only the visible panel
  has to respect the margin.
- `PanelPlacement.Display` — plain rectangles, so a three-monitor desk is
  testable on a laptop with nothing plugged in.

## Deprecation pass

| System | Disposition |
|---|---|
| `PanelPlacement.clamp` | REFACTOR — same name and shape, shadow-aware |
| `PanelPlacement.screen(forAnchor:panel:screens:)` | DELETE — replaced by `targetDisplay`; its "guess from the panel's own position" rules were the bug |
| `clampPanel` copy in `tests/CoreTests.swift` | DELETE — the real code is compiled in now |
| `WindowScan.screenUnderCursor()` | KEEP UNCHANGED — different question (where to put a *rescued* window), different precedence; no overlap worth merging |
| `App.clampPanel()` | REFACTOR — same role, validated screen, shadow-aware |

## Live proof, two real displays (2026-08-06)

Built-in `(0, 0, 1496, 967)`, visible to `y=937`. INSIGNIA-TV
`(1496, -113, 1920, 1080)`. The dead zone is `x 0..1496, y -113..0` — beside the
TV, below the built-in, on no display at all.

With the icon parked at its measured hidden position `(-10094, 937, 28, 30)`:

| | Where the panel landed |
|---|---|
| **Before** | AppKit dropped it at `x=0`, hard against the far-left edge of the whole arrangement. The old clamp then "corrected" it to `x=8..414` on the built-in and called it contained. |
| **After**, person on the built-in | `x=1103..1483` — top-right of the built-in. Contained. |
| **After**, person on the TV | `x=3023..3403` — top-right of the TV. Contained. |

Worth being exact about the failure: in *this* arrangement the old code did not
crop the panel, it put it in the wrong place — the far-left edge of the leftmost
monitor, regardless of which screen the person was using. Cropping is the variant
that shows up when AppKit's rescue point or a visible icon sits next to a dead
zone; that half is covered by the 96-position test sweep. Both are the same root
cause: an anchor that is on no screen.

---

# "You clicked ChatGPT and nothing came up" — a false positive

2026-08-06. Reported with a screenshot: the panel said ChatGPT had nothing to
show, and ChatGPT's window appeared on another screen about a second later. He
had clicked Update in ChatGPT's own updater, which installed and relaunched it.

## What was wrong

`Usability.isStillStartingUp(app)` already existed, and its own comment says it
"covers the launch and relaunch cases, including in-app updaters that quit and
immediately restart themselves". It was wired into exactly one branch of
`Usability.problem(for:)` — the `.notResponding` one, fixed in f656935 after the
same thing happened to Claude during *its* Restart to Update.

`.nothingToShow` never consulted it. That branch asked for a window, waited a
flat 1.0s, and spoke. With the 0.7s settle delay that is 1.7s from the app coming
forward. ChatGPT needed about 2.7s.

Both halves of the update produce the accusation: the old process terminates
(and `confirm()` never checked `isTerminated`, so a dead app answers every
question wrongly), and the new process comes forward with no window yet.

## The fix

`EmptyAppPatience` — a new, dependency-free file holding the decision as a pure
function, the same shape as `PanelPlacement`. On each look it returns `goQuiet`,
`keepWaiting`, `askForAWindow` or `speak`. Ordinary explanations are ruled out
first: terminated, a window appeared, the person moved on, still starting up.
Only then does it ask, and only after a grace period does it speak. `confirm()`
got the same two guards for the `.hidden` and `.titleBarOutOfReach` paths.

A starting app now gets ~18.7s before it can be called broken, against 1.7s.

Two mutations confirm the tests fail when the code is wrong: restoring the
shipped behaviour (never consulting startup) fails 2, and speaking without having
asked fails 2.

## Still open

The panel's last line is "Quitting ChatGPT and opening it again usually sorts it
out", and the button below it says "Try again for me" — which does **not** quit;
it asks the app for a window again. A person could reasonably read the button as
"quit and reopen it for me". Copy is Douglas's call, so it is flagged, not
changed.

## Deprecation pass (second change)

| System | Disposition |
|---|---|
| `EmptyAppWatch.confirm()` for `.nothingToShow` | DELETE — replaced by `watchForWindow`; the flat 1.0s was the bug |
| `EmptyAppWatch.confirm()` for `.hidden` / `.titleBarOutOfReach` | KEEP AS LEAF — same two guards added, otherwise unchanged |
| `EmptyAppWatch.showsNothing(pid:)` | REFACTOR — takes the app and counts the whole process family, so an Electron helper's window rescues its app |
| `Usability.isStillStartingUp` | KEEP UNCHANGED — it was right; only its wiring was missing |
| `EmptyAppWatch.watchForRecovery` | KEEP UNCHANGED — the `.notResponding` equivalent, already correct |

## Deviations

- ~~Could not reproduce on the real multi-display rig.~~ **Cleared 2026-08-06.**
  A second display (INSIGNIA-TV, 1920x1080 at AppKit `(1496, -113)`, beside a
  1496x967 built-in) came online and the A/B was rerun live. See below.
- **Could not drive the shipped app's panel end to end.** The icon is hidden by
  Bartender, and clicking it or sending the hotkey needs Accessibility permission
  for the driving process, which is Douglas's to grant. The probe exercises the
  same `PanelPlacement` code, compiled in, against the same parked status item on
  real AppKit.
- **Did not touch Bartender's configuration.** Unhiding unstray would have made
  the bug disappear without fixing it, and it is his menu bar.
- **The ChatGPT false positive was not reproduced live.** Reproducing it needs an
  app to be mid-update at the moment it comes forward. The timeline was
  reconstructed from the shipped constants (0.7s settle + 1.0s confirm = 1.7s)
  against the reported ~2.7s, and the decision is now covered by tests that fail
  when the old behaviour is restored.
