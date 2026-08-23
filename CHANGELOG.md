# Changelog

## 0.2 — 2026-08-22

Most of this release is unstray learning when to keep quiet. Version 0.1 told
people that working apps were broken. Every one of those was the same failure
this app exists to remove, pointed the wrong way.

### It stops saying things that are not true

- **An app that is opening is no longer called broken.** Click Update in an app,
  and for a second or two it has no window — which looks exactly like the fault
  unstray watches for. Only time tells them apart. An app that is starting now
  gets many seconds, is asked to show a window before anything is said, and is
  let go quietly rather than blamed.
- **An app that is restarting is no longer called frozen.** unstray said Claude
  had stopped answering while Claude was updating itself, and Claude came back a
  second later. Nothing is called frozen now without a second look. It was the
  one thing unstray cannot fix, the most alarming thing it says, and the most
  likely to be temporary.
- **A browser with no window on purpose is no longer called broken.** Some are
  started deliberately with no window at all. unstray offered to fix one, twice,
  with a button that could never have worked.
- **Steam is no longer reported as empty while it is on screen.** Its real window
  belongs to a second helper program, so unstray asked the wrong one. This would
  have happened with many apps built the same way.
- **It no longer says your screens will go black.** That setting only bites if
  you add a screen and then make something fill it. It now says what is set, and
  lets the explanation cover what might follow.
- **It no longer blames a macOS update for something the update may not have
  done.** All unstray knows is that macOS changed version and something is wrong
  now. It says that, and no more.
- **It only opens by itself for something that is wrong right now.** Interrupting
  someone to tell them nothing is wrong is worse than staying quiet.

### It finds things it used to miss

- **A window with only a sliver left on screen is now brought back.** A settings
  window kept 40 points of its width in view and unstray called it fine. The
  question is now whether enough of a window is left to still be a window.
- **It notices when you click an app and nothing comes up**, asks the app to show
  you something, and usually you never find out there was a problem.
- **Hidden, shrunk, frozen and unmovable windows are handled**, not only the ones
  parked off the edge.
- **A rescue of several apps at once no longer skips one.** Bringing an app
  forward can carry you to another screenful, and until that finishes the Mac
  reports no windows at all. unstray waited a fixed fraction of a second and
  sometimes lost the race — which looked like nothing happening. It now waits for
  the windows themselves.

### When it fixes something, it tells you the truth

- **A repair can no longer report an all-clear it never earned.** Pressing "Show
  me how to force it to quit" opened Activity Monitor and then said everything
  was where it should be, while the app was still frozen. That was this app's
  founding failure, committed by this app. One place now decides what the panel
  says.
- **The log records what a repair actually did** — changed it, asked for it,
  handed it to you, or failed — instead of one word that meant five things.
- **A repair no longer leaves an untitled document behind** for you to be asked
  about later.
- **A missing permission is fixed that would have stopped one rescue working on
  every Mac except the one it was built on.**

### The panel

- **It no longer runs off the edge of the screen** and gets cut off mid-sentence.
  A bad look for an app about things ending up where you cannot read them.
- **The picture of your screens is no longer tiny on a one-screen Mac.**
- **A panel that opened itself always has a visible way to close it.**

### Also

- **The app has an icon.** Version 0.1 shipped with none at all, so it appeared
  as a blank tile in the Dock and in your Applications folder.
- **A "Buy me a coffee" link in the footer**, shown only when nothing is wrong.
  The app is free and stays free.

## 0.1 — 2026-07-28

First public version.

- Notices when macOS has turned off one of the three settings that decide
  whether it can lose your windows, and explains each one in plain words.
- Fixes them on request, saying up front when a fix needs you to log out.
- Finds windows parked where no screen can reach — usually after a monitor is
  unplugged — and brings them back to the screen you are using.
- Finds windows with only an unusable sliver left on a screen, and slides them
  fully back into view.
- A rescue key (⌥⌘R, or ⌥⇧⌘R / ⌥⇧⌘W if something else already uses it) that
  gathers whatever app you are fighting with onto your screen.
- Checks again by itself after a macOS update, since a major upgrade or a
  migration is a sensible moment to look.
- Lives in the menu bar, starts with your Mac, and stays quiet until needed.
