# PLAN.md — unstray architecture

## Shape

A menu-bar-only app (`LSUIElement`). Most checks follow system events. A narrow
two-second timer reads the frontmost app's window order, so a repeated Dock click
cannot leave a fully covered window unnoticed. The permission poll stops when
permission arrives.

```
AppDelegate ──owns──> VerdictModel ──produces──> Verdict ──renders──> VerdictView
     │                     │                                              │
     │                     ├── SettingsCheck.runAll()  ──> [Finding]      ├─ AllWellPanel
     │                     ├── WindowScan.check*()     ──> Finding?       ├─ ProblemPanel
     │                     ├── OpenProblems.stillTrue() ─> [Problem.Kind] │
     │                     └── WindowRescue            ──> repairs        └─ PermissionPanel
     │
     ├── EmptyAppWatch ──records──> OpenProblems ──asks──> VerdictModel.recheck()
     │        └── WindowOcclusion ──> raise, then center one covered window
     ├── NSStatusItem + NSPopover
     ├── RegisterEventHotKey (⌥⌘R)
     ├── NSWorkspace.didWakeNotification
     ├── NSApplication.didChangeScreenParametersNotification
     └── Lifecycle (launch at login, OS-version drift)
```

## Data model

`Finding` — one thing the Mac is doing to the person.

| Field | Purpose |
|---|---|
| `kind` | `blackDisplays` / `appsWontComeForward` / `hiddenMinimized` / `strandedWindows` / `windowOffTheEdge` |
| `severity` | `nowBroken` < `willBiteLater` — sorts which single problem is shown |
| `headline` | The symptom, in their words |
| `explanation` | Why, in short lines |
| `actionLabel` | A verb they know |
| `costWarning` | Shown *before* the button; nil when free |
| `blamesOSUpdate` | Set when an update caused it |
| `technicalNote` | Log only. Never rendered. |
| `repair` | `() -> Bool` |

`Verdict` — `.needsPermission` | `.allWell` | `.somethingWrong(primary, alsoFound)`.

Precedence in `recheck()`:
1. Any finding → `.somethingWrong` (settings repairs need no permission)
2. Else no permission → `.needsPermission`
3. Else → `.allWell`

Settings checks deliberately run without permission. Gating them would mean
someone who declined never learns their Mac broke something — the same silent
failure the app exists to correct.

`recheck()` is the single verdict producer. The panel pulls fresh settings and
window scans. `EmptyAppWatch` pushes observations into `OpenProblems`, which
re-validates them during the same recheck. A missing permission keeps the last
honest observation. It never becomes an all-clear that the app did not earn.

The panel's "Missing an app?" button opens an app list inside the same panel.
That list selects a running regular app by process ID. It avoids a separate
popup menu whose first click could disappear while the panel resized.
`VerdictModel.findSelectedApp` calls `WindowRescue.gather(pid:)`, then centers
one substantial window on the current screen. This covers windows hidden behind
another app's floating panel even when their bounds are on-screen.
When the app has no window, it sends one reopen request and checks after the
repair settle delay. A persistent problem enters `OpenProblems`; an app with a
window gets a cautious status because window geometry cannot prove which set of
windows the person sees. The panel stays open while the chosen app comes forward.

`WindowOcclusion` first reads ordered on-screen window metadata. It considers
an app covered only when every usable window is at least 95% under a window
from another process. Window alpha describes the whole window, so a transparent
overlay can still appear opaque in this list. A system-wide Accessibility hit
test at interior points vetoes a cover when the target app is reachable there.
It reads no pixels or window titles. `EmptyAppWatch` checks after activation
and every two seconds while the app stays frontmost. It tries raising the app
before moving one window. It waits for the window order to settle before
reporting failure. It ends an automatic warning when the app becomes reachable
or the person switches apps, and closes a panel opened only for that warning.

Repairs trigger an immediate recheck and one settled recheck after one second.
The immediate pass keeps a live problem on screen. The settled pass catches an
app that carries out the repair after the repair call returns.

## The window problem, and why it takes two APIs

| API | Sees all Spaces | Can move things |
|---|---|---|
| `CGWindowListCopyWindowInfo` | yes | no |
| Accessibility (`AXUIElement`) | current Space only | yes |

So: scan with CGWindowList to find what is unreachable, then bring the owning
app frontmost, then move its windows with AX.

Bringing it forward is not what makes the windows visible to AX — measured
2026-08-14, AX answers for an app that is not frontmost, provided the window is
on the current screenful. Activation is what carries the *person* to the
screenful the window is on, and that takes about a third of a second, during
which AX returns nothing for that app. So the rescue waits for the windows, not
for the clock: `WindowRescue.reachableWindows`.

`ScreenSpace` converts every `NSScreen` rectangle and owns rectangle arithmetic.
`WindowUse` then gives every scan and repair one answer about whether a person
can use a window where it is. Its context sets the initial size floor, while the
visible-area bar stays fixed.

Filter `activationPolicy != .regular` or menu-bar helpers register as problems.

## Activation, and the C shim

`NSRunningApplication.activate` uses macOS 14's cooperative model — the frontmost
app must yield. A menu-bar app is never frontmost, so calls silently no-op
(FB21087054). `.activateAllWindows` has been broken since 10.15 (FB11974786).

`SetFrontProcessWithOptions(&psn, 0)` still does both correctly. It is deprecated
but **not private** — no SIP, no boot-args, no scripting addition — so it should
survive OS updates. Swift refuses to import pre-10.9 Carbon symbols, hence
`LegacyActivation.c`. The modern call remains as a fallback.

It does a third thing the modern call does not, measured 2026-08-14: it carries
the person to another screenful even when `AppleSpacesSwitchOnActivate` is off,
which the modern call will not do. That setting is one of the three unstray
watches, so the rescue has to work while it is wrong — otherwise the repair for
the symptom would be disabled by the very fault the app is reporting.

## When it looks

| Trigger | Why |
|---|---|
| Launch | Catches drift from an update that happened while closed |
| Menu-bar click | They came asking |
| ⌥⌘R | They are fighting an app right now |
| Wake from sleep | Reported cause of stranding on Tahoe |
| Screen plugged/unplugged | Biggest single cause; 2s delay to let macOS settle |
| OS version changed | The recurring job |

No Dock-click input watcher. Dock clicks are indistinguishable from Cmd-Tab via
the existing activation event. The two-second frontmost-window check reads only
window bounds and order; it does not record clicks or window contents.

## Rendering

SwiftUI in an `NSPopover`, 380pt wide, height driven by content (374pt healthy,
~580–630pt with a problem).

`D` holds the palette and type. Outfit at 100/200/300 per house rules, bundled
via `ATSApplicationFontsPath`. Motion respects `accessibilityDisplayShouldReduceMotion`.

`ScreenDiagram` draws live `NSScreen` frames to scale — the signature element.
Stray shapes drift outside the bounding box when things are stranded.

## Where the panel goes

`PanelPlacement` owns this, as plain rectangles rather than `NSScreen`, so a
three-monitor desk is testable with nothing plugged in. `run-tests.sh` compiles
it — the tests used to hold a copy of the arithmetic, which meant deleting the
real clamp left every test green.

The order is: the menu-bar icon **if it is genuinely on a screen**, then the
screen the pointer is on, then the primary. The panel's own position is never
consulted — it is the thing that is wrong. When the icon is hidden, the panel
hangs from a 1x1 invisible stand-in window placed under the menu bar of the
target screen, so AppKit is never asked to rescue a popover anchored into the
void. Then it is clamped, with the popover's 13pt shadow taken off first.

## Log

`~/.unstray/events.jsonl`, one JSON object per line: `launched`, `found`,
`repaired`, `rescued`, `hotkey`, `os_updated`, `permission_requested`,
`permission_granted`. Local only; never transmitted.

## Known gaps

- Rescue is verified against a genuinely stranded window, built on purpose
  (2026-08-14): the installed app, a real ⌥⌘R, and a window brought back from a
  spot no screen covers. Nothing on this machine strands itself post-fix, so any
  future check has to build its own case — and must build the stray window LAST,
  since creating another window after it puts the first out of AX's reach.
- Fullscreen detection of other apps' windows is unreliable on Tahoe
  (Apple FB18862047) — not currently relied upon.
- The popover cannot be driven by `System Events` (non-standard window layer),
  so UI verification is screenshot-based.
