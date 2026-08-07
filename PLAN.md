# PLAN.md — unstray architecture

## Shape

A menu-bar-only app (`LSUIElement`), event-driven, idle at zero cost. No polling
loops except the deliberate one-second permission poll, which stops the moment
permission arrives.

```
AppDelegate ──owns──> VerdictModel ──produces──> Verdict ──renders──> VerdictView
     │                     │                                              │
     │                     ├── SettingsCheck.runAll()  ──> [Finding]      ├─ AllWellPanel
     │                     ├── WindowScan.check()      ──> Finding?       ├─ ProblemPanel
     │                     └── WindowRescue            ──> repairs        └─ PermissionPanel
     │
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
| `kind` | `blackDisplays` / `appsWontComeForward` / `hiddenMinimized` / `strandedWindows` |
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

## The window problem, and why it takes two APIs

| API | Sees all Spaces | Can move things |
|---|---|---|
| `CGWindowListCopyWindowInfo` | yes | no |
| Accessibility (`AXUIElement`) | current Space only | yes |

So: scan with CGWindowList to find what is unreachable, then bring the owning
app frontmost (which makes its windows visible to AX), then move them with AX.

Filter `activationPolicy != .regular` or menu-bar helpers register as problems.

## Activation, and the C shim

`NSRunningApplication.activate` uses macOS 14's cooperative model — the frontmost
app must yield. A menu-bar app is never frontmost, so calls silently no-op
(FB21087054). `.activateAllWindows` has been broken since 10.15 (FB11974786).

`SetFrontProcessWithOptions(&psn, 0)` still does both correctly. It is deprecated
but **not private** — no SIP, no boot-args, no scripting addition — so it should
survive OS updates. Swift refuses to import pre-10.9 Carbon symbols, hence
`LegacyActivation.c`. The modern call remains as a fallback.

## When it looks

| Trigger | Why |
|---|---|
| Launch | Catches drift from an update that happened while closed |
| Menu-bar click | They came asking |
| ⌥⌘R | They are fighting an app right now |
| Wake from sleep | Reported cause of stranding on Tahoe |
| Screen plugged/unplugged | Biggest single cause; 2s delay to let macOS settle |
| OS version changed | The recurring job |

No timer, no Dock-click watcher. Dock clicks are indistinguishable from Cmd-Tab
via public API, and the event-tap workaround has a Tahoe code-signing race.

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

- Rescue is unverified against a genuinely stranded window (none exist on this
  machine post-fix).
- Fullscreen detection of other apps' windows is unreliable on Tahoe
  (Apple FB18862047) — not currently relied upon.
- The popover cannot be driven by `System Events` (non-standard window layer),
  so UI verification is screenshot-based.
