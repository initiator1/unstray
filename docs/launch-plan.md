# Launch Plan

What it takes to put `unstray` in front of the public, and why the strategy is
what it is. Written 2026-07-26.

## The recommendation, in one line

**Open-source it under MIT, free, distributed as a notarized download from
GitHub Releases plus a Homebrew Cask. Do not try to sell it.**

## Why not the Mac App Store

Not a choice — it is closed. Apple DTS engineer Quinn confirmed in
[October 2025](https://developer.apple.com/forums/thread/805556), answering a
developer whose window-manager app was rejected, that `AXUIElementCreateApplication`
in a sandbox is a flat "No", and that "your only path forward here is to
directly distribute your app using Developer ID signing."

Magnet, Divvy and BetterSnapTool are on the Store only because they were
approved before sandboxing became mandatory (~2011) and were grandfathered.
There is no temporary-exception entitlement for this any more. An
[open policy complaint](https://developer.apple.com/forums/thread/805780) from
October 2025 asking Apple for a fair path has no response.

## Why not paid

The disclosed comparables are all *feature-rich* tools with broad appeal:
Lunar at ~$7k/month, Xnapper at ~$4-6k/month before its $150k exit. Nothing as
narrow as "fixes windows you cannot find" has a published revenue figure
anywhere — that absence is itself the finding.

Setapp explicitly rejects apps for
["narrow or niche use case that Setapp users do not request"](https://docs.setapp.com/docs/review-guidelines)
(guidelines revised Oct 2025). That criterion is aimed squarely at a
single-purpose utility like this one.

Meanwhile the reputation case is unusually strong, because this app is a
*documented response to unfixed Apple bugs* — FB21087054, FB18016497, and Apple
[silently reverting a fix claim](https://9to5mac.com/2026/02/11/macos-tahoe-26-3-fixes-two-annoying-design-problems/)
in the 26.3 release notes the same night it was published. That is a story.
A utility is not.

## Blockers — must be done before anyone else runs this

- [ ] **Notarize.** `./build.sh --notarize`. Needs a one-time
      `xcrun notarytool store-credentials unstray --apple-id ... --team-id ...`
      with an app-specific password from appleid.apple.com. Without this,
      macOS 26 hard-blocks the app; the right-click bypass was removed in
      Sequoia. Homebrew also
      [removes non-notarized casks](https://workbrew.com/blog/homebrew-5-0-0)
      from the official tap in **September 2026**.
- [~] **Single-display Mac.** The layout bug this exposed is fixed and covered
      by tests, and the copy is verified for 1/2/3 screens. Still wants one real
      run on a one-screen Mac before launch — the maths is right, but nobody has
      looked at it.
- [x] **Byline decided.** Copyright INITIATOR LLC (Delaware, good standing since
      2020), maintained publicly by [@initiator1](https://github.com/initiator1).
      The entity is a liability shield, not a privacy measure — it is public
      record either way — and it gives future projects one brand to accumulate
      under, which a personal name cannot be sold with.
- [x] **Docs sanitised.** Internal references removed; the AI build contract is
      no longer tracked.
- [x] **Uninstall instructions in the README.** The app takes Accessibility
      permission, registers a login item, and writes `~/.unstray/`. Someone who
      wants it gone must be told all three. This is a trust issue as much as a
      support one.

## Should do before launch

- [x] Unit tests for the pure logic — 33 checks covering reachability, window
      filtering, settings interpretation, severity order, version drift,
      headline wording, and diagram layout. `./run-tests.sh`.
- [ ] Surface repair failures. `repair()` returns a Bool that is logged but
      never shown; if a fix fails the same panel simply reappears.
- [x] Version number visible in the UI, and a `CHANGELOG.md`.
- [x] A bug-report path — a GitHub Issues link is enough.
- [x] A privacy statement: no network calls, one local file, here is
      how to delete it. (Verified true: no networking code exists at all.)
- [x] README note that Bartender/Ice hide menu-bar icons — this will otherwise
      be the single most common "it didn't install" report.
- [ ] A screenshot or short GIF. Strangers decide in seconds.

## Can wait

- Sparkle auto-updates (matters once there are real users)
- Dynamic Type support
- Localisation
- A light-mode palette, or a stated decision that the panel is always dark

## Launch sequence

1. **Public GitHub repo, MIT.** Notarized `.dmg` attached to a tagged release.
2. **Show HN.** Median is 2 points, but Mac menu-bar tools do break out —
   [Badgeify: 118 points](https://news.ycombinator.com/item?id=43620471) (Apr
   2025), [Itsyhome: 57](https://news.ycombinator.com/item?id=46967898) (Feb
   2026). Lead with the Apple bug, not the app.
3. **r/macapps.** Needs 10 local karma before posting; self-promotion is capped
   at once per 30 days, so do not waste the slot.
4. **9to5Mac Indie App Spotlight** — `michaelb@9to5mac.com`. An active weekly
   column that covers exactly this kind of app.
5. **Homebrew Cask** once there is a notarized, versioned release to point at.

**Skip Product Hunt.** The 2026 consensus is saturation and pay-to-play.

## The pitch

> macOS has a bug where clicking an app's icon doesn't bring its window back.
> Apple has known since 2025 and hasn't fixed it. I built the fix — and it
> explains what happened in words a person who has never used a computer can
> understand.

## Legal

No lawsuit, cease-and-desist, or ban was found against any indie developer for
Accessibility-API window manipulation. The category is a decade old. MIT's
AS-IS clause is the standard protection and is already in place.

Citing your own Apple Feedback numbers publicly is normalised —
[Open Radar](https://openradar.appspot.com/faq) exists for it, and
[public FB repos](https://github.com/structuredpath/AppleBugReports) operate
unchallenged.
