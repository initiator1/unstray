# Open items

Things known to be unfinished or unwatched. Add a date and enough context to act
without the conversation that found it.

## A true problem can keep moment-specific wording for too long

2026-08-14. A recorded problem stays until the app is fixed or quits. The panel
can therefore say "You clicked Chrome and nothing came up" long after that click.
The condition remains true, but the sentence describes a moment that has passed.

**Decided by Douglas, 2026-08-14: fresh words, then plain.** A finding keeps its
moment sentence while it is new, then the same finding switches to a plain one
about how things stand. Nothing is ever dropped and the button never changes. A
staleness limit was rejected on the spot — a timer can drop a problem that is
still true and put back an all-clear the app has not earned, which is the
failure this app exists to remove.

**Waiting on Douglas: the later sentences.** Nobody else writes these. Only two
of the three findings read as dated, so he decides which need a second version:

| Finding | What it says now | Reads as |
|---|---|---|
| `appShowsNothing` | "You clicked \<app\> and nothing came up." plus "I asked it to open one and it did not answer." | dated — a click, and a request, that both happened at a moment |
| `appNotResponding` | "\<app\> has stopped answering." | mildly dated — "has stopped" implies it just happened |
| `titleBarOutOfReach` | "You can see \<app\>, but you cannot move it." | fine at any age; probably needs nothing |

The machinery is small and the wording is the only blocker. The age is already
recorded — `OpenProblems.Seen.seenAt` — and `WindowScan.unusable(appName:kind:)`
is the single place every one of these strings is built, so the switch belongs
there and nowhere else. Not built yet: a mechanism with placeholder sentences in
it would be a stub, and this repo does not ship those.

## A rescue may not work when apps are set not to follow their windows

2026-08-14. Reasoned, not measured — do not act on it without building the case.

The stranded repair works by bringing the app forward, which carries the person
to the screenful its window is on. That switch is what
`AppleSpacesSwitchOnActivate` controls, and that setting is one of the three
unstray watches. All three read correctly on this Mac, so every measurement
behind the 2026-08-14 rescue work was taken with it ON.

With it OFF, activation should not change screenfuls, so a window one screenful
away should stay out of AX's reach and "Bring it back" should fail after waiting
1.5s. Worse, `Finding.Kind.displayOrder` puts `strandedWindows` (2) ahead of
`appsWontComeForward` (6), so the panel would show the button that cannot work
and hide the one that fixes the cause.

Not tested, because it means turning off one of the three settings this app
exists to protect, on the machine its owner is working on. To do it properly:
ask first, write `NSGlobalDomain AppleSpacesSwitchOnActivate = false`, park a
window off every screen, put a fullscreen window in front, press the button, then
restore the setting and confirm it reads 1 again. If it does fail, the fix is
probably ordering, not geometry: show the settings problem first when both are
true.
