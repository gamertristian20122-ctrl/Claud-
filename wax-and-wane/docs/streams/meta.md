# Stream: meta (Wax & Wane 2.0, round 2)

Meta, Journal and onboarding: the reasons to play 200 runs. Branch `revamp/meta`.

## What it adds
1. **The Journal** (`scripts/ui/journal.gd`): opened from the title (Journal) and the pause menu
   (Journal | Settings). Six tabs, a paged grid on the left, the selected entry on the right.
   | Tab | Entries | Shows |
   |---|---|---|
   | Relics | 64 relics, 8 keepsakes, 2 Vigil gifts | icon x2, name, tier (5 pips + Trinket / Common / Fine / Rare / Treasure), rite, description, where it turns up, times taken; locked ones say what brings them |
   | Lodgers | the 33 creatures (`BestiaryGallery.regulars()`) | animated idle portrait (x3 / x2), name, where it haunts (from `world.POOLS`), lore, snuffed count |
   | Guardians | the 8 guardians | animated portrait, floor, title, lore, times beaten, fastest fight |
   | Rooms | the 5 special rooms + the 6 champions | prop / 2x champion art, name, floors, the room's line and hint; champions: snuffed or still at large |
   | Candles | the Candle Box | the candle drawn like Tallow (body, drips, face, flame, dish), line, stats, starting gear, best finish, wins; locked ones show their goal |
   | Records | The Ledger (totals, best finish per candle), Tonight's Candle (last 14 nights), the last 20 runs | a run: killer portrait, death note, candle, floor, time played, kills, Kindling, seed, its relics |
   Unseen entries are flat dark silhouettes named "???". New entries (first seen, first met, newly
   unlocked) carry a small gold dot until selected; tabs and the title's Journal button show a dot too.
   Input: touch taps + swipe the grid to turn pages; keys / pad move focus, LB / RB (Q / E) switch tabs,
   left / right past the grid's edge turns the page, B / Esc goes back. Fits 384x216 (phones show 480x216).
2. **Unlocks** (`scripts/game/unlocks.gd`): 18 of the 40 relics added in 2.0 and 2 of the new keepsakes
   start outside the house. Each moves in with an achievement (one with a milestone):
   | Item | Brought by |
   |---|---|
   | Dust Bunny | First Snuff |
   | Clockwork Mouse | Night Shift (100 creatures) |
   | Sweep's Brush | Chimney Sweep (1,000) |
   | Bell Rope | Bell Climber (reach the Belfry) |
   | Nightshade | Crypt Sealed |
   | Glass Chimney | Not a Scratch |
   | Cuckoo Clock | Early to Bed (win before 1:00) |
   | Tinderbox | Wildfire (x12 Kindling, hidden) |
   | Magpie's Nest | Cluttered Mantel (12 relics) |
   | Dowsing Rod | Someone Hid This (a Hollow) |
   | Lit at Both Ends | Smoke Pact |
   | Stopped Clock | Hush (ring the Hand Bell) |
   | Pendulum | Wind It Back (Winding Key) |
   | Pale Taper | Two O'Clock (melt to 2:00, hidden) |
   | Salt Line | Spirits Answered (a Seance) |
   | Blowlamp | Big Game (a house champion) |
   | Honeycomb | Generous Wick (feed the Wax Font five times) |
   | Minute Hand | light 5 candles (5 runs) |
   | Hand Mirror (keepsake) | Looking Glass (a Mirror bargain) |
   | Music Box (keepsake) | The Lucky Tune |
   - Only 2.0 relics are locked, so nothing a 1.x save could already find disappears; candles already
     unlocked stay unlocked, and an achievement earned before this table existed unlocks its item at once.
   - Each rite keeps at least 3 members in the starting pool (Household and Seance have exactly 3).
   - The pool is filtered once per run in `world._ready` (`relic_pool = Unlocks.pool(self)`), so every
     picker (RelicFx.next_relic, the special rooms' `pick_relic`, the altar) respects it. Keepsake picks
     (treasure, shop, Study) go through `Unlocks.keepsakes(w)` / `pick_keepsake(w)`.
   - **Tonight's Candle and typed-in seeds use the FIXED pool** (everything unlocked by default), so a
     seed is the same house and the same loot for everyone, whatever they have unlocked.
   - The achievement toast adds "NEW IN THE HOUSE: Blowlamp"; the achievements list says "Brings: ...".
     The results screen lists every item that moved in during the run (icon + name), and the Journal dots it.
3. **Results** (`scripts/ui/results.gd`): a death note when snuffed: the killer's portrait and
   "Snuffed by Grave Light" (creatures, guardians, champions, floor spikes, a lit hearth, an oil jar,
   your own bomb), "The clock struck two." when the wax melted away with no blow, "You blew out your own
   flame." for Give up. Then the floor, rooms (or the finish time on a win), time played, foes, Kindling;
   the run's relics (focusable / tappable, the name and text show below); NEW IN THE HOUSE; Tonight's
   Candle score or the next candle; the seed ("Seed 4821 7730 - share it with a friend"). Light another /
   Title keep gamepad focus (Light another is the default).
4. **The chalk start room** (`scripts/game/chalk.gd`, art `tools/art_chalk.py` -> `assets/art/chalk/`):
   floor 1's start room has the controls chalked on the floor for the device in use, swapped live with a
   quick smudge when `Controls.device` changes: touch (two thumb rings, the bomb and keepsake buttons),
   keyboard (W A S D, arrow keys, E / SPACE, Q), keyboard + mouse aim (arrow keys OR a mouse), gamepad
   (sticks L / R, RB, LB), plus a candle = clock doodle ("WAX = TIME"). Two flat chalk colours
   (#d3bfa9 / #b6cbcf), drawn at one alpha (0.5), lit by the room like the floor; stains draw over it.
   Floor decals under a drawing are swept aside. The long text hint now shows only for the first 3 runs.
5. **Title** (`scripts/ui/title.gd`, menu + credits only; the opening is untouched): Continue / Light the
   wick / Tonight's Candle / Journal | Seed / Settings | Credits (20 px rows so Continue fits under the
   logo). **Seed** opens a pixel keypad (tap, d-pad, or type digits; Del; Light) for a seeded run with the
   selected candle. The Credits modal lists everything: Claude (design, code, pixel art, jingles), 0x72
   (CC0), Kenney fonts and sound packs (CC0), Ninja Adventure music and sounds by Pixel-boy & AAA (CC0),
   Godot (MIT).

## Data (`Game.records`, saved with the rest)
`seen_relics`, `taken_relics`, `met` (kinds, and `mini:<kind>`), `kills_by_kind`, `bosses_beaten`
(kind -> {n, best seconds}), `run_history` (last 20: won, candle, floor, clock, killer, relics, time, kills,
streak, seed, daily, date, n), `best_streak`, `wins_by_candle`, `daily_history` (14 nights),
`rooms_found`, `journal_new`, `unlocks_known`. `Game.no_save` (tests) keeps a staged profile off disk.

## Hooks in other files (one line each unless noted)
- `world.gd`: `setup` (`set_meta("seeded", ...)`), `_ready` (`relic_pool = Unlocks.pool(self)`),
  `_start_floor` (the controls hint only while `runs <= 3`), treasure / shop keepsake picks
  (`Unlocks.pick_keepsake` / `Unlocks.keepsakes`), `collect_item` + `on_keepsake_taken`
  (`Records.take`), `on_enemy_killed` (`Records.on_kill`), `on_player_hurt` (`Records.on_hurt`),
  `on_player_died` (`Records.on_died`), `_end_run` (the results params go through `Records.end_run`),
  `_explode` (`Records.blame("bomb")`), `save_extra` / `load_extra` (`"records"`).
- `room.gd`: `Records.blame("hearth")`, `Records.blame("oil")`, end of `build`: `Records.on_room(self)`
  (special rooms found, guardian fight timer, the chalk).
- `shot.gd`: `Shot.setup` tags enemy shots with their shooter (`Records.tag_shot`).
- `pickup.gd`: the preview marks the item seen (`Records.see(item)`).
- `specials.gd`: the Study's keepsake list uses `Unlocks.keepsakes(world)`.
- `hud.gd`: the pause menu's Settings button became a row: Journal | Settings (4 lines).
- `achievements.gd`: 3 new entries, the toast's NEW IN THE HOUSE line, the list's "Brings:" line.
- `autotest.gd`: `--tour --journal` (6 lines) and `--unlockall` also sets `Unlocks.force_all`.
- `game.gd`: the new records keys and `no_save`.

### Who did it (the death note)
Hazards call `Records.blame(...)` just before `Player.hurt` (same physics frame). Everything else is read
at the moment the blow lands (`world.on_player_hurt` -> `Records.on_hurt`): an enemy shot touching
Tallow (its shooter was tagged when it was fired; a flask's splash inherits the thrower), else a creature
in contact, else floor spikes under Tallow, else the nearest creature within 34 px (slams, eruptions).
`on_died`: wax left over = Give up; a blow in the last 2 physics frames = that blow; else the clock.

## New achievements (Steam API names = ids)
| id | Name | Description |
|---|---|---|
| census | House Census | Meet every lodger in the house. |
| curio | Curio Cabinet | Find every relic in the house. |
| guardians_all | Night Watch | Snuff all eight guardians. |
(If the endgame stream adds a guardian, `guardians_all` asks for it too; the text says eight.)

## For other streams
- `Records.floor_name(n)` / `floor_count()` read `world.FLOORS` / `LAST_FLOOR`, so a fifth floor shows by
  its own name in the Journal and the results. New creatures and guardians in `Enemy.DEFS` appear in the
  Journal on their own (a second lodger page if there are more than 35).
- `Records.blame("<key>")` before `Player.hurt` for a new hazard, and add its name / icon to
  `Records.killer_name` / `killer_icon` / `short_killer`.
- `Unlocks.TABLE` is the one place to lock or move an item.
- Sounds used: `page_flip`, `ui_move`, `ui_back`, `unlock`, `ui_open`, `ui_click`.

## Tests
- `godot --headless --path . -- --checkscripts`: clean. `--checkrooms`: see the report.
- `--autotest --tour --journal --shots=DIR`: title (with Continue), every Journal tab, a locked relic,
  page 2, a lodger, a guardian, a champion, a run, the nights, the gamepad look, the seed keypad, the
  credits, the achievements list, the chalk start room (touch / keyboard / mouse / gamepad), the pause
  menu, the Journal over the pause menu, the unlock toast, a death-note results screen with a new unlock.
  The staged profile never touches the save file (`Game.no_save`); the real records come back after.
- `--checkrooms`: 0 problems (888 dressed rooms; the chalk attaches to the stand-in start rooms too).
- `--playtest --speed=4 --runs=2 --god`: both runs reach the end and win (12:18 AM, 12:22 AM), no script
  errors. `--playtest --speed=4 --runs=2`: 2 wins (12:32, 12:37 AM), no script errors.
- Full `--tour` (1600x720): 36 shots, no script errors; the start room shows the chalk.
- `--tour --journal` at 1600x720 (480x216) and 1152x648 (384x216): every screen fits.

## Art
`python3 tools/art_chalk.py [--review=<dir>]` writes 14 drawings to `assets/art/chalk/` (and review
sheets with each device's set on a cellar floor at the in-game alpha). Drawn in code: midpoint circles
and Bresenham lines that drop one pixel in ten (never two in a row) like chalk on stone, a 3x5 hand for
letters, keycaps with a front edge, a flame with a warm heart. The tool asserts the two palette colours
and full alpha. The Journal's silhouettes, dots, tier pips and Candle Box candles are drawn in code from
the existing art. No third-party assets added.
