# Stream: v22/night (Wax & Wane 2.2 "The Long Night") - THE NIGHT'S LENGTH

The owner asked for "a slider for 4 floors to like 10 max, I want it to have more fun things" and chose: **more
floors = a longer night**, with new areas of the house (`docs/design/LONG_NIGHT.md`). The `areas` stream built the
Kitchen, the Library and the Attic (`v22_areas.md`); this stream wires them into the night. Branch `v22/night`.

## What changed
1. **Night length in the world** (`world.gd`). `world.night_floors` (4 .. `Areas.max_floors()`, 7 until batch 2) from the
   run's params (`"floors"`), else the slot's (`Records.night_floors()`); Tonight's Candle is always 4. `floor_areas` is
   filled from `Areas.sequence()` with the Clock Tower above the last floor; every floor reads `fdef(n)` / `fpool(n)`.
   `last_floor()`, `is_tower(n)`, `Tower.floor_of(w)` replace `LAST_FLOOR` / floor-5 checks. `Areas.LIST` carries the
   v2.1 guardians in `world.FLOORS` order, so a 4-floor seed picks the same guardians. FloorGen / RoomTemplates take a
   night context (`world.gen_night(n)`: depth, area, the area's likes, the 4-floor key for specials and champions, the
   area's own champions `Areas.LIST[..]["minis"]`); the tower is built by area; skull piles only in the Crypt.
2. **Clock and wax.** `Game.night_minutes(floors)` = 120 + 30 x (floors - 4) is the one place (`world.night_minutes()`);
   every candle gets the extra half hours, `clock_minutes()` = night - wax, `Game.clock_text` reads to 5:00 AM. Melt,
   hits and pickups keep their minute values. The candle's body / face / dish / light (`Player.shown_wax()`,
   `wax_frac()`), the moths' pull, the mannequins' light reach and the HUD bar + notches (eighths of the night, the wide
   one at half the night) show the fraction of the night; danger cues stay in real minutes. Bells strike the hours,
   "Hurry" half an hour and "nearly gone" a quarter before the night's end (cached per run).
3. **Difficulty by depth** (`world.depth(n)`, `Areas.at_depth(tbl, d)`): floor 1 = 1, floor 2 (the Crypt) = 2, the
   floors above stretch to the Belfry's 4 (`NIGHT_CURVE` 0.5), the tower = 5; exact at whole depths. Read by depth:
   FLOOR_DRAIN, KINDLE_CAP, QUICK_WAX (whole minutes), WAX_ODDS, marked foes, Enemy.FLOOR_HP / TOUCH, enemy_dmg_mult,
   creature speed, QUICK par, shop prices, bomb / oil damage, rare-relic weights, the music box's lodgers. Guardians
   away from their home depth (`Areas.home_depth`) get FLOOR_HP-scaled health (the Wax Mother in a long Kitchen).
   `pick_boss`'s first-Belfry rule follows the last floor; Seance waves / music box lodgers come from `fpool()`.
4. **Clock Tower**: opens after a first win when the Belfry falls with half the night left (`Tower.unlock_clock`:
   1:00 AM on 4 floors, 1:45 AM on 7); its hint and lines name the night's own end.
5. **Night length picker** (`Slots.pick_night`, `Slots.NightSlider`): a slot's Play ("Play / 7 floors") and New candle
   open "SLOT N: HOW LONG A NIGHT?": a pixel slider 4 .. max with "7 FLOORS", "Until 3:30 AM ..." and the house it builds
   (new areas in gold). Remembered per slot (`Records.set_night_floors`). Touch: arrows / ticks / drag; keys and pad:
   left / right on the slider, A / Enter lights. The seed keypad has the same slider beside it.
6. **Names**: banner "Floor 3 of 7", `floor_title()`, pause menu, results (night length, the area's room picture,
   "The clock struck half past three."), Share ("seed 4821 7730, 7 floors", a glyph per floor), Journal (night length on
   run records, deepest area, best times per night length: `Records.note_finish` / `best_finish_of`, longer nights in
   `best_nights`, true ending in `true_best_nights`), How to play, the intro, RunSave summary ("Floor 5/7 - 1:41 AM";
   the snapshot keeps `floors`, old ones load as 4), boss card fallback, the ending's dial line, the Pillar's text.
7. **Achievements**: new **The Small Hours** (`small_hours`; renamed at the merge: an omen is already called Long Night; Steam id in `platform.md`): win a night of 7+ floors. Before
   Two needs the clock before 2:00 AM, Early to Bed before 1:00 AM (`Achievements.on_win`); floor / guardian
   achievements follow the area; Night Watch counts the 4-floor house's twelve guardians.
8. **Bot**: `--floors=N`; [playtest] lines say `floor=5/7 (chapel)`; `--savecycle` prints the floor's area, night length
   and a room hash before/after Continue; `--nightdump` (determinism) and `--tour --night` (screenshots) in
   `scripts/night_check.gd`.

## Balance (the Long Night's own rules, tuned with the bot; the 4-floor night reads none of them)
- New areas on a longer night are **wild**: no treasure room, no shop, their guardian leaves wax and coins but no relic
  (`world.wild_floor`, `FloorGen._wild`); the house's own four floors keep theirs. "Your flame grows" is spread so a
  whole night adds +0.45 (`world.flame_growth`). A low wick steadies on the night's last two floors.
- Bot numbers so far (`--playtest --speed=4`, fresh profile, level 2): 4-floor reference on this branch 3/6 wins
  (losses: Crypt 2, Belfry 1; wins 12:35-1:50 AM). 7 floors, linear stretch: 4/4 wins (1:47-2:05 AM, one true
  ending); Crypt-anchored stretch: 4/4 (1:50-2:03 AM); steep curve 0.4: 2/2 (1:52-2:00 AM). The long candle shields the
  weak early floors and ~30 relics make the late floors free, so the wild-area rule and NIGHT_CURVE 0.5 were added
  last; **they have not been measured** (the owner stopped the balance judging). 5-floor nights were not measured.

## Checks
- Determinism: `--autotest --nightdump --speed=4 --dump=FILE` (4 seeded nights, a plain one, Tonight's Candle; every
  floor's area, guardian, omen, cells, numbers, treasure / shop stock, first lodgers and guardian health: 553 lines)
  equals `docs/streams/v22_night_baseline.txt` after every step, the last balance change included.
- `--checkscripts` clean (65 scripts); `--checkrooms` 0 problems (69 layouts, 1776 dressed rooms, areas 657).
- God runs: 7 floors reached the end (WIN 7/7 at 12:43 AM, 1101 s, before the balance changes); with the final rules: WIN 7/7 (the Belfry) at 2:04 AM, 1285 s, 0 script errors.

## Hooks
- A new area (batch 2): build it in `Areas.LIST` (`built`, pool, likes, guardians, optional `minis`); the picker, the
  depth tables and the clock follow `Areas.max_floors()`. A guardian's hp is tuned at its home depth (`home_depth`).
- A per-floor number: `world.floor_k(tbl)` / `Areas.at_depth(tbl, world.depth())` (the floor number on 4 floors).
- Times: `world.night_minutes()`, `clock_minutes()`, `Records.hour_words()`, `night_end_phrase()`, `night_of(params)`.
- Best times: `Records.note_finish(candle, floors, t)` / `best_finish_of(...)`. The candle's look: `Player.shown_wax()`.
- The tower: `Tower.floor_of(w)`, `Tower.unlock_clock(w)`. Keep `--nightdump` equal to the baseline.

## Known issues / not done
- Balance of 5- and 7-floor nights after the wild-area rule is unmeasured (last measured: 7 floors far easier than 4).
- The screenshot tour (`--tour --night --fit`) was written but not run (stopped by the owner), so the picker, the
  long-night HUD, banners, results and Journal have not been looked at on screen.
- `--savecycle --floors=7` was not run (the house signature check is in place).
- The omen "Long Night" (a bigger floor) shares its name with the feature.
- Edited outside the stream's own files (one or two lines each): relic_fx (rare weights by depth), room (oil damage),
  house_ai / area_ai (light fraction), boss_card, ending, candles (Pillar text), platform.md (Steam id).
