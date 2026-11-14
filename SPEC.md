# SPEC.md — unstray

## What it is

A small macOS app that lives in the bar at the top of the screen. It notices
when your Mac has hidden something from you, brings it back, and tells you what
happened in plain words.

It is not a window manager. There are eleven of those, and all eleven fail the
person this is built for.

## Why it exists

In July 2026 a Mac running macOS 26.5 had three connected screens and 71 open
windows. Only 5 were visible. Five more were parked at coordinates no screen
could reach. Making a video full screen blacked out two 4K monitors.

The owner had turned off a setting called "Displays have separate Spaces"
himself, months earlier, trying to stop windows from disappearing. It is a
plausible-sounding fix that makes the problem worse, and nothing in macOS told
him so. He had long since forgotten changing it.

That is the more common story, and a harder one: the setting was not sabotage,
it was a reasonable guess that backfired silently.

Underneath are three real, open, unfixed Apple bugs:

- **FB21087054** — clicking an app's icon in the Dock activates it but does not
  bring its window forward. Apple has acknowledged this.
- **FB18016497** — windows reopen on whichever desktop they were last on rather
  than the one you are looking at.
- **FB11974786** — the API for "bring all of an app's windows forward" has not
  worked since macOS 10.15, per Apple's own engineers.

In February 2026 Apple's release notes claimed a fix for a window bug, then
silently edited it back to "known issue" the same night. Waiting for Apple to
fix this is not a plan.

**These settings will drift again on the next macOS update.** That is the
recurring job: catch it, and explain it, without anyone needing to remember any
of this.

## Who it is for

Primarily one person, on one Mac. But the explanations are written for someone
who has never really used a computer — who does not know the words *window*,
*Space*, *Mission Control*, *minimize*, or *off-screen*, and who will assume
they broke something.

That constraint is the product, not a nicety. Every existing tool in this space
assumes fluency the user does not have.

## What it does

**Answers one question.** Open it and it says whether it found a problem right
now. If something is wrong, it shows the worst problem with one main button.
The quiet panel also lets the person name an app that still will not appear.

**Watches three settings** that decide whether macOS can lose your things, and
notices when a macOS update changes them behind your back.

**Finds things parked where no screen can reach, or left hanging off an edge,**
and brings them back to the screen you are looking at.

**A rescue key (⌥⌘R)** that gathers whatever app you are trying to reach onto
the screen you are using — unminimizing, unhiding, and dragging back anything
that has wandered off.

**A "Missing an app?" choice** for cases the automatic check cannot prove.
It opens a list inside the panel on one click. The list shows running apps,
then asks macOS to bring the chosen app forward. If no
window exists, it asks the app to open one and checks again. It says when a
window exists but may be in another set of windows; it does not claim to see
what is visible to the person.
For a named app, it may move one window to the center of the current screen.
This handles a window covered by a floating panel.

**Checks the active app automatically.** After an app comes forward, unstray
checks whether another window fully covers it. It also checks every two seconds
while that app stays active. It raises the app first and moves one window only
when the cover remains. A rectangle alone is not proof: an apparently solid
overlay can be transparent. Unstray checks whether the app can be reached at a
point inside its window before acting. An automatic warning clears if the app
becomes reachable later. The named-app choice stays available as a fallback.
An active screenshot selection pauses automatic covered-window repair. Failed
Accessibility hit tests leave visibility unknown and do not move a window.

**Explains, every time.** Never "window off-screen at -12000,12485". Instead:
"Your Notes are still open — they just moved to where your other monitor used
to be."

## Product decisions

**One problem at a time, not a dashboard.** A list of problems is a control
panel, and a control panel is what makes every other tool useless to a beginner.

**The healthy screen gets the most design care**, because it is what shows 99%
of the time. "Everything is where it should be" plus proof of what was checked.

**No red anywhere.** Nothing this app reports is an emergency. The attention
colour is warm amber — a lamp switched on in a dark room, not an alarm. Red
would make someone feel they had broken something.

**Say whose fault it is, out loud.** "This is a bug in macOS. It is not your
fault." A beginner's default assumption is that they caused it. Correcting that
is the single most useful sentence on the screen.

**Watch the result, not the Dock click.** The activation event cannot tell a
Dock click from Cmd-Tab, and a second click on an active app may send no event.
Unstray checks whether the frontmost app's windows are fully covered instead.
The hotkey and named-app choice remain explicit ways to try again.

**Do not move windows across Spaces.** That needs private APIs, SIP disabled,
and an NVRAM boot-arg on Apple Silicon. Not worth a security downgrade for a
window bug. A named-app request can move one window within the current Space.

**Never fail silently.** If the app cannot help, it says so. Silently doing
nothing is the exact bug it exists to fix.

**Keep the next useful action visible.** A named-app result is extra context;
it never replaces a real problem or its repair button. A failed named-app result
survives background checks, and Check again retries that app when shown. The
support link appears only on a plain all-clear panel, with no named-app message
beside it.

## Free, and why

Free and MIT, deliberately. Not because a Mac utility cannot earn, but because
this one is narrow: it does one job, most people meet it once, and the effort to
build licensing and support would cost more than a small one-time price returns.

The Mac App Store is closed to it regardless — moving another app's windows needs
the Accessibility API, which is incompatible with the sandbox the Store requires.

MIT does not rule out charging later if it finds a real audience.

## Out of scope

Tiling, snapping, layouts, workspace management, anything requiring SIP off or
private APIs, and anything sandboxed (this cannot ship on the Mac App Store).

## Status

Working: the check engine, both verdict panels, the permission flow, launch at
login, macOS-update detection, the rescue engine, and the log.

The rescue key now has a genuinely stranded window behind it. On 2026-08-14 a
real window was parked at a spot no screen covers, and the installed app was
sent a real ⌥⌘R: it brought the window back to the middle of the screen and
wrote the rescue into its own log. The same window was rescued from a different
screenful by the panel's own button. Both cases were built on purpose, since
this machine has had nothing genuinely lost on it since the settings were fixed.

## Opening by itself

unstray opens its panel without being asked only when a fresh check confirms
a problem. If the check that follows a failed repair finds nothing wrong, it
logs `auto_open_skipped` and stays closed. A running-app record with no live
process (a launcher script that `exec`s another program) is never judged. A
substantial on-screen window above the normal layer counts as the app showing
something.

