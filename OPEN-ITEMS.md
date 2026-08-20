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


## The GitHub Sponsors link in the README was dead

2026-08-19. The Support section pointed at `github.com/sponsors/initiator1`.
That page does not exist — GitHub Sponsors is not switched on for the account,
so the URL silently redirects to the profile page. It has been replaced with
`ko-fi.com/initiatorworks`, which was opened in a browser the same day and
renders "Buy Douglas a Coffee".

Two things follow, and neither is done:

- **Check the same link in the other repos.** Any README or site that offers
  GitHub Sponsors for `initiator1` has the same dead destination.
- **Decide whether to switch GitHub Sponsors on at all.** Ko-fi now collects
  for four apps. A second, empty donation route only creates more links to
  check. Douglas's call.

## The Ko-fi tag records nothing until GA4 is connected

2026-08-20. Every Ko-fi link in this repo carries `?app=unstray`, so the one
page can tell which of the four apps sent a visitor. **Nobody can read that
today.** Ko-fi exposes the parameter only through its Google Analytics 4
integration, and that integration needs a paid Ko-fi Contributor account. The
tag costs nothing and starts working the day Douglas connects GA4. Until then
do not report click counts from it — there are none to report.

The value is `unstray` and it must stay that in every file. RedButtonQuit,
Time Announcer and Portmanager carry their own names the same way.

## The Ko-fi link ships only when unstray is next built for release

2026-08-19. The link is on `main` and verified in a local build. The copy in
`/Applications` is the notarized v0.1 and does not have it. Local builds are
not notarized, so that copy was deliberately left alone. Whoever cuts the next
release picks the link up with it.
