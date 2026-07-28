# Plain Language Rules

Every word `unstray` shows a person must pass these rules. The reader may be
using a computer for close to the first time. They are not stupid — they simply
have not been taught the words yet, and there is no reason they should have been.

## The reader we write for

A person who:

- knows what a screen, a mouse, and a picture on the screen are
- does **not** know the words: window, Space, Desktop, Mission Control, focus,
  activate, minimize, display bounds, coordinates, daemon, API, accessibility
- will believe the computer is broken, or that they broke it, when something
  disappears
- wants their thing back, and wants to know it was not their fault

## The rules

1. **Never use a word the reader might not know without showing it first.**
   Prefer the everyday word. If a technical word is unavoidable because it
   appears on a real button they must click, say the plain thing first and then
   name the button in quotes.

2. **Say what happened, not what is true.** "Your window is off-screen" is a
   fact about geometry. "Your Notes are still open — they just moved to where
   your other monitor used to be" is what happened.

3. **Say whose fault it is, out loud.** These are Apple's bugs. The reader will
   assume they did something wrong. Tell them they did not. This is not
   politeness; it is the single most useful sentence we can write.

4. **One idea per sentence. One sentence per line where possible.**
   Short lines are easier to read when someone is frustrated.

5. **Always end with the action.** Every explanation finishes with a button
   whose label is a verb the reader already knows: "Bring it back",
   "Fix this for me", "Show me".

6. **Never show a number the reader cannot use.** Coordinates, window IDs,
   process IDs, error codes belong in the log file, never on screen. `-12000`
   means nothing to anyone.

7. **Do not apologise on Apple's behalf and do not editorialise.** State it
   flatly and move on. "This is a bug in macOS. It is not your fault." Then fix
   it.

8. **Never promise what we cannot do.** If the fix needs the person to log out,
   say so before they press the button, not after.

## Words we never show on screen

| Never write | Write instead |
|---|---|
| ~~window~~ | **Say "window".** Banning it pushed every string toward "things", which is vaguer and reads as machine-written. Name the actual app where you can ("Notes is open"), and use "window" plainly where you must. |
| Space / Desktop (the virtual kind) | another screenful / a different set of windows |
| Mission Control | the settings page (and then quote the exact button name) |
| activate / focus / frontmost | bring it to the front / put it in front of the others |
| minimize | shrink it down to the bar at the bottom |
| off-screen / display bounds | somewhere the screen cannot reach / where your other monitor used to be |
| the Dock | the bar of pictures at the bottom of your screen (first time only, then "the bar at the bottom") |
| full screen | made to fill the whole screen |
| accessibility permission | permission to move other apps' windows |
| daemon / background process / API | (never mentioned at all) |
| toggle / enable / disable | turn on / turn off |

## Worked examples

These are the three real problems found on this machine. Each is written twice.

### The black displays

**Not this:**
> `spans-displays` is set to 1, so "Displays have separate Spaces" is disabled.
> Full-screening an app on one display causes the other displays to show the
> desktop background only.

**This:**
> **Your other two monitors go black when you make a video full screen.**
>
> That is not your fault, and nothing is broken.
>
> There is a setting in macOS that was turned off. While it is off, your Mac
> treats all three of your monitors as one single screen. So when you make a
> video fill the whole screen, your Mac thinks the whole screen means all three
> monitors — and it empties the other two to get out of the way.
>
> Turning that setting back on lets each monitor keep its own windows.
>
> One thing first: your Mac has to log you out and back in for this to take
> effect. Save anything you are working on.
>
> [ Fix this for me ]  [ Not now ]

### The window that will not come back

**Not this:**
> 5 windows have frame origins outside the union of all connected display
> bounds. Rescue will reposition them to the display under the cursor.

**This:**
> **5 things are open but you cannot see them.**
>
> You had another monitor plugged in at some point. When you unplugged it, your
> Mac left some windows sitting where that monitor used to be — off the edge of
> everything, where no screen can reach.
>
> They are still open. Nothing was lost. They are just parked somewhere you
> cannot look.
>
> [ Bring them back ]

### Clicking the picture and nothing happening

**Not this:**
> macOS 26 regression FB21087054: cooperative activation via yieldActivation
> intermittently fails to raise windows on Dock icon click.

**This:**
> **You clicked its picture at the bottom and nothing happened.**
>
> This is a bug in macOS itself. Apple knows about it and has not fixed it yet.
> You did not do anything wrong, and clicking more times will not help.
>
> The app really is open. Your Mac just forgot to put it in front of everything
> else.
>
> Press **⌥⌘R** any time this happens and I will go find it and put it in front
> of you.
>
> [ Show me how ]

## The test

Read it out loud to someone who has never used a computer.

If they can say back what happened and what they should press, it passes.
If they ask "what's a window?" — rewrite it.


## Two rules learned the hard way

**Never describe a symptom the person cannot be having.** "Your other screens go
black" is false on a one-screen Mac. Check the machine's actual state before
asserting anything about it — a wrong claim costs more trust than a vague one.

**Do not predict one either.** The replacement, "Your screens will go black when
you plug in another one", was equally untrue: the setting only bites if they add a
screen AND then make something full screen. A headline should state what IS —
"Your Mac is set to treat all your screens as one" — and let the explanation
handle what might follow, in words that stay conditional ("could blank", not
"will blank"). Alarm about a hypothetical is the same failure as alarm about a
fiction.

**Do not offer reassurance nobody needs.** "That is not your fault" belongs on a
window that has vanished, where a person really does assume they broke something.
On a settings toggle it is unearned and reads as a script. Save it for when it is
true.
