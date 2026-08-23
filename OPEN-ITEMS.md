# Open items

Things known to be unfinished or unwatched. Add a date and enough context to act
without the conversation that found it.

## A true problem can keep moment-specific wording for too long — DONE 2026-08-22

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

**Closed 2026-08-22.** Douglas approved the later sentences from the council
draft. Built as `ProblemAge.swift`: first sightings survive re-recording (the
watcher re-records on every click, so the age used to reset each time), and the
frozen and empty-app findings switch to age-carrying wording at 120 s and 300 s.
Nothing is dropped and no timer exists. The frozen-app button now opens the
Force Quit window. Ships in 0.3.


## The Sponsor button needs two halves, and both are silent when missing

2026-08-20, **resolved the same day.** The button on a GitHub repo page needs a
funding link GitHub has recorded AND the repo's own Sponsorships feature ticked
on, in Settings > General > Features. Either half alone renders nothing and
errors nothing. Douglas ticked the box; the public page now shows "Sponsor this
project" linking to `https://ko-fi.com/initiatorworks?app=unstray`, verified
logged out.

That was the third shape of one failure in a week, after `ko-fi.com/initiator1`
and the inert `github: initiator1` key. Kept here because the next agent will
otherwise re-derive it: **a populated `fundingLinks` is not evidence a visitor
sees anything.** Check the public page.

Two facts about checking, which differ by host and cost an hour to rediscover:

- **GitHub pages: `curl` works.** `curl -sL <repo-url> | grep -i "sponsor this
  project"` is a reliable test.
- **Ko-fi pages: `curl` is useless.** Cloudflare answers 403 whether the page
  exists or not, so a dead link passes a scripted check. Use a browser, and
  confirm the tip form renders rather than matching the page title.

A newly added FUNDING.yml is not recorded straight away, so an empty
`fundingLinks` does not mean the file is wrong. The split across the four repos
went by when the file was **first added**, not last changed: unstray
(2026-07-28) and redbuttonquit (2026-08-12) were recorded, while portmanager
and timeannouncer, both added that morning, were still empty four hours later
with correct files in place. Do not "fix" a correct file because the API has
not caught up.

## The next release needs a version number — DONE 2026-08-22 (0.2)

2026-08-20. `Info.plist` still says 0.1 and the changelog section is headed
"Unreleased". The diff since the released v0.1 is 35 commits, most of them
removing false accusations, plus the first working icon — that argues for
**0.2**, not 0.1.1. Douglas picks the number.

## v0.2 released — 2026-08-22

Notarized, staple validated on the downloaded zip, `v0.2` annotated on `main`
(28f84b1), `releases/latest` serves it. `git describe` works again. The v0.1
tag below stops mattering from here.

## The v0.1 tag is orphaned from main

2026-08-20. `git tag v0.1` points at 28b70b8, which is **not** an ancestor of
`main`. History was rewritten after the release, so the tagged commit was
replaced by 17c30cf — same subject, same timestamp, identical tree, different
sha. Any `git log v0.1..main` therefore lists the whole project, including
v0.1's own features, which is how the previous count of "69 commits since 0.1"
was reached. **The real release point on main is 17c30cf.**

**Decided 2026-08-20: leave it alone.** Deleting or force-moving a tag that
carries a published GitHub release converts that release to a draft, and v0.1
has a live `unstray-0.1.zip` with real downloads. That is a real risk to the
only public artifact, taken to repair a reference that expires on its own: once
`v0.2` is tagged correctly on `main`, every diff anchors to v0.2, `git describe`
starts working, and v0.1 stops being consulted. Reach is 0 stars and 0 forks, so
nobody outside this machine holds the tag.

Revisit only if v0.2 slips past about a month, or if the repo gains forks — in
which case the answer hardens to never touch it.

Until v0.2 ships, diff against 17c30cf, never against the tag. `tag-release.sh`
now refuses to create a tag that is not an ancestor of main.

## The changelog does not describe the next release — DONE 2026-08-20

2026-08-20. Sixty-nine commits sit between the v0.1 tag and `main`, and about
twenty of them change what a person sees: headless browsers no longer accused,
starting apps no longer accused, windows with an unusable sliver now rescued,
hidden and frozen windows handled, the panel no longer cropped at a screen
edge, and several strings rewritten to stop predicting symptoms nobody has.

**The Unreleased section lists one of them — the coffee link.** Anyone reading
the changelog would think the next version is a donate button. This is the
main thing standing between now and a release build, and it is writing, not
engineering. The commit subjects are already in the plain voice and are a
usable draft source: `git log v0.1..main`.

Also needs deciding at the same time: the version number. `Info.plist` still
says 0.1, and the size of this diff argues for 0.2 rather than 0.1.1.

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
integration. Until Douglas connects GA4 there are no click counts to report —
none, not few.

**Correction, same day.** This entry first said GA4 "needs a paid Ko-fi
Contributor account", which was repeated from another session and is wrong.
Checked live on ko-fi.com and help.ko-fi.com on 2026-08-20:

- **Contributor is not a subscription and has no fixed price.** It is a toggle
  in Settings → Payment that shares **5% of tip income** with Ko-fi. Five
  percent of nothing is nothing. It can be switched off at any time.
- Contributor is what unlocks Google Analytics, along with supporter-only
  content, scheduled posts, a shorter page name and a custom theme colour.
- With Contributor off, tips carry a **0%** service fee, which is why it was
  deliberately left off. Memberships, shop sales and commissions are 5%
  regardless.
- **Ko-fi Gold is the paid tier: $12/month for 0% on everything.** It only
  pays for itself above roughly $240/month in tips. Ko-fi's own page now says
  "You no longer need Ko-fi Gold."

So the real question is not what to spend. It is whether 5% of future tips is
worth per-app attribution, and it is reversible either way.

**2026-08-22: Douglas says Contributor is already on.** Not verified — the
toggle is in his Ko-fi settings and no agent can see it from outside. If it is
on, the remaining step for the `?app=` tags to produce a number is pasting a
Google Analytics 4 Measurement ID into Ko-fi's page settings. Nothing in this
repo depends on either.

## The Ko-fi link ships only when unstray is next built for release — DONE 2026-08-22

v0.2 is tagged, notarized and pushed with the link in it.

The value is `unstray` and it must stay that in every file. RedButtonQuit,
Time Announcer and Portmanager carry their own names the same way.

## The Ko-fi link ships only when unstray is next built for release

2026-08-19. The link is on `main` and verified in a local build. The copy in
`/Applications` is the notarized v0.1 and does not have it. Local builds are
not notarized, so that copy was deliberately left alone. Whoever cuts the next
release picks the link up with it.
