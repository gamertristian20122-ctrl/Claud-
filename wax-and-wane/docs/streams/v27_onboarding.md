# v2.7 stream `onboarding`: shown the controls by animation, learn by doing, told once

Branch `v27/onboarding`. A real player (the owner's friend) tried 2.6: the game is fun, but "learning the tutorial is
not great", "there should be an animation or something telling you the controls first", and the teaching is "kind of
redundant". This stream gives a new save slot an animated, learn-by-doing controls primer before the first fight and
takes every other teaching text down to one just-in-time showing per slot.

## The judge (written first, run on 2.6 before any change)

`--autotest --primercheck` (`scripts/primer_check.gd`, `PrimerCheck`) plays a brand-new player's first three minutes
on each device: a fresh slot in memory (it never writes the save), the title's Light the wick -> New candle ->
Midnight -> 4 floors -> the run (seed 2701, so every device and every build sees the same house), the story card
(Begin as soon as it takes a press), the primer with simulated input when there is one (thumbs on the screen, keys, a
gamepad: real input events through the HUD), then the play-test bot to the first room's first kill and on to minute
three (4x after the kill). It polls the HUD, so it works on any build: every hint, every card's teaching lines (one
card = one text), every chalk drawing (once a run) and every primer step is logged with what it teaches; a **repeat**
is a text that teaches nothing new. Run it with its own profile:
`XDG_DATA_HOME=/tmp/x godot --headless --path . -- --autotest --primercheck [--device=touch|keyboard|gamepad]`.

## BEFORE: every teaching moment of the first three minutes (2.6, touch, in order)

| When | Where | What it says | Duplicate of |
|---|---|---|---|
| title | Candle Box (`title.gd`) | "Flare Up - Burn 2 minutes of wax to blaze for 3 seconds." | (the candle picker: kept) |
| 0:03 | story card "12:00 AM" (`world._intro`) | 4 story lines + "Your wax is your life - and your time." + "Every hit melts you. Wax drippings mend you." + "Left thumb moves. Right thumb aims and fires. Bomb: the right button." (keys: "WASD moves. The arrow keys or the mouse fire.", pad: "Left stick moves. ...") | |
| 0:03 | 6 chalk drawings on the start room floor (`chalk.gd`) | WAX = TIME, MOVE, AIM+FIRE, BOMB, KEEPSAKE (Tallow has none yet), SPECIAL | the card (4 of 6) |
| 0:03 | ghost sticks (touch, runs 1-3, `hud._draw_ghosts`) | two faint rings at the thumb spots | the card + chalk (passive) |
| 0:04 | hint, 8 s (`world._intro` Begin) | "Left thumb: move   Right thumb: aim + shoot   Bomb: right button" (keys/pad add "SHIFT: Flare Up" / "LT: Flare Up") | the card AND the chalk |
| 0:05 | hint (every treasure room, every run) | "Choose one relic. The other will crumble." | itself, in the next treasure room |
| 0:11 | hint (once) | "That wall is cracked and seeping wax... a bomb might open it" | |
| 0:11 | hint, 6 s, first fight (`moves.gd`, a candle's first 2 runs) | "Big round button: Flare Up. Burn 2 minutes of wax to blaze for 3 seconds." | the chalk SPECIAL + the title |
| 1:22 | hint (special room, 2 per kind) | "Walk into the box to wind it: 3 coins a turn." | |
| 1:51 | hint (first hit, 2 per slot) | "Your wax spilled! Grab the warm drops before they cool" | itself at 2:19 |
| 1:53 | hint (floor 2, every omen, every time) | "Long Night: A bigger floor with two treasure rooms" | |
| 1:55 | hint (marked foe, 2 per slot) | "A marked foe glows: tougher, but it pays out" | itself (keys run) |
| 2:02 | hint (2 per slot) | "Kill quickly to keep the streak: Kindling pours minutes back in" | itself |
| later | keepsake: banner + "Keepsake: clear rooms to fill its pips, then tap its button" (2 per slot), "<name> is ready" (every charge) | | |
| run 2-3 | floor 1: the controls hint again (7 s) + the chalk again + the move hint again (run 2) | | runs before |

So in the first five seconds the controls are told three times (card, floor, hint) and the special move twice more
before the first fight; most hints show twice per slot and the treasure / omen / keepsake-ready lines every time.

BEFORE numbers (`--primercheck`, seed 2701; game seconds, simulated input, no reading time; reading = words shown
before the first kill at about 200 words a minute):

| Device | Light the wick -> first kill | Words before it (reading) | Teaching texts in 3:00 | Repeats | Re-told lessons |
|---|---|---|---|---|---|
| touch | 18.6 s | 120 (~36 s) | 18 | 8 | 10 |
| keys | 17.3 s | 115 (~35 s) | 16 | 6 | 9 |
| gamepad | 17.4 s | 114 (~35 s) | 17 | 6 | 9 |
