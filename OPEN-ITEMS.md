# Open items

Things known to be unfinished or unwatched. Add a date and enough context to act
without the conversation that found it.

## A true problem can keep moment-specific wording for too long

2026-08-14. A recorded problem stays until the app is fixed or quits. The panel
can therefore say "You clicked Chrome and nothing came up" long after that click.
The condition remains true, but the sentence describes a moment that has passed.

No expiry was added. A timer could drop a true problem and restore the false
all-clear this design removes. The product needs either a staleness limit or new
wording for these three findings that does not imply a recent click. Copy is
Douglas's call.

## Each repair means something different by "it worked"

2026-08-14. Every `Finding.repair` closure returns a `Bool`, and each one means
something else. `appNotResponding` opens Activity Monitor and returns a hardcoded
`true`, having repaired nothing. `appShowsNothing` returns whether an Apple event
was accepted, and the headless-Chrome case proved an event can be accepted and
ignored. The window repairs return whether the accessibility layer accepted a new
position.

This reaches no UI — since 5712af9 the panel is driven by the re-check, not by
this value — so nothing on screen lies about it. But `RepairLog.repaired` writes
it as `success`, and that log is what a later diagnosis reads. "Opened Activity
Monitor" recorded as a successful repair of a frozen app is data that will
mislead somebody.

Either make the closures return whether the person's problem is gone, or stop
calling the field `success` and record what was actually attempted.

## The stranded scan can still offer a button that does nothing

2026-08-13. The edge-pushed check now refuses to report a window on another
Space, because the accessibility layer cannot move one and the button would
never work (see `kCGWindowIsOnscreen` in `WindowScan.findOutOfReach`). The older
stranded scan — `WindowScan.check()`, the "Bring it back" button — has the same
hole and was deliberately left alone. A window parked past every screen on a
Space you are not looking at is reported, and pressing the button cannot move
it.

Left alone because that scan was tuned against real false alarms (eight menu-bar
helpers, then the app the person was reading the panel in), and changing what it
reports risks reopening those. Fix it with the same flag when there is a real
case to test against.

## A multi-app rescue can strand its own later items

2026-08-13. `WindowRescue.rescue` calls `bringToFront` once per app in the list.
Bringing an app forward can move the person to another Space, and every window
still queued behind it then becomes unreachable in the same run. Observed: a
three-app rescue moved two and left the third, which is what led to the
`kCGWindowIsOnscreen` fix. The fix makes this much less likely — every reported
item is on the current Space when the scan runs — but nothing stops an app from
switching Spaces mid-loop.

## A gap between screens can read as reachable

2026-08-13. `ScreenSpace.visiblePart` returns the bounding box of everything a
window shares with any screen, so a window straddling two screens that do not
touch counts the dead space between them as visible. It errs toward saying
nothing, which is the safe direction, and macOS rarely lets displays be arranged
with a gap. Worth knowing before trusting the number for anything else.

## The rescue key is still untested against a fully stranded window

2026-08-13. `WindowRescue.gather` is verified against an edge-pushed window: one
at (1850, 250, 509, 700) moved to x=1411 while a usable window beside it was
left alone. The fully-stranded branch — a window past every screen — has still
never been exercised on a real one, which is what `SPEC.md` already says.

## Local git history diverged from GitHub

2026-08-13. The local clone and `origin/main` held content-identical histories
under different commit hashes — 51 local commits against 50 remote, every tree
byte-identical. Someone rewrote one side at some point. Resolved by replaying
the new commit onto the remote lineage; no force push, nothing lost. The old
local lineage is kept on the branch `backup-local-main-20260813`. Delete that
branch once you are satisfied nothing is missing.
