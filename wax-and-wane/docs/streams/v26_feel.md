# Stream: v26/feel (Wax & Wane 2.6) - smoother, snappier, less fiddly

The owner asked: "make the game play better". The game is already fun; this stream makes it smoother, snappier
and less fiddly to play, above all on a phone, without making it a different game and without changing the
seeded houses. Branch `v26/feel`.

## The outside judge (measured before any change)

Three probes, all in the repo:

- **`FeelProbe`** (`scripts/feel_probe.gd`): every `--playtest` run now prints `[feel]` lines: where the run's
  time goes (fighting, the doors-shut beat, walking to pickups, walking to the next door, walking back through
  rooms already cleared, special rooms, held still, transitions), rooms entered (new vs walked back through),
  room cleared -> through the next door, room pans and trapdoors without control. Game seconds.
- **`--autotest --feelcheck`** (`FeelProbe.check`): frame-level judges, one number each (99 = never / eaten):
  a 90-degree swing at full speed, the touch stick's travel for full speed, the pan and the trapdoor without
  control, a fire tap and a special-move press made just before a pan ends, the pickup magnet, Aim: Auto, the
  full map, Quick restart. PASS/FAIL.
- **`--designcheck --latency`** (the design pass's input probe), unchanged.

### Bot runs, before -> after (seeds 8101 + 8102, `--playtest --speed=4`, fresh profile, level 2)

Both seeds walk the very same route before and after (98 and 123 rooms entered, the same rooms new and walked back
through), so the time *outside* fights compares one to one; the fights themselves diverge (every hit and kill draws
from the loot RNG, so later lodgers differ), so fight time and hits do not.

| Game seconds (share of the run) | 8101 before | 8101 after | 8102 before | 8102 after |
|---|---|---|---|---|
| Result | WIN 12:22 AM, 800 s | WIN 12:35 AM, 754 s | WIN + tower 12:58 AM, 989 s | WIN + tower 1:25 AM, 1028 s |
| **Walking to pickups** | **97 (11.6%)** | **57 (7.3%)** | **154 (14.9%)** | **76 (7.2%)** |
| Room cleared -> through the next door, median / mean | 3.4 / 4.0 s | 3.2 / 3.1 s | 4.2 / 4.9 s | 2.7 / 3.0 s |
| **Transitions without control** | **32 (3.9%)** | **22 (2.8%)** | **40 (3.9%)** | **28 (2.7%)** |
| Room pan, mean (pans) | 0.33 s (94) | 0.23 s (94) | 0.33 s (118) | 0.23 s (118) |
| Trapdoor, mean | 0.42 s | 0.27 s | 0.48 s | 0.38 s (one is the tower's ladder) |
| Walking to the next door / walking back | 87 / 154 | 80 / 135 | 97 / 142 | 97 / 150 |
| Rooms entered: new / walked back through | 50 / 48 (49%) | 50 / 48 | 64 / 59 (48%) | 64 / 59 |
| Fighting (diverges, see above) | 414 (49.6%) | 437 (56.1%) | 536 (51.9%) | 648 (61.1%) |
| Doors-shut beat / special rooms / held still / idle | 18 / 9 / 14 / 9 | 19 / 8 / 16 / 6 | 13 / 11 / 22 / 18 | 17 / 13 / 23 / 8 |
| Drops the magnet brought | - | 114 | - | 153 |

Totals over the two runs: walking to pickups **251 -> 133 s (-47%)**, transitions **72 -> 50 s (-31%)**, a cleared
room's way out **median 3.4-4.2 -> 2.7-3.2 s**. Walking (to the next door and back) stayed 480 -> 462 s: it is the
route. "After" here is the code before the last small rule (wax flies only when half of it fits); the final code's
own two runs are under Checks.

### Frame judges (`--feelcheck`, 60 Hz physics frames), before -> after

| Judge | Before | After |
|---|---|---|
| 90-degree swing at full speed (velocity within 20 degrees of the new way) | 7 frames | **5** |
| Touch move stick: thumb travel for full speed | 22 px (the whole stick) | **14 px** |
| Touch move stick: speed at a 10 px push | 45% | **68%** |
| Room pan without control | 21 frames (0.35 s) | **17 (0.28 s)** |
| Trapdoor without control | 28 frames (0.47 s) | **20 (0.33 s)** |
| Fire tap ending 3 frames before a pan ends | eaten | **fires the frame control returns** |
| Special move pressed 4 frames before a pan ends | eaten | **fires the frame control returns** |
| A coin 110 px away in a cleared room, Tallow standing still | never comes | **1.17 s** (0.45 s to land + the drift) |
| A wax drop at a full candle / a shop item | stay | stay |
| Aim: Auto - foe in front (64 px) vs foe behind (44 px) | - | **the one in front** |
| Aim: Auto - the thumb drags up 12 px | - | **fires up (the stick wins)** |
| Aim: Auto - embers in 2 s vs a held fire key | - | **5 = 5** |
| Full map: tap the minimap / press M | - | opens over a paused game / closes and play goes on |
| Quick restart | - | the run is recorded as given up, the next is lit (same candle, same night length) |

Design latency probe, before = after (PASS): key fire -> ember 1 frame, a tap in the recharge 10 (kept), touch
drag -> ember 1, touch down -> ember 2, a 5 px flick 1, key move -> first pixel 2, reverse at full speed 3, touch
move 1, a bolt's hit -> flash / sound / HUD 0 / 0 / 0, an ember's hit -> flash / sound 0 / 0.

## What the numbers said

- **Picking things up was 12-15% of a run** (97 s and 154 s of the bot's 835 s and 1034 s), and a fought room took
  a median 3.4-4.2 s from its last kill to the next door. That walk is the clock melting for nothing: the pickup
  magnet goes after it.
- **Room changes are frequent** (94 and 118 pans a run): a pan was 0.33 s without control, and a tap or a move
  pressed in it was lost. Shorter pans, inputs kept.
- **Walking back is the biggest dead time** (48-49% of room entries are rooms already cleared; 142-154 s a run),
  but it is the route itself (explore everything, the guardian last), and the melt there is the game's clock. Left
  as it is (see Known issues); the full map with its "drops left" dots helps a person plan the way back.
- **Fights are half the run and fair**: of 27 shot hits in the two runs none came from beyond the candle's light
  (2 from beyond half of it), and the whole room is always on screen (272 x 192 inside 384/480 x 216), so nothing
  hits from off-screen. What was missing was *which side* a blow came from: the hit mark.
- **Doors** already open on the frame the last lodger falls, with the door sound, the clear chime, dust from every
  door and a light ring: nothing to change there.

## What changed

1. **Pickup magnet** (`pickup.gd` `_sweep_wants`, `world.calm_t` / `on_sweep`). Once a room is clear and quiet for
   0.45 s, its loose drops - coins, bombs, matches for a keepsake that is not full, diary pages, and wax when at
   least half of it fits in the candle - land, hop and fly to Tallow (up to 230 px/s), with one soft whoosh per
   sweep and their own pickup sounds. Shop goods, pedestals (relics, tonics, keepsakes), chests, the trapdoor, a
   pact's goods and a stub that would mostly be wasted stay where they are (a stub waits for a deeper cut; the
   full map marks the room). Rooms entered already clear (a hollow, a room with leftovers) sweep too.
   **Sweep's Brush** (shop relic) would have become dead weight, so it now also brings the drops left in the
   floor's other cleared rooms in through the doors ("Clearing a room sweeps every drop on the floor to you";
   geometric, no dice).
2. **Aim: Assist / Auto / Off** (Settings > Controls; `world.auto_aim`, `hud._physics_process`). Assist is today's
   aim assist and stays the default. **Auto** (touch): with the right thumb resting on the screen Tallow fires at the
   nearest foe - the one in front first, one in the open before one behind cover, out of the embers' reach only
   when nothing nearer is up - and keeps its target unless another is clearly better (no flicking). Dragging the
   thumb aims as before. Only the direction is picked: same fire rate, same damage, same assist. Off = no assist.
3. **Snappier flow** (`world.PAN_TIME` 0.27 s, was 0.34; `DROP_OUT` 0.32 s, was 0.45; `DROP_IN` 0.4 s, was 0.5).
   While a pan, a trapdoor or a relic held aloft takes control away, the flame keeps recharging, a fire tap in the
   last 0.2 s is kept (`player.gd`, the frozen branch) and a special-move press in the last 0.15 s is kept
   (`moves.gd` `_held_up`): both fire the frame control returns.
4. **Movement and hits** (`player.gd`, `hud.gd`). A sharp turn (45-100 degrees) now bites like a turn back
   (`TURN_ACCEL` blended by the angle): side-steps land in 5 frames instead of 7. The touch move stick reaches full
   speed at 60% of its reach (`MOVE_FULL`; 13 px of thumb travel instead of 22) with a smooth ramp from the same
   dead zone. Diagonals were already the same speed as straight lines. A blow now draws a hot pixel chevron for
   0.3 s on the side it came from (cream tip, red arms, the tip alone for the last 0.12 s) with sparks flying back
   at it, on top of the white flash, the knock-back and the i-frame blink (`_draw_hitmark`; visual only).
5. **Quality of life.**
   - **Full map** (`scripts/game/full_map.gd`, `FullMap`): tap or click the minimap, press M / Tab or the pad's Back
     (moved from pause; Start still pauses), or the pause menu's Map. Over the pause menu: every room seen, walked
     rooms lighter, Tallow's room cream with a flame, the guardian, treasure, shop, hollow, the special rooms' own
     marks ("?" until known), doorways, an ember dot where loose drops still lie, a legend and Resume. It shows only
     what the minimap has seen, bigger.
   - **Quick restart**: the pause menu's Restart (one question: "LIGHT A NEW CANDLE?") records the night as given up
     and lights the next at once - same slot, candle and night length (a typed-in seed or Tonight's Candle replays
     that same house). On the results screen **Light another** now keeps the run's candle and night length (it used
     the slot's candle); after Tonight's Candle it lights the slot's own candle as before.

## Settings and controls added

- Game > **Pickup magnet** ON / OFF: `Game.settings["magnet"]` (true).
- Controls > **Aim**: Assist / Auto / Off: `Game.settings["aim"]` ("assist"). It replaces the Aim assist switch;
  `aim_assist` stays the switch `world.assist_aim` reads (Off sets it false). An old save with Aim assist off loads
  as Off.
- New action `map`: M, Tab, pad Back (Back left `pause`). The pause menu rows are now Journal | Map | Settings and
  Save & quit | Restart | Give up.
- New strings through `L.t` (`lang/en.json` regenerated): Pickup magnet, Aim, Assist, Auto, Off, Map, Restart,
  LIGHT A NEW CANDLE?, This night ends here..., You, Guardian, Treasure, Shop, Hollow, Drops left, Resume,
  SWEPT IN +{n}, the new Sweep's Brush line.

## For other streams

- **gui** (restyling menus and the HUD): my edits there are small and functional - `hud.gd` (`map_layer`,
  `open_map`, `_confirm_restart`, the `map` key and the minimap tap in `_input`, Auto in `_physics_process`, the move
  stick's ramp, the two button rows), `settings_panel.gd` (the Aim cycle, the Pickup magnet toggle), `results.gd`
  (Light another's params). `FullMap` builds its modal with `UI.modal` / `UI.button` / `UI.label`, so it restyles
  with them.
- `world.auto_aim(p)`, `world.restart_params()`, `world.quick_restart()`, `world.open_map()`, `world.calm_t`,
  `Pickup.wax_amount()`, `Pickup._sweep_wants(p)`.
- The bot is unchanged (it sets its own aim); `FeelProbe.tick` reads what it is doing (`autotest._intent`).
  `--diarycheck` turns the magnet off (it finds and picks up the pages itself).

## Determinism

No new draws from `world.rng` or the floor RNG: the magnet, the auto aim, the map and the Brush's floor sweep use
none (the Brush places drops with `free_spot_near`); the hit mark's sparks use `randf()`.
`--autotest --nightdump --speed=4` equals `docs/streams/v22_night_baseline.txt` (553 lines, 4 floors).

## Checks (final code)

- `--checkscripts`: 77 scripts, 0 errors. `--checkrooms`: 0 problems (69 layouts, 1776 dressed rooms, 657 area rooms).
- `--autotest --nightdump --speed=4`: equal to `docs/streams/v22_night_baseline.txt` (553 lines).
- `--autotest --feelcheck`: PASS (the table above; plus Sweep's Brush: 1 drop swept in from another room, the
  priced relic left behind; the map; Quick restart: Tallow, 4 floors, the old run in the history as given up).
- `--designcheck --latency`: PASS, every number as before. `--movescheck`: PASS (0 failed; "held aloft / paused"
  still holds: a press while held aloft is kept only 0.15 s).
- `--playtest --speed=4 --runs=1 --god`: WIN 4/4 at 12:16 AM (858 s, 0 script errors; 102 drops swept, pickup 8.0%).
- `--playtest --speed=4 --runs=2 --seed=8101` on the final code: 1 of 2, 0 script errors. Seed 8101 LOST in the
  Crypt (29 hits on floor 2, 282 s; the same seed won in the two other batches, so the fights' variance), seed 8102
  WON at 12:39 AM (597 s; pickup 46 s = 7.4%, a cleared room's way out median 2.5 s, pans 0.22 s, trapdoors
  0.27 s). All seven bot runs of this stream: 0 of 91 shot hits came from beyond the candle's light.
- `--tour --feel --fit` at 1600x720 (480x216) and 1920x1080 (384x216): 9 shots each, 0 fit flags, looked at zoomed
  (the magnet mid-sweep, the hit mark, Aim: Auto firing at the foe in front, the map, the pause menu, Restart,
  both settings pages).
- `python3 tools/extract_strings.py --check`: up to date (467 keys); `--strict` on the two new files: PASS.

## Known issues / not done

- **Walking back** (half of all room entries) was not shortened: it is the route and the clock. It costs the bot
  135-154 s a run, roughly 35-55 minutes of the clock; a "hurry in cleared rooms" speed-up would win back part of
  that, but it is a balance change, so it is the owner's call (not done).
- **Auto** aims for touch only: keys, a pad and the mouse already give a direction (there Auto acts as Assist).
- The guardians' versus card + entrance (about 4 s each, any tap skips) were left alone (the juice and v2.4 streams'
  spectacle); the 0.25 s doors-shut beat before lodgers appear stays (it is what makes a room fair).
- The pad's Back button now opens the map instead of pausing (Start pauses).
- The magnet changes the economy a little in the player's favour: the bot walked 40-80 s less a run, which is
  10-25 minutes of the clock at the floors' melt. It did not show in these runs (the winners finished at 12:35,
  1:25 and 12:39 AM against 12:22 and 12:58 AM before: the fights' variance is bigger), but the next balance batch
  should keep an eye on it; Settings > Game > Pickup magnet turns it off.
- A bomb pressed during a pan is still refused (rare).
- Not checked on a real phone; the screenshots are at 1600x720 (480x216), `--fit` clean.
