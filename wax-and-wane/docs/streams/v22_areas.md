# Stream: v22/areas (Wax & Wane 2.2 "The Long Night", batch 1) - THE KITCHEN, THE LIBRARY, THE ATTIC

The owner asked for a night-length slider "to have more fun things". The design (`docs/design/LONG_NIGHT.md`) answers
with new areas of the house that fill the middle of longer nights. This stream builds batch 1 as self-contained
content with clean seams: three areas, each with its own rooms, decor, wall lights, music, two new lodgers, a new
guardian (plus an older one that fits), and a gimmick that makes its rooms play differently. It does **not** build
the floor sequence into the game or touch the clock: the `night` stream wires the areas in (see "Hooks" below).
Branch `v22/areas`.

## The areas

| | The Kitchen | The Library | The Attic |
|---|---|---|---|
| Look | orange brick caps, a cream-and-blue tiled backsplash, terracotta quarry tiles / a slate-and-terracotta scullery / warm flags round a braided rag rug; copper pans, plate racks, onions, spice jars; long tables, a black range, a butcher's block, flour sacks | green caps, dark green damask over a walnut dado; a green carpet with a wine border / walnut boards with a green runner / a brass compass star inlaid in the boards; bookshelves everywhere, a stern portrait, a map; free-standing bookcases, a reading desk, a globe, book piles | pine caps, planks under the rafters, pale dusty pine boards / a loft hatch with straw / a dressmaker's tissue patterns; a round window throwing moonlight; a straw hat and scarf, lavender, a shelf with a doll; dust-sheeted wardrobes, chairs and mirrors, trunks |
| Night colour | warm `(0.34, 0.25, 0.21)` | green-grey `(0.23, 0.27, 0.26)` | deep blue `(0.19, 0.20, 0.28)` |
| Wall lights | brass oil lamps (`glass` flame) | green-shaded reading lamps (`candle` flame) | none lit at first: the lanterns (gimmick) |
| Gimmick | **Stove tops** glow on and off: 1 s dull-red flicker (a warning), then 2.2 s hot (4 wax on touch, they sizzle lodgers); two groups take turns, so there is always a cold way through. The layout's spikes become stove tops and 2-4 more go on open floor (never in a door lane, a door mouth or the reward cells). **Boiling pots** (the layout's urns): steam over them; two shots and the pot spills a scalding puddle (3 wax a half-second to Tallow, it burns lodgers too) for 5 s | **Sliding bookcases**: 1-2 cases on 3-cell rails per ordinary room roll one cell every 3.6 s after a 0.6 s shudder and a creak. They never roll into Tallow, a walking lodger or a pickup (they wait), never sit in a door lane, and every position of every case keeps all doors joined and no floor sealed off (checked for every combination when the rails are chosen, and again by `--checkrooms`). They are furniture: 4 shots or a bomb break one. **Shelf-doors**: in about a third of the ordinary rooms one built-in bookcase has a book sticking out; three shots swing it open to a nook (a chest, a big wax or a bomb). When the floor's Hollow lies behind a top wall, that wall is a shelf-door too (shots or a bomb open it) | **Deep dark**: Tallow's light is 78% as big up here (`AreaGimmicks.ATTIC_LIGHT`). **Lanterns** on the top wall (up to 3 a room, each keeping a light of the budget) light when shot and stay lit (a lit lantern freezes the mannequins in its pool). **Dust sheets** over the furniture (template B) are tall: they hide whatever stands behind them until one shot tears the sheet off (it flies away; sometimes a coin or a wax drop falls out) |
| Music (`area_<id>`) | Ninja Adventure "14 - Curse" (CC0) | "30 - Ruins" | "16 - Melancholia" |
| Reverb (`Audio.set_space`) | 1 (small, dry) | 1 (books soak it up) | 4 (timber, airy) |
| New lodgers | **Pot-Lid Crab** (`lid_crab`): scuttles sideways behind a copper lid that turns away shots from its front (hit it from behind, above or below; it turns round after 0.75 s; bombs and big blows always land), snaps forward after a 0.45 s wind-up. **Flour Ghost** (`flour_ghost`, flies): every ~3.4 s it puffs up (0.45 s) and leaves a flour cloud that swallows every shot that flies into it, its own side's too, for 3.4 s | **Bookworm** (`bookworm`): tunnels through bookcases, desks and book piles (hidden and untouchable inside them, paper bits fly), rears up (0.4 s) and bites. **Inkblot** (`inkblot`): hops, spits a 3-blot fan (0.5 s tell), bursts into three sticky ink puddles and two **Ink Drops** (`ink_drop`, small fry) that leave smaller puddles; ink slows Tallow like soot | **Lantern-Shy Mannequin** (`mannequin`): moves only in the dark. In Tallow's light (or a lit lantern's pool) it is only wood; in the dark it walks fast with two ember eyes and lunges along a red lane (0.5 s). **Snapping Trunk** (`trunk`): a trunk among the attic's trunks (one frame in four its eyes glint under the lid); it wakes when Tallow comes close or shoots it (0.55 s rattle), hops three times with its lid snapping, then shuts and rests |
| Older lodgers that fit | Larder Thief, Cinder Rat, Drain Hopper, Sootling, Hearth Devil (behind the range), Icebox Corpse, Cistern Slug, Masked Porter (the back stairs), Tincture Doctor; flyers Flue Imp, Lamp Moth | Deathwatch Beetle, Rafter Leaper, Cinder Rat, Green Chanter, Restless Psalter, Hooded Mourner, Waxwork Bride, Iron Snuffer; flyers Psalter, Lamp Moth, Gilt Cherub | Rafter Leaper, Deathwatch Beetle, Sootling, Cinder Rat, Waxwork Bride, Iron Snuffer, Gutterspout, Hooded Mourner; flyers Clapper Bat, Lamp Moth, Grave Light |
| New guardian | **THE STOCKPOT** (`stockpot`, 44x40, 150 hp): an iron cauldron with ladle arms and two eyes glaring from under its lid. Boiling arcs (2-4 broth blobs lobbed at and round Tallow, each landing ringed in red while it flies; they burst into drops, and from phase 2 leave scalding puddles), the spill (it tips toward Tallow: a red lane 0.85 s, then a row of scalding puddles and a fan; two lanes in phase 3), the stir (a 2-3-armed spiral of broth, phase 2+), and it calls kitchen pests (two Cinder Rats; a Pot-Lid Crab and a rat in phase 3; never past 4 foes) | **THE HEAD LIBRARIAN** (`librarian`, 32x52, 158 hp): a tall hushing shade with half-moon spectacles. Flying books (aimed fans, a wall of books with a two-book gap, a three-armed spiral in phase 3), and the **hush**: "Shhh...", a pale ring telegraph (0.8 s), then a dotted ring spreads from her with one or two gaps (marked); where it passes Tallow outside a gap he cannot shoot for 1.3 s ("hushed") and it snuffs his embers as it goes; no damage by itself, a book fan follows. Phase 2+ she will not be crowded (a fade and she is elsewhere); phase 3 sends two rings | **THE DRESSMAKER'S FORM** (`dress_form`, 40x48, 165 hp): a headless dress form on a castored stand with a crinoline cage, a tape measure, pins and a great sewing needle. Pin volleys (diamond pins, `fx/bolt_pin`), spinning sheets (phase 2+: two or three dust sheets unfold round it, harmless while they flicker, then whirl; touching one melts 5 wax), the sewing-needle dash (a red lane to the wall, 0.85 s, 0.62 s in phase 3; pins burst where it stops from phase 2; two dashes in a row in phase 3) and a pin ring in phase 3 |
| Second guardian (older) | The Wax Mother (tallow was rendered in the kitchen) | The Hollow Warden (the reading room's night watch) | The Gaoler (the attic gets locked) |

All three guardians have three phases (66 % / 33 %), a roar and a banner line between them (`phase_lines`), a title
for the versus card, a boss bar, the usual phase pause, finale and rewards. Every attack is telegraphed.

## Files
New:
- `tools/art_areas.py` - every image of the three areas (226 files; asserts the 0x72 palette and opaque pixels;
  `--review=DIR` writes x3 room previews and x4-x6 contact sheets).
- `assets/art/rooms/room_<kitchen|library|attic>(_1|_2).png`, `assets/art/decor/{sconce,wall,side,prop}_<area>*`,
  `assets/art/areas/<area>/*` (decals, gimmick props, creatures), `assets/art/fx/bolt_pin_f0..1`.
- `assets/audio/music/area_kitchen|library|attic.ogg` (`tools/import_audio.py`, -16 LUFS loops).
- `scripts/game/areas.gd` (class `Areas`): the area table for all eight areas (the five 2.0 floors as read-only copies
  of world.gd FLOORS / POOLS and FLOOR_LIKES, the three new ones, batch 2 listed as not built), `sequence(n)`,
  `max_floors()` (7 until batch 2), `floor_def(id)`, `pool(id)`, `depth_in`, the Journal helpers
  (`haunts_text`, `guards_text`, `house_order`), the `--area` test start / report and the `--tour --areas` tour.
- `scripts/game/area_ai.gd` (class `AreaAI`): the six lodgers' and three guardians' behaviours.
- `scripts/game/area_gimmicks.gd` (class `AreaGimmicks`): the per-room gimmicks, the attic's dressing (round window,
  lanterns) and the library's shelf-door spans, the puddles / flour clouds / hush rings / spinning sheets the creatures
  leave, the bot's push and the `--checkrooms` pass for the new themes.

Edited (one or two lines each unless noted):
- `scripts/game/enemy.gd`: 10 DEFS entries (7 lodgers incl. the Ink Drop, 3 guardians), `frames_for` reads
  `"areas/<area>/<name>"` sprite paths, the AI dispatch sends `area_*` to `AreaAI`, two optional hooks for
  behaviours: `hit_<ai>(e, dmg, knock) -> bool` in `take_hit` and `died_<ai>(e)` in `_die`.
- `scripts/game/room.gd`: `AreaGimmicks.attach(self)` after the decor, `AreaGimmicks.obstacle_tex()` first in
  `_obstacle_tex`, `AreaGimmicks.shot_at()` first in `shot_hits`, `AreaGimmicks.urn_broken()` for "U".
- `scripts/game/room_decor.gd`: a `kitchen` / `library` / `attic` entry in SCONCE, WALL, SIDE, FLOOR, FOOT,
  `attic` in CORNER_WEBS, `AreaGimmicks.dress()` before the wall lights, the three themes in `check_dressing`.
- `scripts/game/world.gd`: `floor_areas`, `fdef(n)` and `fpool(n)` (below), and the 9 FLOORS / POOLS lookups of the
  floor building go through them (name, theme, dark, music, reverb, bosses, the v1 boss, the pool).
- `scripts/game/player.gd`: `light.texture_scale *= AreaGimmicks.light_mult(world)` (the attic's deep dark).
- `scripts/game/records.gd`: the death note names "a Hot Stove" and "Scalding Broth" (+ icons).
- `scripts/ui/journal.gd`: "Haunts ..." and "Guardian of ..." come from `Areas` (every area, in house order).
- `scripts/main.gd`: `--checkrooms` adds `AreaGimmicks.check()`.
- `scripts/autotest.gd`: `--area=<id>` start + report, `--tour --areas`, `mv += AreaGimmicks.bot_push(w, pos)`.
- `scripts/audio_check.gd`: the three music slots. `tools/import_audio.py`: the three MUSIC entries.
- Credits: `assets/licenses/CREDITS_music.txt` (regenerated), `README.md` (music table, layout, commands),
  `scripts/ui/ending.gd` (credits roll track list), `scripts/ui/credits_pages.gd` ("all 13 music tracks"),
  `DESIGN.md` (asset contract).

## Hooks for the night stream (what world.gd must call to build a floor from an area id)
1. **Which area is floor n:** `Areas.sequence(night_floors)[n - 1]` (ids; `sequence` clamps to 4..`Areas.max_floors()`,
   7 until batch 2). Fill `world.floor_areas[n] = id` for every floor of the night (or replace `fdef` / `fpool`):
   ```
   var floor_areas := {}                       # world.gd: floor number -> area id
   func fdef(n := floor_num) -> Dictionary:    # name, theme, dark, music, boss, bosses, space, area
       return Areas.floor_def(floor_areas[n]) if floor_areas.has(n) else FLOORS[n]
   func fpool(n := floor_num) -> Dictionary:   # e / h / f slots
       return Areas.pool(floor_areas[n]) if floor_areas.has(n) else POOLS[n]
   ```
   `_start_floor` already reads the guardian options, the night colour, the music and the reverb
   (`Audio.set_space(fdef(n)["space"])`) from `fdef(n)`; `_build_room` passes `fdef()["theme"]` to `Room.build`
   (that is all the dressing and the gimmicks need); `_spawn_room_enemies` takes `fpool()`.
2. **Still on floor numbers** (the night stream should move them to the area or the depth): `floor_title()` /
   the floor banner's "n/LAST_FLOOR", `LAST_FLOOR`, the per-floor tables (`FLOOR_DRAIN`, `KINDLE_CAP`, `QUICK_WAX`,
   `WAX_ODDS`, `STEADY_FLOORS`, `champ_chance`, `Enemy.FLOOR_HP`, `Enemy.TOUCH`, `enemy_dmg_mult`), `Enemy.pick_boss`'s
   "floor >= 4" first-Belfry rule, `RoomTemplates.FLOOR_LIKES` (use `Areas.def(id)["likes"]`), `FloorGen.OPENING_POOL`,
   `Specials` (Seance waves and the music-box lodger read `world.POOLS[n]`; champions by floor), `Records.floor_name()`
   and `Records.floor_count()`, the results screen's room picture (`results.gd`), `share.gd`, `boss_card.gd` (only when
   a guardian has no title), `gallery.gd` / `art_judge.gd` / `autotest._theme_shots` (tours). Save & Continue rebuilds a
   floor from the seed: store the night length (and so the sequence) in the snapshot.
3. **Guardian health does not scale by depth** (DEFS `hp`): the three new guardians are tuned for the Chapel's depth
   (150-165 hp, like the Hollow Warden 148 / Melted Choir 158). An older guardian used as an area's second option keeps
   its own hp (the Wax Mother 92 in the Kitchen is soft there): scale guardian hp by depth when the tables stretch.
4. Tonight's Candle / seeds: all placement is seeded from the room seed (stove tops, rails, shelf-doors, lanterns, the
   window); rewards (shelf-door nooks, dust sheets) use `world.rng` like other drops.

## Tests (this branch)
- `godot --headless --path . -- --checkscripts`: clean.
- `godot --headless --path . -- --checkrooms`: 0 problems. 1776 dressed rooms (8 themes x 74 layouts x 3 seeds) within
  the light budget, nothing on a door slot; the areas' own pass: 657 rooms (3 themes x 73 layouts x 3 seeds),
  every lantern lit still within the budget (6), no gimmick on a door slot, no stove or rail in a door lane, every
  sliding-shelf combination keeps the room whole, the same seed gives the same gimmicks.
- `--autotest --tour --areas --shots=DIR` (1600x720): 31 shots, no script errors.
RESULTS_PLACEHOLDER
