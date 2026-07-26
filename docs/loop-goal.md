# The Loop Goal

Self-directed build contract for `foremac`. I re-read this at the top of every
iteration. It is the standing definition of "done" so I do not drift, and so I
do not stop early because a phase boundary felt like a stopping point.

## The mission

Build a small macOS app that **notices when the Mac has hidden something from
you, brings it back, and explains what happened in words a person who has barely
used a computer can understand.**

Not a window manager. Not a tiling tool. There are eleven of those and they all
failed the person we are building for. This is a **repair-and-explain** tool.

## Why it exists (do not lose this)

Apple has open, unfixed bugs — FB21087054 (clicking an app's picture in the bar
at the bottom does nothing) and FB18016497 (things reopen on the wrong screenful).
macOS silently turned off `spans-displays` during a Tahoe update, which blacked
out two monitors and stranded five windows at coordinates no screen can reach.
BOSS did not do any of this. The Mac did it to him, quietly, and gave him no way
to find out why.

**The settings will drift again on the next macOS update.** That is the recurring
job. The app exists so that when it happens, nobody has to remember this
conversation or ask an AI to run `defaults read`.

## The loop, each iteration

1. **Plan exactly one thing.** One coherent, shippable unit. Not a phase, not a
   milestone — one thing.
2. **Spend real effort on the UI/UX before writing code.** Per BOSS's explicit
   ask. Generate 2–3 interaction models, compare, pick, and write down *why*.
   The first technically convenient implementation is not the answer.
3. **Implement it.**
4. **Verify it visually.** Screenshot the actual rendered app on the actual
   screen. Source review is not verification for UI work.
5. **Commit** — one logical unit, conventional commit message.
6. **Update the docs** that changed (CLAUDE.md / SPEC.md / PLAN.md / this file).
7. **Decide honestly**: is it done, or is there a next thing? If done, stop.

## Design constraints (non-negotiable)

- **Plain language is the product**, not a coat of paint. Every string passes
  `docs/plain-language.md`. If a sentence needs the word "window", rewrite it.
- **Never show a number a person cannot use.** No coordinates, no window IDs,
  no error codes, no FB numbers on screen. They go in the log.
- **Say whose fault it is.** "This is a bug in macOS. It is not your fault."
- **Public and deprecated APIs only.** No private APIs, no SIP disabling, no
  NVRAM boot-args, no scripting additions. The whole point is surviving macOS 27.
- **Every UI element delivers what its label promises.** No stubs, no
  placeholders, no "coming soon". If it is not built, it does not ship.
- **Dark theme, Outfit font** (100 large / 200 medium / 300 small).
- **Never auto-apply anything that needs a logout** without saying so first.
- **Idle at zero cost.** No polling loops, no busy timers.

## The bar is OUTSTANDING, not "satisfied"

BOSS corrected this explicitly. "Satisfied" is the point where I stop finding
faults. "Outstanding" is a different and much higher bar, and it is the one that
applies:

- **Satisfied** = the checkboxes are ticked and nothing is broken.
- **Outstanding** = a person who has never used a computer opens this, feels
  *relieved*, and understands something about their Mac they did not understand
  before. A stranger would screenshot it and send it to a friend.

Practical consequences — I do not get to skip these:

- The plain-language pass is not "good enough once it is jargon-free". Every
  sentence gets read aloud and rewritten until it lands.
- Visual polish is a requirement, not a bonus: real typography, real spacing,
  real hierarchy, motion where it explains something. No default-looking
  SwiftUI panel with system-blue buttons.
- Empty/healthy state gets *more* design care than the error state, because it
  is what BOSS sees 99% of the time.
- If a step is technically correct but feels flat, it is not done. Redo it.
- Never ship "it works" as the final answer. Works is the floor.

## What "genuinely done and shippable" means

All of these true:

- [x] Checks the three load-bearing settings and reports drift in plain language
- [x] Fixes them on request, warning about logout *before* the button is pressed
- [x] Finds things that are open but unreachable, and brings them back
- [x] A rescue hotkey that works from a background process
      (`SetFrontProcessWithOptions`, since cooperative activation silently fails)
- [x] Re-checks automatically after a macOS update — the recurring job
- [x] Every explanation passes the read-aloud test in `docs/plain-language.md`
- [x] Visually verified with screenshots at the real size on the real screen
- [x] Menu-bar app, launches at login, invisible until needed
- [x] Writes JSONL where Aria can read it
- [x] CLAUDE.md, SPEC.md, PLAN.md written and current
- [x] Git history: small commits, each one revertable alone

## Stop conditions

**Stop when** every box above is ticked and the app has been used once, for real,
end to end.

**Stop early and ask** only if: something needs BOSS's taste or money, an action
is irreversible or outward-facing, or the same approach has failed three times
(then write ISSUE.md).

**Do not stop for**: "phase done, continue?" — continue. Commits, restarts,
rebuilds, installs — just do them.

## The test that matters

Read any screen of this app out loud to someone who has never used a computer.

If they can say back what happened and what to press, it passes.
If they ask "what's a window?" — rewrite it.


---

## Outcome (2026-07-26)

Every box above is ticked and verified on the real machine, not in theory.

The loop earned its keep on the last iteration: the rescue hotkey was logged as
firing but never moved anything, because `gatherFrontmostApp()` asked for the
frontmost app *after* macOS had made foremac frontmost. The engine test passed
while the feature was broken end to end — only pressing the actual keys found
it. Fixed with `ActivityWatch`.

Bugs found by using the thing rather than reading it:
1. Ad-hoc signing silently revoked Accessibility on every rebuild
2. Panels vanished on a stray click, twice (BOSS hit both)
3. `recheck()` short-circuited without permission, hiding settings problems
4. The icon read as a smiley face
5. The rescue hotkey rescued foremac itself

Stopping here. The app is done.
