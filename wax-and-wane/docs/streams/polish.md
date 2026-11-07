# Polish, balance & QA (stream `polish`, round 2)

Branch `revamp/polish`. Small, surgical fixes across the merged round-1 build: the bugs round 1
reported, a crash / soft-lock hunt with the bot, a balance pass, a CPU bench, and a phone UX pass.

## 1. Round-1 bugs (all verified, all fixed)
| Bug | Fix | Where |
|---|---|---|
| Hints drawn over the boss bar ("Hand Bell is ready" over the boss name) | hints, item previews and their band move up 24 px while the boss bar shows (`Hud._place_hints()`, also called by `set_boss`) | `hud.gd` |
| Kindling + Clean + Quick texts overlap | `world.fx_text` stacks a new text 10 px above any live one it would cover (below them if that would leave the room) | `world.gd` `_free_text_y` |
| Achievement toast over the title logo after a run | arriving on the title drops queued toasts and the one on screen (they are saved and listed anyway); a toast that does show on the title slides in at the bottom | `achievements.gd` |
| Pale Taper ghost shots chip urns / crates | ghost shots skip `Room.shot_hits` and only test the outer wall | `shot.gd` |
| Dust motes snap at the start of the camera pan | the old room keeps its motes (drawn where that room is) for the 0.6 s pan; the new room scatters its own | `juice.gd` `DustMotes.move_to` |
| Room-clear light ring past the walls | the ring is clipped to the room interior | `juice.gd` `room_cleared` |
| "11:55 PM" when wax goes above 120 | **rule: the night never starts before midnight.** Spare wax reads as a bonus: the HUD clock stays at 12:00 AM with a small gold "+8 min" next to the candle bar; everywhere else `Game.clock_text(m)` gives "12:00 AM +8 min" (results, title best time, records, pause). `Game.clock_text(m, false)` drops the bonus, `Game.spare_minutes(m)` gives it | `game.gd`, `hud.gd` |
| `assets/licenses/Kenney_Fonts_CC0.txt` empty | restored from the jam-ready-assets Kenney Fonts licence | licence file |

## 2. Crash and soft-lock hunt
Every batch ran headless at `--speed=4` with its own fresh profile (`XDG_DATA_HOME` per process), then the
log was grepped for `SCRIPT ERROR`, `ERROR`, `[stuck]` (new: the bot logs a room it has been in for 120 s)
and runs that never finished (a 50-minute `timeout` per batch).

| Batch | Flags | Runs | Script errors / errors | Stuck / timed out |
|---|---|---|---|---|
| normal, fresh profile | `--playtest --seed=S` (S = 100, 200, 1000, 2000, 5000-20000) | 62 | 0 / 0 | 0 / 0 |
| stress | `--stress` (a random relic every room), with and without `--god` | 6 | 0 / 0 | 0 / 0 |
| save cycle | `--stress --god --savecycle` (Save & quit + Continue at floors 2, 3, 4; up to 64 relics) | 2 | 0 / 0 | 0 / 0 |
| every candle | `--unlockall --candle=tea_light / party / pillar / black_taper` | 18 | 0 / 0 | 0 / 0 |
| showcase combos | `--god --relics=blowlamp,tinderbox,twin_wick,candelabra`; `pale_taper,sharp_wick` + all six helpers + Moth Friend | 4 | 0 / 0 | 0 / 0 |
| bench | `--bench` (busiest rooms, 20 foes, Blowlamp + Tinderbox + helpers, full stains) x7 | 7 | 0 / 0 | - |

Bugs found and fixed on the way:
- **Plain kills never dropped bombs**: in `world._plain_drop` the bomb branch was `elif r < 0.165` *after*
  `elif r < 0.19` (coins), so it could never be reached. Now `r < 0.215 + luck * 0.1` (2.5 % base).
- **The bot's `--relics=` gave nothing**: it waited a fixed 0.4 s, but the screen fade takes longer, so the
  grant hit the old screen and silently returned. It now waits for the run and prints what it granted.
- New bot tools: `--savecycle`, the `[stuck]` line, and per-run `[diag]` lines (per floor: seconds, hits,
  wax lost to hits, wax gained; and what hit the bot).
- No hard soft-lock in any run. The `[nav]` lines (bot still in a room after 20 s) all resolved by themselves.

## 3. Balance
Measured with the bot, fresh profile, no `--unlockall`, `--speed=4`, 12 runs per setting unless noted
(seeds are consecutive from S, so every row plays different houses). The bot ignores most telegraphs,
so people do better than it.

| Setting | Contact (floor 1/2/3/4) | Floor health (`Enemy.FLOOR_HP`) | Wins | Winners finished | Losses |
|---|---|---|---|---|---|
| merged round 1 (before) | 6 / 6 / 7 / 7 | 1 / 1.28 / 1.75 / 2.25 | **3 of 17 (18 %)** | 12:32 - 12:56 AM | 10 on floor 2, 4 on floor 3 |
| pass 1 | 5 / 5 / 6 / 6 | 1 / 1.2 / 1.6 / 2.05 | 6 of 9 (67 %) | 12:00 - 1:52 AM (4 of 6 before 12:35) | floor 2-3 |
| pass 2 | 5 / 5 / 6 / 6 | 1 / 1.2 / **1.7 / 2.2** | 9 of 12 (75 %) | 12:00 - 1:56 AM (median 12:34) | 2 on floor 2, 1 on floor 3 |
| pass 3 | 5 / 5 / **7 / 7** | 1 / 1.2 / 1.7 / 2.2 | 10 of 12 (83 %) | 12:34 - 1:15 AM | 2 on floor 2 |
PASS4ROW
What the diagnostics showed: almost every loss is a run that reaches the Crypt with little wax and then
takes 15-27 hits there (floor-2 wax lost to hits 105-150 vs 17-77 gained back). Runs that get through the
Crypt with a few relics snowball and finish early. So the early contact damage is the strongest knob
(one point on floors 1-2 moved the bot from 18 % to ~80 %), while late health / contact mostly sets how
early the winners finish.

Also changed: plain kills drop bombs again (see above), and at most 3 marked foes carry a glow light.

## 4. Performance: `--bench`
`godot --headless --path . -- --autotest --bench [--secs=6] [--seed=N] [--ablate]`

- For each floor it builds the normal room with the most static lights, lights every candelabra,
  keeps 20 foes alive (a trickle of 2 every 0.25 s, a moth swarm, every 4th one marked), gives
  Blowlamp + Tinderbox + Twin Wick + Candelabra + Matchling + Warming Pan + Paper Lantern + Moth Friend +
  Dust Bunny, fills the floor stain image to its cap, and lets the bot fight in god mode.
- It switches off the headless frame sleep (`OS.low_processor_usage_mode_sleep_usec = 0`; headless
  Godot sleeps 6.9 ms after every frame, which hides the real cost) and measures wall-clock CPU per
  physics step (`physics_frame` to the next `process_frame`) and per process-only frame. Note the
  engine's `Performance.TIME_PROCESS` / `TIME_PHYSICS_PROCESS` monitors are the *worst frame of the
  last second*, not an average; the bench prints them as "engine worst/s".
- It also prints live lights by owner, shadowed lights, particles, shots, node counts, and then three
  trips through the four floors with node / object / orphan / resource counts after each floor.
- `--ablate` repeats floor 1 with each script group switched off (enemies, shots, player, world, juice,
  relics, room, HUD) to show where the time goes.
