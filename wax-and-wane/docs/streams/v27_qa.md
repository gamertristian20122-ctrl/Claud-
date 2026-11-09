# Stream: v27/qa (Wax & Wane 2.7) - the bugs a real player would hit

A friend of the owner played 2.6 and found "a few bugs here and there" but could not say what. Six streams had
been merged in a day with light testing (v2.1 slots + levels, v2.2 night length + areas, v2.3 special moves,
v2.4 boss intros, v2.5 the diary, v2.6 GUI + feel). This stream ran every self-check and tour, played the bot
through the combinations, read the code where the streams meet, and hit the game with random presses at random
moments (the "monkey") to find what a person would trip over. Branch `v27/qa`. No version bump, no APK.

## The checks this stream adds

- **`--autotest --qacheck`** (`scripts/qa_check.gd`): one probe per bug fixed here, plus regression probes for the
  risky meeting points that turned out fine (Android's Back over every layer, Quick restart in Tonight's Candle
  and in a 7-floor night). Headless it sets a 384x216 screen; with a window it takes screenshots
  (`xvfb-run ... --resolution 1536x864 -- --autotest --qacheck --shots=/abs/dir`). Exit code 1 on a FAIL.
- **`--playtest --monkey`** (`scripts/qa_monkey.gd`): while the bot plays, a person's presses land on top of it
  every 0.3-1.4 s: Android's Back, Esc / Start, M / the pad's Back (the map), the special move, a bomb, the
  keepsake, taps on II / the minimap, the app losing focus, and in the pause menu Resume, Map, Settings or the
  Journal. A watchdog prints `[monkey] PROBLEM` when three closing presses in a row (Back, Esc, B) change
  nothing, the game stays paused for 20 s, the house stays paused with no menu or card, or time stays slowed.
- **`--playtest --settings=key:value,...`**: any `Game.settings` for a bot run (`swap_sticks:true`,
  `reduce_motion:true`, `aim:auto`, `magnet:false`...). With `--device=touch|gamepad` (already read by Controls)
  it covers the v2.6 settings in bot runs.

## Findings

Severity: **major** = a player notices and it looks broken; **minor** = cosmetic or rare; **test** = a self-check
that cried wolf (it hid real results).

| # | What a player sees | Where | How to reproduce | Severity | Fixed? | Checked by |
|---|---|---|---|---|---|---|
| 1 | Pause right as Tallow is hit (or a guardian falls) and every menu crawls: the pause menu pops in slowly, Settings / the Journal lag, **Save & quit's screen fade takes ~9 s** (looks like a hang) | `world.toggle_pause` / `world.hitstop` | Get hit and tap II / Back (or a call or notification takes the screen) within the 0.06-0.35 s freeze, then Save & quit | major | yes, `361f260` | qacheck "a pause during a hit's freeze": before x0.05 while paused, fade 8.9 s; after x1.00, 0.9 s |
| 2 | A diary page's reading card (or the guardian's versus card) that opens during a hit's freeze runs in slow motion and **ignores taps for ~12 s** | `world.hitstop` (the freeze's tween waited out any pause) | Tallow is burned (hot stove top, his own bomb) on the frame a page's card opens | major (rare) | yes, `7a247a5` | qacheck "a reading card opened during a hit's freeze": before x0.05, hold 0.04 of 0.6 s after 0.7 s; after x1.00, 0.65 s |
| 3 | With Swap sticks on a 16:9 screen (384 wide: monitors, Steam Deck, many phones' 1920x1080) a floor / relic banner's line under the title is drawn **off the right edge** (and wrapped to 47 lines) | `hud._place_banner` (used the keepsake button's x as its right edge; Swap sticks puts it on the left) | Swap sticks + touch at 384x216, take a relic or start a floor | minor | yes, `ca8f8cc` | qacheck "banner subtitle, Swap sticks, 384x216": before x 384..385, 47 lines; after x 74..309, 1 line; screenshot |
| 4 | The Kitchen's **hot stove tops are hard to see on a phone** (handoff follow-up): only the burner rings turn orange on an orange-brown floor | `area_gimmicks._kitchen_step` | A Kitchen floor (5+ floor night) | minor | yes, `6f6266b`: hot tops throw rising embers like a hearth's coals (visual only, no lights) | qacheck "hot stove tops throw embers": before 0, after 4 over 1 hot top; 1600x720 screenshot |
| 5 | `--tour --platform` said `FAIL d-pad down focus: Map` | `autotest._platform_tour` | The check expected Journal; since v2.6 the row under Resume is Journal / Map / Settings and down lands on Map (correct) | test | yes, `646c057` | platform tour: before fails=1, after fails=0 |
| 6 | `--savecycle --floors=7` said the house came back **DIFFERENT** after Save & quit + Continue (floors 4-7 in one run, floor 2 in another) | `autotest._save_cycle` | It read the "before" side 3 game-seconds into the floor, after the bot had walked into a room (that writes the room's candelabras / emptied chest cells into its grid). The house was the same | test | yes, `06b766d` | 2 seven-floor runs + 1 god run: every cycled floor SAME (the library hash that "failed" before comes back) |
| 7 | The chalk drawings in the first room show the default keys after a rebind | `chalk.gd` + `tools/art_chalk.py` (key glyphs are baked into the art) | Rebind the special move, start a run | minor | no: the `onboarding` stream is replacing the chalk start room and its hints | - |
| 8 | The first-run "12:00 AM" story card ignores Android's Back (Begin works) | `world.on_back` returns while `_intro_root` is up | Fresh slot, first run, press Back | minor | no: design call (Back could also mean Begin); not a trap | code read (the bot never sees this card) |
| 9 | A page picked up during a fight whose card had not shown yet is not shown after **Quick restart** or **Save & quit** (the page is found and in the Journal's Diary tab; only the card is skipped) | `world.quick_restart` / `_end_run(again)` skips the results screen that reads `diary_unread` | Take a page in a fight, then Restart from the pause menu | minor | no: design call (show it on the next run's start, or on the title?) | code read |
| 10 | A thumb that lands on the minimap (top right) opens the full map and pauses, mid-fight; with Swap sticks that is the move thumb's side | `hud._input` (v2.6: tap the minimap) | Rest the right thumb high on the screen | minor (design risk) | no: v2.6 feature; a long-press or a smaller hit area is a design call | code read |
| 11 | `--tour --gallery --fit` lists ~40 `OVER` lines | the gallery review sheet sits on its own layer over the title | Run the tour | test noise | no: a dev review sheet, never in play | - |
| 12 | `creature_glow.gd:46 custom_samplers` engine error in every log | `creature_glow.gdshader` | Any run | old, known | no (not this stream's) | - |

Checked and **not** a bug (each was a named risk):

- **Android's Back** (the system gesture reaches the game as a go-back request, `main.gd` -> `world.on_back`): in
  play it pauses, again it resumes; over the full map it closes the map then resumes; over Settings > Achievements
  it closes one layer per press; over the guardian's versus card and over its entrance it pauses, and the fight
  still starts after Resume; over a diary page it closes the page and the house goes on. It never opens the map;
  only the pad's Back opens the map (v2.6 by design), and Esc / B / Start / Back always close it again. All six
  are qacheck probes now. `main.gd` and `RunSave` are the only listeners, so a press is never handled twice.
- **A special move during a guardian's entrance or a reading card**: the card pauses the house (no move); during
  an entrance the guardian is `active = false` and every move skips it (Flare's heat, Slam, Sparkler, aim); a press
  skips the entrance and the move goes off, as a tap would. `--movescheck` PASS.
- **The pickup magnet** never takes priced goods, pedestals, chests, a pact's goods or the trapdoor (`_sweep_wants`);
  pages are swept only in a calm room; a sweep stops when Tallow leaves (`calm_t` resets on a pan).
- **Quick restart** in Tonight's Candle (scored once, the same house at level 2 and 4 floors, the same date) and in
  a 7-floor night in a level-3 slot (a new 7-floor house at level 3; the slot's saved run is the new one): qacheck.
- **Save & quit + Continue across night lengths**: 4 and 7 floors, every floor SAME; a run keeps its own length and
  level whatever the slot is set to now.
- **The full map and the Settings pages at 384x216** (gui, feel, platform, moves tours at 1536x864 with `--fit`):
  no OFF / OVER line; the Keys page shows only with keys or a pad; Swap sticks puts bomb / keepsake / move on the
  left, clear of the floor name.
- **Low-wax Flare Up on long nights**: 2 minutes, refused below 5 (any night length), taken straight off the wax
  (never a hit, never a kill).
- **Rebinding**: a key or button that another action uses is refused (move, shoot, pause, map included).
- **Timers and tweens after leaving a run**: game code has no `await`; the scene-tree timers in `enemy.gd`,
  `guardians_v21.gd`, `tower.gd` check `is_instance_valid` first.
- **Tallow Heart on long nights** ("Refill your wax", `heal(200)`): the 5-floor bot win at 12:04 AM came from it
  (wax 27 -> 158 on the Chapel's guardian); a refill is a refill, by design.

## Everything that was run (2.6.0 + this branch)

Self-checks (all on a fresh profile each): `--checkscripts` (every script ok), `--checkrooms` (0 problems; 1776 dressed
rooms, 657 area rooms), `--diarycheck` (42 checks PASS), `--movescheck` (PASS, 0 failed), `--feelcheck` (PASS),
`--designcheck --latency` (PASS), `--nightdump --speed=4` (equal to `v22_night_baseline.txt`, before and after the
fixes), `--savecycle` at 4 and 7 floors (see #6), `--tower --keeper` (the Keeper wins in phase 3, as documented).

Tours at 1600x720 with `--fit`: main, gui, slots, journal, platform (#5), diary, moves, feel, night, intros,
areas, specials, tower, bosses, gallery (#11), relictour; main at 1280x800 and 1920x1080; gui, feel, platform,
moves at 1536x864 (384x216). 0 script errors, 0 `[fit]` lines outside the gallery. Screenshots looked at:
title, slots, settings, pause, map, results, reading card, boss cards, HUD at 384 and 480 wide, Kitchen stoves.

Bot runs (`--playtest --speed=4`, fresh profile; 0 script errors, 0 `[stuck]`):

| Run | Result |
|---|---|
| each candle once (`--unlockall --candle=`): Tallow / Tea Light / Party / Pillar / Black Taper / Moonwick | WIN 12:31 / WIN 1:59 / WIN 1:49 / WIN 12:40 / WIN 1:53 / LOSS Crypt; moves used 6 / 69 / 30 / 5 / 10 / 11 times |
| `--difficulty=1` / `--difficulty=4` | WIN 12:47 / LOSS Crypt |
| `--floors=5` / `--floors=7` | WIN 12:04 (Tallow Heart) / WIN 2:18 AM |
| `--device=touch --settings=swap_sticks:true,reduce_motion:true,aim:auto,magnet:true` | WIN 12:49 |
| `--device=gamepad --settings=swap_sticks:true,magnet:false --floors=6` | WIN 1:43 |
| `--savecycle --floors=7` (2 seeds) / `--savecycle --god` (4 floors) | WIN 2:37 and 2:13 / WIN 12:40, every floor SAME |
| `--stress --god --floors=6` (a random relic every room) | WIN 1:30 |
| `--monkey` (6 runs) | see below |

Monkey runs (`--playtest --speed=4 --monkey`, about 2,900 presses in all, 0 script errors, 0 `[stuck]`):

| Run | Setup | Result | Presses | `[monkey] PROBLEM` |
|---|---|---|---|---|
| seed 301 | Tallow, keys, 4 floors | WIN 12:24 AM | 447 | 1: "paused 7 s" over the Belfry guardian's versus card. The first watchdog's own random walk (it re-opened Map / Settings / the Journal 20% of the time and could press the pause menu's Resume through Settings); recoverable by Back, and the Back matrix probe passes there. The watchdog now flags a closing press that changes nothing instead |
| seed 302 | touch, Swap sticks, Reduce motion, Aim Auto, 5 floors | LOSS Kitchen | 256 | 0 |
| seeds 303 / 304 / 305 | keys, 4 floors | LOSS Crypt / WIN 12:38 / WIN 12:45 | 209 / 633 / 634 | 0 |
| seed 306 | gamepad, the Black Taper, 7 floors | WIN 1:58 AM | 733 | 0 |

After the fixes: `--checkscripts`, `--checkrooms`, `--feelcheck`, `--movescheck`, `--diarycheck`,
`--designcheck --latency`, `--audiotest` (0 failed), `--qacheck` (11 PASS) all pass; `--nightdump` still equals the
baseline (hash 4259394795); `--playtest --god --runs=2` both reach the end (one climbs the Clock Tower); the main
tour at 384x216 and the areas tour at 480x216 show no `[fit]` line.

## Files

- `scripts/game/world.gd`: `toggle_pause` puts the time scale back when it pauses; `hitstop`'s tween runs while
  paused (#1, #2).
- `scripts/game/hud.gd`: `_place_banner`'s right edge (#3).
- `scripts/game/area_gimmicks.gd`: embers over hot stove tops (#4).
- `scripts/autotest.gd`: the platform check (#5), `_save_cycle` (#6), `--settings`, `--qacheck`, `--monkey` hooks.
- `scripts/qa_check.gd`, `scripts/qa_monkey.gd`: new.
