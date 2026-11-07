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
| normal, fresh profile | `--playtest --seed=S` (S = 100, 200, 1000, 2000, 5000-24000) and the plain `--runs=2` | 76 | 0 / 0 | 0 / 0 |
| stress | `--stress` (a random relic every room), with and without `--god` | 6 | 0 / 0 | 0 / 0 |
| save cycle | `--stress --savecycle` with and without `--god` (Save & quit + Continue at floors 2, 3, 4; up to 64 relics) | 4 | 0 / 0 | 0 / 0 |
| every candle | `--unlockall --candle=tea_light / party / pillar / black_taper` | 43 | 0 / 0 | 0 / 0 |
| showcase combos | `--god --relics=blowlamp,tinderbox,twin_wick,candelabra`; `pale_taper,sharp_wick` + all six helpers + Moth Friend | 4 | 0 / 0 | 0 / 0 |
| god | `--god --runs=2` (twice) | 4 | 0 / 0 | 0 / 0 |
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
| pass 4 | **5 / 6** / 7 / 7 (`Enemy.TOUCH`) | 1 / 1.2 / 1.7 / 2.2 | 8 of 12 (67 %) | 12:05 - 1:21 AM (median 12:48) | 3 on floor 2, 1 on floor 3 |
| **pass 5 (final)** | 5 / 6 / 7 / 7 | 1 / **1.25** / 1.7 / 2.2 | 5 of 12 (42 %) | 12:10 - 12:56 AM | 6 on floor 2, 1 on floor 3 |

Passes 4 and 5 differ only by 4 % Crypt health, so read them together: **13 wins in 24 (54 %)**, winners
finishing 12:05 - 1:21 AM (median 12:46 AM). Twelve bot runs swing by +-15 % on their own (one seed block
went 0 for 4, the next 3 for 4), which is why every row is 12 runs on fresh seeds.

Final values: `Enemy.TOUCH = [5, 6, 7, 7]` (was 6 / 6 / 7 / 7 inline), `Enemy.FLOOR_HP = [1.0, 1.25, 1.7, 2.2]`
(was 1 / 1.28 / 1.75 / 2.25). Boss health, `DRAIN_PER_SEC` and the drop tables are unchanged apart from
the bomb-drop fix.

### Candles (god-free, `--unlockall --candle=X`, 3 runs each unless noted)
| Candle | Setting | Wins | Winners finished |
|---|---|---|---|
| Tea Light | before | 1 of 3 | 12:50 AM |
| Tea Light | pass 3 | 2 of 3 | 12:49, 1:27 AM |
| Party Candle | pass 3 | 3 of 3 | 12:20 - 1:01 AM |
| Altar Pillar | pass 3 | 3 of 3 | 12:27 - 1:11 AM |
| **Tea Light** | **final (pass 5)** | 1 of 3 | 12:44 AM |
| **Party Candle** | **final** | 3 of 3 | 12:32 - 12:44 AM |
| **Altar Pillar** | **final** | 1 of 3 | 12:54 AM |
| Black Taper (melt x1.2, damage x1.1) | passes 2, 4, 5 | 8 of 9 | 12:00 - 1:31 AM |
| Black Taper | + melt x1.4, hits x1.3, damage x1.0 | 4 of 7 | 12:24 - 1:08 AM |
| **Black Taper (final)** | + lit at 12:20 AM (100 wax) | **1 of 6** | 12:19 AM (losses on floors 2-3) |
The Black Taper is meant to be the hard mode, but with a Smoke Altar after every boss and twice the
marked foes (coin payouts) the bot ended its runs with 12-14 relics against 8-10 for Tallow, and won more
often than with Tallow. It is now lit at 12:20 AM (100 wax, was 120), melts x1.4 (was x1.2), takes x1.3
from hits (new candle key `"hit"`, read by `Player.apply_candle`; Save & Continue restores `hit_mult` with
the other player numbers) and has no damage bonus (was x1.1). Line: "Hard mode. Lit at 12:20 AM. Melts
fast; every boss offers a Smoke Altar." (293 px, fits the 300 px title label).
What the diagnostics showed: almost every loss is a run that reaches the Crypt with little wax and then
takes 15-27 hits there (floor-2 wax lost to hits 105-150 vs 17-77 gained back). Runs that get through the
Crypt with a few relics snowball and finish early. So the early contact damage is the strongest knob
(one point on floors 1-2 moved the bot from 18 % to ~80 %), while late health / contact mostly sets how
early the winners finish. The `hit by` lines show enemy shots cause about three hits in four; contact
is the rest, so the Crypt's shooters are what a struggling player meets first.

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

### Results (this container: 4 shared cores, other streams' bots running beside it)
| | physics step avg / p95 | process frame avg / p95 | live lights max (by owner) | nodes max |
|---|---|---|---|---|
| before | 1.47-1.65 / 2.7-3.6 ms | 0.40-0.50 / 0.67-0.84 ms | 15-18 (marked foes 4-7) | 258-331 |
| after | 1.39-1.68 / 2.8-3.2 ms | 0.41-0.47 / 0.65-0.72 ms | 12-14 (marked foes 3) | 250-322 |

- Static lights per busiest room: 5 / 4 / 6 / 5 against the budget of 6 (`RoomDecor.LIGHT_BUDGET`), so no
  room is over. Only one light casts shadows (Tallow's).
- A spawned foe costs 0.1-0.16 ms. `--ablate` shows no single hog: foes ~0.3-0.4 ms of a physics step
  (20 of them), relic helpers + Blowlamp ~0.35 ms, HUD 0.1 ms of a process frame.
- Leak check, three trips through the four floors: nodes stay within +-16 of the previous trip, objects
  within +-70 (no steady growth), 0 orphan nodes; resources rise 572 -> 608 once (textures loaded on
  first use) and then stay.
- The "engine worst/s" process spikes (18-28 ms) come from this machine being shared: the bench's own
  per-frame maximum is 2-7 ms.

Fixes:
- `Stains`: the 240x144 stain texture is uploaded at most every 50 ms instead of every frame something
  splats (a big fight re-uploaded it 60 times a second); mirrored splat images are made once and cached
  instead of duplicated for every splat.
- `world._physics_process`: the enemy and enemy-shot lists are pruned in place instead of allocating
  two new arrays (and lambdas) every physics frame.
- `Enemy`: at most 3 marked foes carry their own PointLight2D at a time (the tint still marks the rest);
  a marked wave room used to add a light per foe.

## 5. Phone UX (480x216)
- Floating texts (`world.fx_text`: Kindling, Clean, Quick, +min...) and shop prices now have a crisp
  1 px dark outline (`UI.outlined(label)`, `outline_size` 2 on the 8 px font, no blur). The drop shadow
  alone got lost on bright chapel and cellar tiles.
- Pause menu relics are 24x24 touch slots (18 px only when a run holds more than 24, so the menu still
  fits 216 px).
- Settings sliders: the - / + buttons are 24 px wide (were 20).
- The hint band under hints and item previews grows with the line (long shop lines spilled past it).
- Checked: pause 23 px + 4 px grace each side, bomb / keepsake 30 px + 4-6 px grace, menu buttons 24 px
  tall; left/right safe insets are already applied to every HUD corner element (`Hud.safe_insets()`);
  hints and previews lift above the boss bar.

## Known issues / for other streams
- Title (meta stream): the Candle Box arrows are about 20x23 px; 24 px wide would match the other targets.
- An achievement toast that pops while the pause menu is open covers the pause header for ~2 s.
- The bench runs on a shared container; compare its numbers only with runs made on the same machine.

## Hooks for other streams
- `UI.outlined(label) -> Label`: 1 px dark outline for any text drawn over the floor.
- `Game.clock_text(minutes, spare := true)` / `Game.spare_minutes(minutes)`: the clock rule above.
  Use these for any new time display (journal records, results death note, seeded runs).
- `Enemy.TOUCH` (contact per floor) and `Enemy.FLOOR_HP` are the main difficulty knobs.
- Bot: `--savecycle`, `--relics=` (now reliable), `[diag]` / `[stuck]` lines, `--bench`, `--ablate`.
