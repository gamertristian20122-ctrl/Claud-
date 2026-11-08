# Stream: endgame (Wax & Wane 2.0, round 2) - THE CLOCK TOWER

A secret fifth floor and the true ending: the hook for "can you beat it before 1 AM?" videos.
Branch `revamp/endgame`.

## How it works
1. **Unlock.** Snuff the Belfry's guardian (Hour Fiend or Great Pendulum) with the clock at or before
   **1:00 AM** (`Tower.UNLOCK_CLOCK`, wax >= 60). Instead of the victory banner the boss room clears, pays
   the usual guardian reward (a relic, a big wax, coins, "Your flame grows") and **a ladder of light** rises in the
   middle: "A LADDER OF LIGHT - The bells are not done with you". Touching it climbs (a pale moonlit fade, not the
   trapdoor fall) to floor 5, and the ladder's light runs down the wick: **+12 min** on arrival
   (`Tower.ARRIVAL_WAX`; the tower is long and the wax keeps burning). After 1:00 AM the normal victory still happens.
   - The Belfry win is counted right away (records `wins`, `best_finish`, the Black Taper unlock and the win
     achievements), so dying in the tower never takes a win away; the true ending's own `_end_run(true)` takes
     that one back so it is never counted twice.
   - Discoverable: after a normal win, while the tower has never been seen, the results screen says
     *"Something ticks above the belfry... be done by one."* Moonwick's Candle Box text is a second hint
     ("Locked: Be done by one, then climb").
   - Tonight's Candle (the daily) can reach it too. The 2:00 AM rule still applies up there: the wax keeps burning.
2. **Floor 5, THE CLOCK TOWER** (`FLOORS[5]`, theme `tower`): 7-9 cells = 6-8 rooms + the Keeper's room, one
   treasure room, **no shop, no hollow, no special rooms, no omens** (`Tower.layout`, called from
   `FloorGen.generate`). Brass and dark wood: wainscot walls with a brass rail, boards / parquet / boards with a
   floor grate over turning clockwork, slatted windows that throw striped moonlight (cool light) on the floor,
   brass lanterns, great wall gears that turn, bracket clocks that all say one o'clock, clock weights, a shelf of
   oil cans and springs, long-case clocks and cog crates as furniture (`B`), cogs / springs / screws / a lost key on
   the floor. Night colour `Color(0.27, 0.29, 0.40)`. Music `floor_5` = Ninja Adventure "19 - Ascension".
   Lodgers (`POOLS[5]`): Cog Sentries, Deathwatch Beetles, Hearth Devils, Rafter Leapers, Sootlings, Bone Lodgers;
   heavies Gutterspouts, Belfry Brutes, Waxwork Brides, Iron Snuffers, Necromancers; flyers Minute-Hand Wraiths,
   Clapper Bats, Gilt Cherubs. Ordinary health x2.35 (`Enemy.FLOOR_HP[4]`, Belfry x2.25); hits land as hard as in
   the Belfry (`enemy_dmg_mult` stops growing after floor 4).
3. **THE KEEPER OF HOURS** (`Enemy.DEFS["keeper"]`, `scripts/game/keeper.gd`): a hooded clockwork figure,
   48x56, a clock dial for a face (its hands show the house clock and run backwards in stopped time), a long-case
   trunk with a swinging pendulum, a plum cloak. It stands on a great brass dial inlaid in its floor
   (`tower/room_keeper.png`) and its two great hands sweep that dial. 280 hp, contact 8, a hand hits for 6.
   - **Phase 1 - the hands.** The hour hand (short, 74 px, slow: 180 deg in ~3.9 s) and the minute hand (long,
     104 px, quick: 120 deg in 1.6 s) take turns. Before a hand moves, its pale ghost shows where it starts, a
     dotted red arc shows the arc it covers and a dotted line marks where it stops (1.0 / 0.9 s warning): run the
     way the arc goes, past that line, or out past the tip (a one-time hint says so). Each sweep starts behind you
     and passes through where you stand. Aimed cog fans (4) and cog rings (10) in between.
   - **Phase 2 (66%) - stopped time.** Every ~8.5 s: the room greys (a screen shader; bullets and Tallow keep
     their colour), everything freezes, 12-16 cog bolts appear one by one in the frozen air (a ring closing on
     where you stood, or the dial's twelve aimed at you), each with a pale mark showing which way it will fly; three
     brass pips over the Keeper go out with three ticks, then everything moves again at once. Your own sparks hang
     in the air during the stop and fly on with the rest. Frozen bolts are harmless until time moves.
   - **Phase 3 (33%) - desperate.** The hour hand turns for good (slowly: you can walk round it), the minute hand
     sweeps faster with a shorter warning, and every 4.2 s the Keeper chimes: a ring of sound waves with a gap
     where you stand (keep still and it passes you by), and on every other chime a Cog Sentry (at most 2).
   - Every phase is seen, even by a run that melts it: damage past the next threshold is held until the Keeper
     has changed phase, and phases 1 and 2 last at least 6 and 8 s (`Keeper.MIN_PHASE`); held hits make the dial
     flash pale and ring like metal. Stopped time comes 1.6 s into phase 2. A new phase breaks off its hands.
   - Versus card via `Juice.of(world).boss_card` (it uses `Enemy.frames_for("keeper")`), music `final_boss`.
4. **True ending** (`scripts/ui/ending.gd`, a CanvasLayer over the world): "THE KEEPER OF HOURS IS STILLED",
   then four scenes (192x96 art at x2, moving parts drawn in code): the quiet house under the moon (twinkling
   stars, chimney smoke, one window lit), the tower dial running down and stopping at your finishing time, Tallow's
   flame settling on a windowsill under the night sky, the sky lightening step by step to dawn and the little flame
   going out; then a credits roll (logo, every credit, the guardians and the house champions by name), then the
   results screen marked **TRUE ENDING** ("Done by 1:23 AM. The clock has stopped."). Music `ending` = Ninja
   Adventure "15 - Credit Theme". Any key / click / tap / pad button skips after the first scene ("Tap to skip").
5. **Moonwick** (`Candles.LIST["moonwick"]`, last in `ORDER`): unlocked by stilling the Keeper. A pale blue-white
   candle in a silver dish: 108 wax (Tallow 120), speed x1.08, its sparks pierce one foe.

## New creatures (`Enemy.DEFS`, ai `tower_*` -> `Keeper`)
| id | Name | Behaviour | Telegraph |
|---|---|---|---|
| `cog_sentry` | Cog Sentry | keeps 46-80 px away, circles; stops and fires a cog down 4 lanes (+ then x) | 4 red lanes + eye flash 0.6 s |
| `minute_wraith` | Minute-Hand Wraith | flyer, drifts round you, aims its minute hand, lunges 180 px/s along it, fades out and comes back elsewhere | pale lane + flash 0.65 s |
| `keeper` | THE KEEPER OF HOURS | see above (`"secret": true`) | |

## Achievements (`achievements.gd`, all hidden)
| id | Name | Description |
|---|---|---|
| tower | Above the Bells | Climb the ladder of light into the Clock Tower. |
| keeper | Time's Up | Still the Keeper of Hours. |
| true_early | Home Before Half Past | Reach the true ending before 1:30 AM. |
| keeper_tallow / _tea_light / _party / _pillar / _black_taper / _moonwick | The Last Candle / Small Hours / Many Happy Returns / Load-Bearing / Midnight Oil / Moon Over the Tower | Still the Keeper as that candle. |

Records: `tower_seen`, `true_endings`, `true_best` (earliest true-ending clock minute).

## Hooks (one or two lines each, outside my files)
- `world.gd`: `FLOORS[5]`, `POOLS[5]`; `champ_chance` has a 5th value; `floor_title` on floor 5; omens never roll
  above floor 4; `_start_floor` -> `Tower.on_floor_start(self)`; `_build_room` -> `Tower.on_build(self, r)`;
  `_start_boss` plays `final_boss` on floors >= 4; `descend` -> `if transitioning or Tower.on_descend(self)`;
  `_boss_down` -> `if Tower.on_last_boss_down(self): return` before `_victory()`; `save_extra/load_extra` -> `"tower"`.
- `enemy.gd`: three `DEFS` entries, `FLOOR_HP` gets a 5th value (and the clamp uses its size), the AI dispatch sends
  `tower_*` to `Keeper.ai()`.
- `floor_gen.gd`: floor 5 returns `Tower.layout(rng)` (2 lines at the top of `generate`).
- `room_templates.gd`: `FLOOR_LIKES[5]`. `room.gd`: `B` furniture for the tower. `room_decor.gd`: a `tower` entry in
  `SCONCE` / `WALL` / `SIDE` / `FLOOR` / `FOOT`, `Tower.dress(...)` for windows and gears, and the tower in
  `check_dressing`.
- `results.gd`: `Tower.on_results(self, v, params)` (last line of `_ready`): TRUE ENDING, the tower's name and room,
  "The Keeper kept you." on a tower death, the first-win hint. It finds labels by their text, so it survives a
  restyle as long as the title still starts with "DONE BY" and the line "The house is quiet...".
- `candles.gd` (Moonwick), `player.gd` (`apply_candle`: `pierce`, `holder_tex`; `_ready` uses `holder_tex`).
- `achievements.gd`: 10 entries. `autotest.gd`: `--tower`, `--tour --tower`, `Keeper.bot_push` in `drive`, and the
  main tour's final boss now starts at 58 wax (after 1:00 AM) so it still ends on the normal results screen.
- `tools/import_audio.py`: two `MUSIC` slots (`floor_5`, `ending`).

## For other streams
- **meta (Journal):** `Enemy.DEFS["keeper"]["secret"] = true` - keep it hidden until seen. The cog sentry and the
  wraith are ordinary lodgers (floor 5 only). Moonwick's `unlock_text` is deliberately cryptic.
  `Game.records["true_endings"]` / `["true_best"]` / `["tower_seen"]` for the records page.
- **Credits (README + title.gd):** music now also uses "19 - Ascension" and "15 - Credit Theme" (Ninja Adventure,
  CC0, already credited as a pack; `assets/licenses/CREDITS_music.txt` regenerated).
- **Steam:** the 10 achievement ids above.

## Tests
- `godot --headless --path . -- --checkscripts`: clean. `--checkrooms`: 0 problems (1110 dressed rooms incl. the tower).
- `--autotest --playtest --speed=4 --tower [--god]`: starts a run on floor 5 at 12:48 AM with an 8-relic kit
  (`Tower.TEST_KIT`, +0.6 damage), +12 min for the ladder. Prints `[tower] test start ...`. Add `--keeper`
  (and `--keeperwax=N`, default 60) to go straight into the Keeper's room. The Keeper fight logs
  `[keeper] phase N after T s, Tallow at <clock>`, `[keeper] stilled after ...` / `[keeper] Tallow fell ...`.
- `--tour --tower --shots=DIR`: the ladder, the tower's first room and three rooms, the Keeper's card, each phase,
  stopped time (start, countdown, resume), phase 3, the death, the four ending scenes, the credits, the TRUE ENDING
  results, a tower death's results, the first-win hint and Moonwick in the Candle Box.

### Balance (bot, `--speed=4`, `--tower` = 8-relic kit, arriving at 12:36 AM after the ladder's +12 min)
| Build | Runs | Result | Notes |
|---|---|---|---|
| first build (tower hits x1.48, HP x2.5, Keeper 340) | 3 | 0 wins | all reached the Keeper with ~50 wax and lost ~1.5 min a second |
| pass 1: hits as in the Belfry, HP x2.35, Keeper 300, hand 6, +12 min on arrival | 1 | 0 | |
| pass 1 + the bot runs ahead of a moving hand; Keeper only, 60 wax (`--keeper`) | 2 | 2 wins (1:57, 1:59 AM) | hands hit it once a fight; phase 3 cost ~2.4 min a second |
| pass 2: Keeper 280, phase 3 slower | 1 | 1 (1:05 AM) | |
| **pass 3: phase 3 rings only from the chimes, fans cap at 5, a sentry every 3rd chime** | **4** | **3 wins** (1:44, 12:53, 1:36 AM) | the loss reached the Keeper with 14 wax and got it to 23% |
| + every phase is seen (damage waits at each threshold) | `--god --keeper` 2 | both still it, ~46 s fights | |

The tower rooms are the main filter (a bad room costs 20-40 minutes); the Keeper fight costs a typical run
30-60 minutes. Full game `--playtest --speed=4 --runs=2 --god`: both runs climbed the ladder, stilled the Keeper
and ended on TRUE ENDING (12:24 AM and 12:05 AM, 18 and 16 relics, no script errors). A god run stilled the Keeper in
7-12 s, which is why each phase now holds until the Keeper has changed phase.
Normal `--playtest --speed=4 --runs=2` (random seeds, no god mode): both runs beat the Belfry before one
(12:16-12:20 AM, 15-17 relics), climbed the ladder, stilled the Keeper and ended on TRUE ENDING; no script errors.
Those strong runs stilled it in 5-6 s before `Keeper.MIN_PHASE`; with it a fight lasts at least ~14 s plus
phase 3. `--tower --keeper --god` with the minimum phase times: 46 s fights, phases at 16-20 s and 31-35 s.
Knobs: `Tower.ARRIVAL_WAX`, `Tower.UNLOCK_CLOCK`, `Enemy.FLOOR_HP[4]`, `DEFS["keeper"]["hp"]`, `Keeper.HAND_HIT`,
the per-phase cooldown tables in `Keeper.tower_keeper`, `chime_t`, `MAX_SENTRIES`.

## Art (`python3 tools/art_tower.py [--review=DIR]`)
Everything is drawn in code in the 0x72 palette (the tool asserts palette and alpha), 1 px #222222 outline, light
from the top-left; round things (gears, dials) are rasterised from fixed integer maths. The tower rooms reuse the
room builder of `tools/art_rooms.py` (walls, caps, door joints, vignette) with a `tower` theme added at run time,
plus my own floor painters and the wainscot. The sconces are recolours of the Belfry's (same flame spots).
Only smooth image: `tower/light/moon_slats.png` (a light texture).
No third-party assets added (the two new music slots are from the already-credited Ninja Adventure pack).
