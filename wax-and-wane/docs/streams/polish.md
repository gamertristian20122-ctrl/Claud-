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
(see the table at the end of this file)

## 3. Balance
(see below)

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
