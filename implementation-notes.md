# The rescue was racing a screenful change, and losing

2026-08-14. Four open items closed together, because one measurement answered
three of them.

## Method

Nothing was changed until real windows existed to change it against. A small
harness makes ONE window at an exact position and keeps it there, and a second
tool drives the shipped `WindowScan` and `WindowRescue` sources — compiled in,
never copied — against it. A window made to fill the whole screen supplies the
second screenful, which is the only way to reach the "one screenful away"
condition without driving Mission Control by hand.

A binary launched from the shell inherits the terminal's Accessibility
permission, so all of this runs without asking anyone for anything.

## What was measured

1. **A window parked at x = -12000, off every screen, reports
   `kCGWindowIsOnscreen = true`** while it sits on the current screenful. Put a
   different screenful in front and the same window reports `false`, and AX
   returns nothing for it. The flag has nothing to do with pixels, which is what
   the earlier note said, now confirmed from the opposite end.

2. **AX answers for an app that is not frontmost.** The comment in `rescue` said
   the app "has to be frontmost for its things to become visible to the
   accessibility layer at all". That is wrong. Being on the current screenful is
   what matters.

3. **Activation is what carries the person to another screenful, and it takes
   about a third of a second.** First AX answer at 350ms. At the 120ms the
   rescue waited, five runs out of five saw no windows at all; a further
   148–498ms saw the window every time.

Losing that race is silent: no windows, nothing moved, nothing said. That is the
mechanism behind "a three-app rescue moved two and left the third".

## The stranded scan was not offering a dead button

The open item said a window stranded one screenful away is reported and the
button cannot move it. Built and pressed: it can. `rescue` brings the app
forward, that carries the person to the window, and the window comes back. The
real "Bring it back" repair moved a window from x = -12000 into the middle of
the screen while a fullscreen window held the display.

So the scan is right to report it, and gating it on `kCGWindowIsOnscreen` would
have hidden a problem this app can fix. What was actually wrong was the wait.

## The rescue is immune to the setting it depends on

That raised a worry: the rescue leans on activation switching screenfuls, which
is exactly what `AppleSpacesSwitchOnActivate` controls — one of the three
settings unstray watches. If the rescue needed that setting to be right, then
the repair for the symptom would be disabled by the fault being reported.

Measured on 2026-08-14, with Douglas's agreement to turn the setting off for a
few minutes. Every run restored it through a shell trap, so an error could not
leave it wrong.

**The rescue does not care.** With the setting off, the real "Bring it back"
button carried the person to the window's screenful in 382ms and brought the
window from x = -12000 back to the middle of the screen. Same with the Dock
restarted, in case the write had not been re-read: 383ms.

A result like that is worthless without knowing the setting was in force, so a
control was built. It takes a screenful of its own by going fullscreen — which
makes it frontmost, the state macOS's cooperative activation requires of a
caller — and then activates the target the MODERN way, which is the path the
setting governs.

| Setting | Modern `NSRunningApplication.activate` | Carbon `SetFrontProcessWithOptions` |
|---|---|---|
| on | carried over after 445ms | carried over after 350ms |
| off | **never carried** (2s) | carried over after 382ms |

So the setting is real and in force, and the Carbon shim ignores it. That is a
third measured reason not to "modernise" `LegacyActivation.c`, alongside the two
Apple bugs already recorded. The open item is closed: no ordering change is
needed, because the button works either way.

**A shipped promise, checked while the switch was in hand.** unstray's repair for
this setting writes it and does nothing else, and the panel offers no cost
warning — so if a write alone were not enough, that button would be a lie under
the app's own rule about never promising what it cannot do. Written off with
nothing restarted: not carried. Written back on with nothing restarted: carried,
455ms. The write takes effect at once in both directions. The button is honest,
and now verified rather than assumed.

## The gap between two screens: no change, on purpose

`ScreenSpace.visiblePart` returns a bounding box, so a window straddling two
screens with dead space between them counts that space as visible.

Screens set beside each other share an edge however far up or down one is slid,
and any window touching both then touches them along that shared edge — so the
pieces always meet and the bounding box is the shape the person sees. Only
screens dragged to meet at a corner can separate the pieces.

All three callers use this number to decide whether to SPEAK: the size floor in
`WindowUse.judge`, the "this app still has something on screen" test in
`findOutOfReach`, and one line of the log. A generous answer keeps unstray
quiet; a stingy one invents problems. Crying wolf is the failure this app has
actually shipped — eight menu-bar helpers, then the app the person was reading
the panel in — and missing a two-corner window on a diagonal desk is not. The
behaviour is now pinned by a test named for the decision, so the next person
meets the reasoning rather than the surprise.

## Deprecation pass

| System | Disposition |
|---|---|
| `Finding.repair: () -> Bool` | REFACTOR — same field, returns `RepairOutcome`; one Bool that meant five things was the item |
| `RepairLog.repaired(_:success:)` | REFACTOR — takes the outcome; the `success` key is deleted rather than renamed, because no reader could tell which meaning an existing line carried |
| `RepairLog.rescued(count:)` | REFACTOR — was defined and never called; now records moved against reported |
| `WindowRescue.rescue(_:)` | REFACTOR — one trip per app instead of per window, waits for reachability, returns the outcome |
| `WindowRescue.gather(pid:)` | REFACTOR — same wait; its Bool is unchanged, being a different question (did anything visible happen) |
| the flat `usleep(120_000)` in both | DELETE — measured too short whenever a screenful change is involved |
| `WindowRescue.bringToFront(pid:)` | KEEP UNCHANGED — still the only activation path; the wait wraps it rather than replacing it |
| `WindowRescue.axWindows(pid:)` | KEEP AS LEAF — now called by the wait rather than by each caller |
| `VerdictModel.repair(_:)` | KEEP AS LEAF — passes the outcome to the log; `recheck()` still owns the verdict |
| `WindowScan.check()` stranded gate | KEEP UNCHANGED — measured: the button works, see above |
| `WindowUse.Report.canBeMoved` | KEEP UNCHANGED — still gates the edge case only |
| `ScreenSpace.visiblePart` | KEEP UNCHANGED — see above |

## Verified live, 2026-08-14

- A window at (-12000, 400, 800, 600), reported by the real scan, rescued by the
  real button from a different screenful, back to (560, 256, 800, 600).
- Two apps each with a stranded window, rescued in one press from a different
  screenful, to (560, 256) and (610, 306). Logged as `moved:2 reported:2`.
- The installed app in `/Applications`, sent a real ⌥⌘R with the person on the
  same screenful: (-12000, 400, 700, 500) back to (610, 306, 700, 500), and
  `{"event":"hotkey","movedSomething":true}` in its own log. That also proves
  the Accessibility grant survived the rebuild and redeploy.

## Deviations

- **The two-app, two-screenful case was not built.** New windows land on the
  desktop screenful, and the only screenful a script can create without driving
  Mission Control is a fullscreen one, where a stray window cannot live. So the
  multi-app rescue was exercised with both apps one screenful away rather than
  on two different ones. The mechanism is the same wait, measured directly.
- **`AppleSpacesSwitchOnActivate` was not turned off to test the degraded
  case.** It is one of the three settings this app exists to protect, on the
  machine its owner is using. Recorded as an open item with the experiment to
  run instead.

---

# One author for the verdict

2026-08-14. The repair button could replace a known problem with an unearned
all-clear.

## What was wrong

The panel pulled settings and window findings into `recheck()`. The watcher
pushed three other findings straight into `verdict`. A repair then called only
the pull path. That path could not find the watcher's problem, so it reported
that all was well while the problem remained.

The same split had already caused two earlier failures. The pull and push paths
used different window rules and different startup patience.

## The fix

`EmptyAppWatch` now records the app name, pid, and problem category in
`OpenProblems`. It then asks `recheck()` to decide the verdict. `recheck()`
re-asks each recorded problem and removes it only when the answer is known.

A failed Accessibility check keeps the last honest problem. A terminated app is
removed. A relaunch waits for a later pass. A current problem is re-derived, so
its kind can change when the app's condition changes.

Every repair now gets an immediate recheck and one settled recheck after one
second. The watcher and the button path share that delay. The immediate pass
prevents a false all-clear. The settled pass sees repairs that finish after the
repair call returns.

`Finding.shownFirst` now gives every finding a complete order. Severity wins
first. Kind wins next. The id breaks the final tie. Arrival order no longer
changes the one problem shown.

## Deprecation pass

| System | Disposition |
|---|---|
| `VerdictModel.showUnusable(appName:problem:)` | REFACTOR — replaced by `noteUnusable(appName:pid:problem:)`, which records evidence and calls `recheck()` |
| `EmptyAppWatch.onUnfixable` | REFACTOR — now carries the pid that identifies the same process |
| `VerdictModel.recheck()` | REFACTOR — now owns every runtime verdict decision |
| `VerdictModel.repair(_:)` | REFACTOR — now adds one settled confirming recheck |
| `WindowScan.unusable(appName:problem:)` | REFACTOR — now forwards its value-only kind to the one string factory |
| `EmptyAppWatch` silent repair and patience | KEEP UNCHANGED — still decides when to speak first |
| `EmptyAppPatience` | KEEP UNCHANGED — still answers whether an app is broken or opening |

## Found during review

- **A fabricated accessibility handle.** The first version rebuilt a
  `Usability.Problem` by putting `AXUIElementCreateApplication(pid)` into the
  `window:` slot. It was inert — every repair re-derives the real window before
  it moves anything — but inert by luck, and the type was lying. `WindowScan`
  only ever switches on WHICH problem it is, so `Usability.Problem.Kind` now
  carries that and no fake handle exists.
- **Two sources can name the same finding.** An off-edge window the watcher
  tried and failed to slide back is recorded here AND found by
  `checkOffTheEdge()`, so `recheck()` could hold the same id twice. Findings are
  deduplicated by id after sorting, so the ordering decides which copy survives.
- **The test target had swallowed the whole app.** Reaching `fate` pulled in
  `OpenProblems`, which pulls `Usability`, `WindowScan`, `WindowRescue`,
  `ActivityWatch`, `RepairLog` and the Carbon shim — three seconds, and code that
  can move a person's windows one careless line from running in a test. The pure
  decision moved to `ProblemFate.swift`, the same shape as `EmptyAppPatience`
  and `PanelPlacement`. The list in `run-tests.sh` is back to seven
  dependency-free modules and about a second.

## Verified live, 2026-08-14

Calculator, launched and left alone past the startup grace, then `SIGSTOP`ped so
it genuinely stopped answering. `Usability.problem` returned `.notResponding`.
The panel said "Calculator has stopped answering." A second re-check — which is
exactly what the repair button triggers — said it again, where the old code
would have dropped to "Everything is where it should be". `SIGCONT`, and the
next look forgot it on its own.

## Deviations

- The brief says `OpenProblems` must store only the app name, pid, and time. It
  also says a failed check must keep saying the prior problem. Those rules
  conflict when the live problem cannot be re-derived. The store keeps
  `Usability.Problem.Kind` as the conservative answer. It never stores an
  `AXUIElement`. `record` accepts the observed problem so it can keep the exact
  category that the watcher already stated.

---

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

---

# Windows left hanging off a screen edge

2026-08-13. A measured Epson Scan 2 window kept only 40pt of its 434pt width on
screen. Both old checks accepted that sliver as usable.

## Deviations

- The earlier app-specific scan used a 120pt height floor. The machine-wide scan
  used 150pt. The refactor keeps both values in `WindowUse.Scope`, while the
  visible-area bar stays at 200pt wide and 120pt tall.
- `Usability.problem(for:)` now gives the title-bar repair the window whose title
  bar is out of reach. The old branch gave it the first on-screen window, which
  could have a different problem. This is the brief's only behavior correction.
- **The repairs now hold the same size floor as the checks, which narrows them.**
  `WindowRescue.rescue` and `gather` used to move any accessibility window they
  found off screen, at any size. Both now judge through `WindowUse`, so anything
  under 200x120 is left where it is. This was not asked for; it follows from
  routing them through the one judgement, and it is kept deliberately.

  Apps park real windows off screen on purpose — an Epson process on this Mac
  holds surfaces of 64x64 and 1920x30 — and dragging one of those into the middle
  of somebody's screen would look exactly like the bug this app removes. The old
  behaviour would have done it. The cost is the opposite case: a genuinely useful
  window under 120pt tall, stranded, that ⌥⌘R no longer retrieves. That shape is
  rare, and a thing the app would not call lost should not be a thing it drags
  back.

## Verified live, 2026-08-14

Reproduced the measured geometry again after the refactor. A window at
(1880, 200, 509, 700) on a 1920x1080 screen was reported, the button moved it to
x=1411 flush with the right edge with y untouched, and the rescan came back
clean. ⌥⌘R moved a window at (1850, 250, 509, 700) to x=1411 the same way.

### `kCGWindowIsOnscreen` is not what the earlier note claimed

That note said the flag means "on the current screenful, not visible". The first
half is a guess and the measurement does not support it. Creating a second,
fully visible Finder window flipped the FIRST window's flag from `true` to
`false` while that window had not moved a point and still had 40pt showing.
Creating a third flipped it back and knocked out the second.

What was then tested in both directions is narrower and is all the code needs:
when the flag is `false`, `AXUIElementCopyAttributeValue(kAXWindows)` does not
return that window at all, so it cannot be read or moved; when it is `true`, AX
returns it and `kAXPosition` accepts a new value. So read the flag as "the
accessibility layer can reach this", and never as a claim about pixels or about
Spaces.

This cost a false alarm during review: a live test built two windows in the
wrong order, the first went out of AX's reach, the scan correctly reported
nothing, and that looked like a regression in the refactor. It was the test that
was wrong. Build the off-edge window LAST when reproducing this by hand.

## Found during review

- **The first version reported windows on other Spaces.** A live run flagged
  three apps; the repair moved two and could not touch the third, because AX
  reaches only the current Space. That leaves a "Slide it back" button that does
  nothing however often it is pressed. `kCGWindowIsOnscreen` now gates the edge
  case. It reads as "on the current screenful", not "visible": a window with
  40pt of 509 left on screen reported `true`, a window in the middle of the
  screen one Space over reported `false`.
- **The plural read wrong.** "Only a sliver of them is still on your screen"
  describes one shared sliver and does not agree with its own verb. Each window
  has its own, so the plural is "a sliver of each".
- **The finding rebuilt itself from a second scan.** `checkOffTheEdge()` called
  `windowOffTheEdge()`, which walked the whole window list again and could come
  back with a different answer than the one the finding was written from. The
  activation check also accepts a shorter window than this scan does, so the
  button could be handed an empty list. It now falls back to the same question
  that raised the finding, the way `titleBarOutOfReach` already did.

## Verified live, 2026-08-13

Reproduced the measured geometry with a throwaway window at (1880, 200, 509,
700) on a 1920x1080 screen. `checkOffTheEdge()` reported it, the button moved it
to x=1411 — flush with the right edge, y untouched — and the rescan came back
clean. Two genuinely lost windows turned up in the same run that nothing had
been watching: App Store with 48pt of 1168 left, Standard Notes with 157pt of
1160.
