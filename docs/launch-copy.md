# Launch copy

Drafts to edit, not to paste unread. Everything factual here is sourced in
`docs/launch-plan.md`.

**Do not claim a macOS update changed the setting.** It did not — it was changed
by hand, as a guess at fixing the disappearing windows. The app can say a setting
is wrong and what that does; it cannot say what changed it. Inventing a cause is
the one thing that would discredit the whole project.

---

## Show HN

**Title** (80 char limit — this is 76):

> Show HN: Unstray – macOS loses your windows, Apple hasn't fixed it, so I did

Alternatives if that reads too sharp:

> Show HN: Unstray – finds Mac windows that macOS has hidden from you
> Show HN: Unstray – a Mac utility that explains why your window vanished

**First comment** (post immediately after submitting — HN convention, and it is
where the story actually lands):

> I have three displays, and windows kept disappearing. At some point I went
> into System Settings and turned off "Displays have separate Spaces", because it
> sounded like it might help. It didn't — it made things worse, and it also meant
> two of my monitors went black whenever I made a video full screen.
>
> Months later I had completely forgotten changing it. When I finally looked
> properly, 66 of my 71 open windows were on a desktop I wasn't looking at, and
> five were parked at coordinates like (-12000, 12485) — where a monitor used to
> be before I unplugged it.
>
> Nothing in macOS connects that setting to those symptoms. That's the part I
> found worth fixing: not the setting itself, but that a reasonable guess can
> quietly wreck your window management and leave no trail back.
>
> Underneath there are three open Apple bugs. FB21087054: clicking an app's
> Dock icon activates it but doesn't bring its window forward — Apple has
> acknowledged this. FB18016497: windows reopen on whatever desktop they were
> last on. FB11974786: the API for "bring all of an app's windows forward"
> hasn't worked since macOS 10.15, per Apple's own engineers. In February
> Apple's release notes claimed a fix for a window bug and then quietly edited
> it back to "known issue" the same night.
>
> Unstray watches the three settings that decide whether macOS can lose your
> windows, re-checks after an OS update, finds windows sitting outside every
> display, and brings them back. ⌥⌘R gathers whatever app you're fighting with
> onto the screen you're looking at.
>
> The part I actually cared about is the writing. Every string is written for
> someone who doesn't know the words "window", "Space", or "off-screen". It
> never shows a coordinate. It says whose fault it is:
>
> "That is not your fault, and nothing is broken. A setting got turned off, and
> while it is off your Mac treats all of your screens as one big screen."
>
> Two implementation notes that might interest people here:
>
> - There is no public API to move a window to another Space. yabai's scripting
>   addition needs SIP off plus an NVRAM boot-arg on Apple Silicon now, and
>   Hammerspoon's equivalent has been broken upstream since Sonoma 14.5. So
>   Unstray moves *you* to the window instead of the window to you — public
>   APIs only, nothing that breaks on macOS 27.
> - `NSRunningApplication.activate` silently does nothing when called from a
>   menu-bar app, because macOS 14 made activation cooperative and a menu-bar
>   app is never frontmost. The one call that still works is
>   `SetFrontProcessWithOptions`, which Swift refuses to import because it
>   predates 10.9. There is a nine-line C shim in the repo for exactly this.
>
> MIT, no network calls of any kind, no analytics. Feedback welcome —
> especially from anyone on a single display, since I built this on three.

**Timing:** weekday, 8–10am US Eastern. Answer every comment for the first few
hours; that matters more than the post.

**Do not:** ask for upvotes, cross-post the link anywhere for the first day, or
argue with anyone who says Rectangle already does this (it doesn't, but arguing
reads badly — just explain the difference once).

---

## r/macapps

Needs 10 local karma first, and self-promotion is capped at one post per 30
days, so do not waste the slot on a weak week.

**Title:** Unstray — free, open source: finds Mac windows that macOS has hidden

Shorter body than HN. Lead with the symptom, not the architecture. Include the
screenshot. Say "free and open source, no upsell" explicitly — that subreddit
is sceptical of launches by default and the phrase does real work.

---

## 9to5Mac Indie App Spotlight

Email `michaelb@9to5mac.com`. Short, no attachment bigger than a screenshot.

> Subject: Indie App Spotlight — Unstray, a free Mac utility for windows macOS
> has hidden
>
> Hi Michael,
>
> Unstray is a free, open-source menu-bar app that finds windows macOS has lost
> — stranded off-screen after a monitor is unplugged, or hidden by a system
> setting whose effects are impossible to trace back to it — and brings them
> back.
>
> The angle that might suit the column: it's a direct response to three
> unfixed Apple bugs (FB21087054, FB18016497, FB11974786), and everything it
> says is written for someone who has never really used a computer. It never
> shows a coordinate or an error code; it explains what happened and makes clear
> it isn't the reader's fault.
>
> MIT licensed, no network calls, no analytics, no paid tier.
>
> [link] — happy to answer anything.

---

## The one-liner

For the repo description, and anywhere with a character limit:

> Finds Mac windows that macOS has hidden, and explains what happened.
