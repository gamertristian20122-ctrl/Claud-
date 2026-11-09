# Stream: v21/slots (Wax & Wane 2.1)

The owner asked: "Don't add candles that are specifically made for difficulty modes. I want it when you
press Light the wick that there's three save slots and each save slot there's a difficulty level from 1 to 4."
Branch `v21/slots`. Two parallel streams (shots, bosses) work in other files; the hooks they will meet are
listed at the end.

## What changed

1. **Three save slots.** *Light the wick* opens the Slots screen (`scripts/ui/slots.gd`): three cards side by
   side (122 px each at 384 wide, up to 150 on the phone's 480x216).
   - Empty slot: a sleeping, unlit Tallow and **New candle** -> the level picker (four big buttons: the number,
     the name and one line each) -> the run starts in that slot at that level.
   - Used slot: `SLOT N` (gold = played last) and **Delete**, then its level (number + name), runs / wins,
     best finish (any candle), relics seen, lodgers met, the last candle, and when a run is saved
     **Continue / Floor N - 12:41 AM**. **Play** (a new run; the existing "YOUR CANDLE IS STILL LIT" confirm
     when that would put a saved run out), **Level** (the picker with NOW on the current level, then a
     confirm; a saved run keeps its own level), **Delete** (two confirms, Keep it focused both times).
   - Touch, keys and gamepad: focus starts on the main button of the slot played last; B / Esc / Back
     returns to the title. One line under the cards: "Every slot keeps its own level, Journal, unlocks and
     achievements."
   - The title remembers the slot played last: its stats line says "Slot 1, level 2   Runs ..", its Continue
     says "Slot 1: Floor 2 - 12:41 AM", its Candle Box, Journal, Tonight's Candle and Seed use that slot. If the
     Slots screen deletes that slot or changes its level, the title behind follows at once (`refresh_slot`).
2. **Per-slot data** (`scripts/autoload/game.gd`). `Game.records` is the slot in use; everything that is
   progress lives in it (runs, wins, best times, the Journal, unlocks, candles, achievements, run history,
   Tonight's Candle, tips, and the candle the slot lights next). Files, all written atomically (tmp + rename):
   `user://save.cfg` = settings (shared) + `[game] slot` (played last); `user://slotN.cfg` = `[slot] level` +
   `[records]`; `user://runN.cfg` = that slot's Save & Continue snapshot (`RunSave`, which now also stores the
   run's level). An empty slot has no file and is never written; it gets one when a candle is lit in it
   (`Game.light_slot()` in `world._ready`), so Tonight's Candle on a fresh install starts Slot 1 at level 2.
   Achievements are earned per slot; Steam (if GodotSteam is ever present) gets every slot's achievements at
   start (`Game.all_achievements()`) and each new one as it is earned in any slot.
3. **Moving a 2.0 save in.** At start-up, a `save.cfg` with a `[records]` section and no slot files becomes
   Slot 1: every record copied, `run.cfg` -> `run1.cfg` (stamped with its level), level 2, or level 1 if
   Gentle burn was on; the old file is kept as `user://save_2.0.cfg`; `save.cfg` keeps only the settings.
4. **Difficulty 1-4** (`world.LEVELS`, applied through `world.difficulty()` only):

   | Level | Name | Line | melt | foe damage | foe health | marked foes | drip wax |
   |---|---|---|---|---|---|---|---|
   | 1 | Gentle | For learning: you melt slower and foes hit softer. | x0.75 | x0.5 | x0.85 | x1 | x1.25 |
   | 2 | Midnight | The night as it was made: a fair fight. | x1 | x1 | x1 | x1 | x1 |
   | 3 | Witching Hour | Harder: a faster melt, harder hits, more marked foes. | x1.1 | x1.2 | x1.15 | x1.5 | x1 |
   | 4 | Two O'Clock | Brutal: tough foes, cruel hits and thin wax. | x1.15 | x1.35 | x1.3 | x2 | x0.85 |

   Hooks: the melt in `world._physics_process` (replaces `gentle_mult`), `world.enemy_dmg_mult()` (contact,
   shots, the Keeper's hands), `Enemy.setup` (creatures and guardians), `world.champ_chance()`,
   `world.wax_bonus()` (wax pickups). Floor hazards (spikes, oil jars, your own bomb) are not foes and do not
   change. Gentle burn is gone from Settings (level 1 replaces it). Tonight's Candle always plays level 2 and
   is recorded in the slot in use; seeded runs use the slot's level; a continued run keeps the level it was
   lit at. The level shows on the pause menu, the results (death note and win), the Journal's run records
   and Ledger, the slot cards, the title line and the Share text ("Tallow at level 3: snuffed at Floor 2").
   New achievements (also in the Steam id list, `platform.md`): `win_level3` Spellbound (win on level 3 or
   higher), `win_level4` Dead of Night (win on level 4). 54 achievements now.
5. **The Black Taper is a sidegrade.** Before: the hard-mode candle (100 wax = lit at 12:20 AM, melt x1.4,
   hits taken x1.3, x2 marked foes paying coins, a forced Smoke Altar after every guardian; 4.8 min unhurt).
   After: Tallow's wax and melt (8.0 min unhurt), a short light (`"light": 0.75`, `Player.light_mult`) and
   foes beyond the edge of that light take 50% more damage (`"dark_hit": 1.5`, `Candles.dark_mult`, one line
   in `Enemy.take_hit`; a dark hit flashes violet). The edge follows the light, so the lower the wick, the
   more of the room is "the dark". Line: "A short, dark light. Foes out in the dark take 50% more damage."
   Its unlock (win a run) and achievements stay. Every "hard mode" line is gone (candles.gd, store texts,
   facts, README, CLAUDE.md).
6. **Texts**: store pages (Play, Steam, itch, press kit, POST_IT, trailer plan): 3 save slots, 4 levels,
   54 achievements, the Black Taper's new line, the slot files for Steam Cloud. `facts.md` regenerated
   (`tools/make_facts.py` now reads `world.LEVELS` and `Game.SLOTS`). README (save slots, flags, files).

## Checks (before -> after)

Level judge: `--autotest --playtest --speed=4 --runs=8 --difficulty=N` on a fresh profile, fresh seeds (the bot
ignores most telegraphs, so people do better). Targets: level 1 85-100 %, level 2 as 2.0.0 (7 of 12, about
55 %), level 3 25-40 %, level 4 5-20 %.

| Level | Numbers judged (melt / foe damage / drip wax) | On this branch (before the merge) | Merged 2.1 build (+ the four new guardians, bigger shots) |
|---|---|---|---|
| 1 Gentle | x0.8 / x0.6 / x1.25 | 6 of 8 (both losses on floor 3, within two minutes of the end) | |
| 1 Gentle | **x0.75 / x0.5 / x1.25** | 7 of 8 | **8 of 8**, winners 12:09-12:58 AM, 7 of them climbed the Clock Tower |
| 2 Midnight | x1 (2.0.0) | 4 of 8 | **6 of 8**, winners 12:25-1:54 AM (median about 1:00), losses on floors 2 and 3 |
| 3 Witching Hour | x1.1 / x1.3 / x1 | 2 of 8 | |
| 3 Witching Hour | **x1.1 / x1.2 / x1** | 3 of 6 (cut off) | **3 of 8**, losses mostly in the Crypt |
| 4 Two O'Clock | x1.15 / x1.3 / x0.85 | 2 of 8 | |
| 4 Two O'Clock | x1.2 / x1.4 / x0.8 | | 0 of 8 (2 runs hit the Ossuary bug, since fixed) |
| 4 Two O'Clock | x1.2 / x1.4 / x0.85 | | 0 of 12 (10 of the 12 ended on floors 1-2) |
| 4 Two O'Clock | **x1.15 / x1.35 / x0.85** | | **2 of 8** (25 %, a hair above the goal; foe damage x1.4 is a cliff for the bot) |

Foe health (x0.85 / x1 / x1.15 / x1.3) and marked foes (x1 / x1 / x1.5 / x2) did not change between passes.
Black Taper at level 2 (before the merge): 4 of 8 (Tallow on 2.0.0: 7 of 12), winners' median 1:09 AM, 16 % of its
blows landed in the dark (1,425 of 9,116). Save move: a real 2.0 profile (8 runs, 4 wins, 28 achievements, a
saved run) became Slot 1 with 29 records and 0 mismatches (`--tour --slots` on a copy). God runs: both reach the
end; `--checkscripts`, `--checkrooms` clean; `--tour --slots` 12 checks pass.

## Hooks outside this stream's files (for the merge)
- `scripts/game/enemy.gd`: `Enemy.setup` one line (`max_hp *= world.difficulty()["hp"]`); `take_hit` two lines
  (the Black Taper's dark multiplier and its violet flash).
- `scripts/game/player.gd`: `light_mult` (var, `apply_candle`, the light update, the Smoky Halls clamp) and
  `paint_preview` takes `"unlit": true` (no flame: the empty slot's sleeping Tallow).
- `scripts/game/world.gd`: `LEVELS` / `DEFAULT_LEVEL` / `level` / `difficulty()`; the multiplier hooks;
  `setup` reads the level and the slot's candle; `_ready` calls `Game.light_slot()`; `_end_run` passes the
  level; the Black Taper's special cases in `champ_chance`, `_champ_drop` and `_offer_altar` are gone.
- `tools/balance_probe.gd`: `--check=levels` replaces `--check=gentle`.
- **For the bosses stream**: new guardians get the level's health from `Enemy.setup` and the level's damage
  through `world.enemy_dmg_mult()` (use it, or `Shot`/contact damage, for any new attack). **For the shots
  stream**: enemy shot damage stays `5.0 * world.enemy_dmg_mult()` in `Shot._physics_process`.
- After merging: re-run `python3 tools/make_facts.py` (guardian and achievement counts) and the level judge.
