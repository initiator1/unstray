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
| `appNotResponding` | "\<app\> has stopped answering." plus "It usually recovers on its own within a minute." | the second line is the urgent one — after an hour it is not stale but **false**, telling him to wait a minute for a recovery that already failed for sixty |
| `titleBarOutOfReach` | "You can see \<app\>, but you cannot move it." | fine at any age; probably needs nothing |

The machinery is small and the wording is the only blocker. The age is already
recorded — `OpenProblems.Seen.seenAt` — and `WindowScan.unusable(appName:kind:)`
is the single place every one of these strings is built, so the switch belongs
there and nowhere else. Not built yet: a mechanism with placeholder sentences in
it would be a stub, and this repo does not ship those.

