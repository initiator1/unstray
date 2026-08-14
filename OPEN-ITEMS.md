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
