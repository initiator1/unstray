# unstray

A small Mac app that notices when your Mac has hidden something from you, brings
it back, and tells you what happened in plain words.

It lives in the bar at the top of your screen and stays out of the way until it
is needed.

---

## The problem

You click an app. Nothing appears. The menu bar changes, so the app is clearly
*there* — but there is no window. You click again. Still nothing.

Or you make a video full screen and your other monitors go black.

Or you unplug a monitor, and something you had open is simply gone.

None of this is your fault. These are real, open, unfixed bugs in macOS:

- **FB21087054** — clicking an app's Dock icon activates it but does not bring
  its window forward. Apple has acknowledged this.
- **FB18016497** — windows reopen on whichever desktop they were last on, not
  the one you are looking at.
- **FB11974786** — the API for "bring all of an app's windows forward" has not
  worked since macOS 10.15, per Apple's own engineers.

In February 2026 Apple's release notes claimed a fix for a window bug, then
silently edited it back to "known issue" the same night.

Worse, macOS quietly changes its own settings during updates. On the machine
this was built for, an update turned off "Displays have separate Spaces" — which
blacked out two 4K monitors and stranded five windows at coordinates no screen
could reach. macOS never mentioned it.

## What unstray does

**Answers one question.** Open it and it tells you whether anything is wrong
right now. If nothing is, it says so in one sentence. If something is, it shows
exactly one problem — the worst one — with one button.

**Watches three settings** that decide whether macOS can lose your windows, and
checks them again after every macOS update, because that is when they drift.

**Finds windows parked where no screen can reach** and brings them back to the
screen you are using.

**⌥⌘R rescues whatever you are fighting with** — unminimizes it, unhides it, and
drags it back into view.

**Explains everything in plain language.** Never "window off-screen at
-12000,12485". Instead: *"Your Notes are still open — they just moved to where
your other monitor used to be."*

Every explanation is written for someone who has never really used a computer —
who does not know the words *window*, *Space*, *minimize*, or *off-screen*, and
who will assume they broke something. They didn't, and the app says so.

## Install

```bash
git clone <this repo> && cd unstray
./build.sh
cp -R build/unstray.app /Applications/
open /Applications/unstray.app
```

Then grant Accessibility permission when asked (System Settings → Privacy &
Security → Accessibility). Without it, unstray can still find and fix settings
problems — it just cannot move windows.

It starts with your Mac from then on. If you turn that off, it stays off.

### Signing

`build.sh` signs with Developer ID if one is available, falling back to ad-hoc
with a warning. **Use a real identity if you have one.** Ad-hoc signatures change
the app's identity on every rebuild, so macOS silently revokes the Accessibility
permission each time — which is the exact silent failure this app exists to fix.

```bash
UNSTRAY_SIGN_ID="Developer ID Application: Your Name (TEAMID)" ./build.sh
```

## Using it

| | |
|---|---|
| **Click the icon** in the top bar | See whether anything is wrong |
| **⌥⌘R** | Bring the app you are fighting with back to your screen |

It also looks on its own when you wake your Mac, when you plug or unplug a
screen, and after a macOS update.

## What it will not do

- It does not tile, snap, or arrange your windows. There are plenty of tools for
  that, and they are not this.
- It never moves a window you deliberately placed — only ones no screen can reach.
- It never reads your screen, types, clicks, or sends anything.
- It does not run in the background watching you. It looks when something
  happens, then goes quiet.

## Uninstalling

unstray leaves three things behind. Removing all three takes a minute:

1. **Quit it** — click the icon in the top bar, then Quit.
2. **Delete the app** — drag `/Applications/unstray.app` to the Trash. That also
   removes it from your login items.
3. **Remove its notes** — `rm -rf ~/.unstray` in Terminal, or delete the
   `.unstray` folder in your home folder. It only ever contains a small log of
   what unstray found and fixed.
4. **Take back the permission** — System Settings → Privacy & Security →
   Accessibility → switch unstray off, or select it and press the minus button.

## Privacy

unstray makes no network connections of any kind. There is no analytics, no
telemetry, no crash reporting, no update check — the app contains no networking
code at all.

It writes one file, `~/.unstray/events.jsonl`, readable only by you. It records
what kind of problem was found and whether a fix worked. It does **not** record
which apps you use, window positions, window titles, or anything on your screen.

## Troubleshooting

**I can't see the icon in my menu bar.** If you use Bartender, Ice, or a similar
tool, it may be hiding it — check that app's settings. Menu bars that are very
full can also push icons off the edge on smaller screens.

**⌥⌘R does nothing.** Another app may already be using that combination.
unstray tries ⌥⌘R first, then ⌥⇧⌘R, then ⌥⇧⌘W. Check `~/.unstray/events.jsonl`
for a `hotkey_fallback` line to see which one it got.

**It says it needs to log me out.** Only for the setting that makes your screens
independent again — macOS itself requires the logout. Save your work first;
unstray will not log you out without you pressing the button.

## Requirements

macOS 14 or later (developed and tested on macOS 26.5 "Tahoe"). Not sandboxed,
so it cannot ship on the Mac App Store.

## For developers

Architecture and the API constraints that shaped it: [PLAN.md](PLAN.md).
Product reasoning: [SPEC.md](SPEC.md). Working notes: [CLAUDE.md](CLAUDE.md).
The writing rules every user-facing string obeys:
[docs/plain-language.md](docs/plain-language.md).

Short version of the hard parts:

- Accessibility can move windows but only sees the desktop you are looking at.
  `CGWindowList` sees every desktop but cannot move anything. You need both.
- There is no public API to move a window to another desktop. So unstray moves
  *you* to the window instead — no SIP disabling, no private APIs, nothing that
  breaks on the next macOS.
- `NSRunningApplication.activate` silently does nothing when called from a
  menu-bar app. The one call that reliably works is a deprecated Carbon
  function Swift refuses to import, hence a small C shim.

## Bugs and questions

Open an issue: https://github.com/INITIATOR/unstray/issues

## Licence

MIT — see [LICENSE](LICENSE). Copyright (c) 2026 INITIATOR LLC.

Built and maintained by [@initiator1](https://github.com/initiator1).

This software is provided as is, without warranty of any kind. It changes
macOS settings and moves application windows at your request; you are
responsible for deciding whether to let it.
