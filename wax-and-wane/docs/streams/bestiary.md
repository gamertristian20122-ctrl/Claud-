# Stream: bestiary (Wax & Wane 2.0, round 1)

A house full of memorable monsters: 33 creatures (was 17) and 8 guardians (was 4), each with a name,
a one-line lore entry and a stain colour for the Journal and the death splats.

## What is new

### Creatures (16 new, 33 total)
| id | Name | Floors | Behaviour (`ai`) | Telegraph |
|---|---|---|---|---|
| `wax_blob` | Rose Melt | 1-2 | `blob`: squashy hops; splits into 2 Melt Drops on death | - |
| `wax_bit` | Melt Drop | (split) | fast jittery chase, 4 contact damage | - |
| `moth` | Lamp Moth | 1-3 | `moth`: arrives as a swarm of 3, pulled to your flame (faster when you burn bright), flutters off after a touch, 3 contact damage | - |
| `snuffer` | Iron Snuffer | 2, 4 | `snuffer`: straight dash at your position | red dashed lane + wind-up frame 0.7 s |
| `wisp` | Grave Light | 2-3 | `blinker`: fades out, blinks near you, fires a 3-shot fan; glows (unshaded) | white flash + eyes 0.5 s |
| `sootling` | Sootling | 2-4 | `sooter`: skitters round you leaving soot smears that slow Tallow | - |
| `waxwork` | Waxwork Bride | 3-4 | `statue`: frozen while you face or shoot toward her, fast when you look away; eyes glow red when moving | creak sound when she starts |
| `cinder_rat` | Cinder Rat | 1, 2, 4 | `rat`: fast erratic darts and pauses | - |
| `psalter` | Restless Psalter | 3 (+Choir) | `fanner`: keeps its distance, alternating 5- and 3-page fans (`bolt_page`) | eye opens + flash 0.5 s |
| `clapper_bat` | Clapper Bat | 4 | `bellbat`: erratic flight, rings a slow ring of 10 sound waves (`bolt_ring`) | pale ring + flash 0.6 s |
| `deathwatch` | Deathwatch Beetle | 4 (+Pendulum) | `bouncer`: rolls diagonally, rebounds off walls, every 4th bounce turns toward you | ticks on each bounce |
| `grave_hand` | Grave Hand | 2-3 (+Sexton) | `burrow`: travels underground (untargetable mound), stops and shakes, then grabs | red ring 0.75 s |
| `gutterspout` | Gutterspout | 4 | `turret`: stationary; fires 3 quick shots along a row/column when you line up | pale lane + flash 0.45 s |
| `angel` (0x72) | Gilt Cherub | 3-4 | `orbit`: circles you at ~66 px and fires single shots | gold flash 0.4 s |
| `orc_warrior` (0x72) | Belfry Brute | 4 | `brute`: heavy chaser, ground slam (ring of 10 + hit within 28 px) | red ring + squash 0.55 s |
| `zombie` (0x72) | Potted Sleeper | 1-2 | `spitter`: slow, stops to spit a 3-shot fan | green flash 0.5 s |

Every older creature got a house name too (Coal-Bin Shambler, Larder Thief, Flue Imp, Bone Lodger, Hearth Devil...).

### Guardians (4 new, 8 total) - two per floor, picked from the run seed
| Floor | Option A (v1) | Option B (new) |
|---|---|---|
| 1 Cellar | Old Rot | **The Wax Mother** - weeping rings of rose wax, sheds Rose Melts (1, later 2, never a flood), aimed sprays (ph 2), a three-armed pouring spiral (ph 3) |
| 2 Crypt | The Gaoler | **The Sexton** - spade tosses of bone (`bolt_bone`), digs under the floor and erupts beneath you (red ring), raises Grave Hands (ph 2+), digs faster (ph 3) |
| 3 Chapel | The Hollow Warden | **The Melted Choir** - three wax choristers who sing in turn: alto fan, treble sound-ring, bass staccato; two voices at once (ph 2, plus a Psalter), all three (ph 3) |
| 4 Belfry | The Hour Fiend | **The Great Pendulum** - a brass bob on a rod sweeping the room (its arc is shown before it starts), bursts at each turn, aimed trio at the bottom (ph 2+), drops Deathwatch Beetles (ph 2+), stops and tolls between phases |

Each new boss has 3 phases (66% / 33% health) with a roar, a banner line (`phase_lines`) and a short
pause between phases. The finale stays sensible: until a player has won once, a normal run always ends
with the Hour Fiend; afterwards floor 4 is either the Hour Fiend or the Great Pendulum ("The Hour Fiend's
heart swings"), and the victory banner uses the boss's own line (`victory`). Tonight's Candle ignores the
records so the daily is identical for everyone.

### Floor flavour (POOLS)
- **Cellar** (gentle): shamblers, thieves, slugs, cinder rats, Rose Melts, Potted Sleepers; flyers: imps, Lamp Moths.
- **Crypt**: + Sootlings, Grave Hands, Iron Snuffers, Tincture Doctors; flyers + Grave Lights.
- **Chapel**: Hearth Devils, Rafter Leapers, Grave Lights; heavy: Chanters, Mourners, Psalters, Waxwork Brides; flyers: Cherubs, moths, Psalters.
- **Belfry**: Deathwatch Beetles, rats, Icebox Corpses; heavy: Gutterspouts, Belfry Brutes, Snuffers, Waxworks; flyers: Clapper Bats, imps, Cherubs.

### Balance changes (for the integrator)
- Ordinary creatures' health by floor is `Enemy.FLOOR_HP` = x1.0 / 1.28 / 1.65 / 2.1 (v1.1 was
  1.0 / 1.25 / 1.5 / 1.75): the cellar and crypt stay close to v1.1, the chapel and belfry press harder.
  Guardians: Old Rot 78, Gaoler 110, Wax Mother 92, Sexton 122 (floors 1-2, ~+10%); Hollow Warden 142,
  Melted Choir 152, Hour Fiend 220, Great Pendulum 228 (floors 3-4, ~+16-18%).
- Contact hits: 6 on floors 1-2 (as v1.1), 7 from the chapel up (`touch` default in `Enemy._physics_process`).
- `small_fry` creatures (Lamp Moths, Melt Drops) do not feed Kindling (one line in `world.on_enemy_killed`),
  otherwise swarms made the streak heal free.
- The bot numbers are in the stream report; with the stronger relics/juice streams merged, re-check
  `--playtest` and tune here (health scaling in `Enemy.setup`, `touch` default, boss `hp`).

## Hooks for other streams
- **Journal (round 2):** `Enemy.DEFS[kind]` has `name` (Title Case; bosses UPPER CASE as on the boss bar),
  `lore` (one line) and `stain` (Color). Bosses also have `title` (intro subtitle). Use
  `Enemy.frames_for(DEFS[kind].get("sprite", kind))` to get a SpriteFrames for the portrait (anim `idle`,
  or `default` for the chest mimic). `BestiaryGallery.regulars()` / `.boss_kinds()` list them.
- **Juice:** `e.stain_color()` for death splats. Enemies telegraph through `e._telegraph(col)` (flash) and
  `e.tele()` (a `Telegraph` node: `line()`, `ring()`, `path()`); feel free to add sound/shake there.
  New enemy shot kinds (all 7x7, loaded by `Shot` as `fx/<kind>`): `bolt_page`, `bolt_ring`, `bolt_wax`,
  `bolt_bone` in `assets/art/fx/`.
- **World:** `world.boss_kind` is the guardian chosen for the current floor
  (`Enemy.pick_boss(FLOORS[n]["bosses"], n, run_seed, daily)`); `FLOORS[n]["bosses"]` lists both options,
  `FLOORS[n]["boss"]` (the v1 guardian) is kept for anything that still reads it.
- **Enemy flags:** `e.buried` = underground / blinked out (no contact, shots pass, `active` is false but the
  AI keeps running). `e.mem` is per-creature scratch space. `e.later(delay, fn)` runs `fn` on enemy time.
- **Player:** Soot smears (`SootPatch`, on the room's floor layer) slow Tallow by handing back 45% of each
  frame's step (`player.position -= vel * dt * 0.45`), no stat changes.
- **Tours:** `--tour --gallery` (every creature labelled at 1x and 2x, every guardian, then each floor's
  lodgers in a lit room), `--tour --bosses [--only=<kind>]` (each guardian mid-fight, two shots each).

## Files
- `scripts/game/enemy.gd` (DEFS, loader, dispatch, flags), `scripts/game/enemies/house_ai.gd`,
  `boss_ai.gd`, `telegraph.gd`, `soot_patch.gd`, `gallery.gd`.
- `scripts/game/world.gd`: `FLOORS` / `POOLS`, `boss_kind` + the pick in `_start_floor`, `_start_boss`
  (title line), one line in `_victory` (boss's own victory banner).
- `scripts/autotest.gd`: 4 lines (gallery / bosses tour hook).
- `tools/art_monsters.py` + `tools/art_monsters_bosses.py` -> `assets/art/monsters/*` and `assets/art/fx/bolt_*`.

## Art notes
All new creatures are original pixel art drawn in code as character grids (one char = one pixel) on
the 0x72 palette: 1 px #222222 outline (8-neighbour like the 0x72 sprites), flat fills, one shade on the
back and underside, white/dark 2 px eyes, 4-frame idle + 4-frame run, feet on the bottom row. Small foes
are 16x16, tall ones 16x22, bosses 32x36 to 48x40. The Lamp Moth is ash grey with ember eye spots so it
never reads as the beige Moth Friend relic. `zombie` frames are the 0x72 `zombie_anim` frames copied
under our naming (the pack ships them as f10, f1, f2, f3).

## Credits
No new third-party assets. The `zombie`, `angel` and `orc_warrior` frames are from 0x72 DungeonTileset II
(CC0, already credited).
