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

**Answers one question.** Open it and it says whether anything is wrong right
now. If nothing is, it says so in one sentence and offers nothing else. If
something is, it shows exactly one problem — the worst one — with one button.

**Watches three settings** that decide whether macOS can lose your things, and
notices when a macOS update changes them behind your back.

**Finds things parked where no screen can reach** and brings them back to the
screen you are looking at.

**A rescue key (⌥⌘R)** that gathers whatever app you are trying to reach onto
the screen you are using — unminimizing, unhiding, and dragging back anything
that has wandered off.

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

**A key press, not a watcher.** The original idea was to detect repeated Dock
clicks. macOS provides no way to tell a Dock click from Cmd-Tab or Spotlight,
and the event-tap workaround has a documented Tahoe code-signing race that
silently disables it. More importantly, pressing a key makes unstray frontmost —
which is exactly the state macOS requires before one app may bring another
forward. The hotkey works *because* of how the OS behaves, not despite it.

**Move the person to the window, never the window to the person.** Moving a
window across Spaces needs private APIs, SIP disabled, and an NVRAM boot-arg on
Apple Silicon. Not worth a security downgrade for a window bug.

**Never fail silently.** If the app cannot help, it says so. Silently doing
nothing is the exact bug it exists to fix.

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

Untested in the wild: the rescue hotkey against a genuinely stranded window,
because after the settings fix this machine no longer has one.
