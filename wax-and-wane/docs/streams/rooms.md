# Stream notes: rooms (v2.0 revamp, round 1)

Rooms, decor and level design. Every room of the house is now dressed for its floor, lit by flickering
wall lights, and built from one of 69 hand-made layouts that a validator checks.

## What changed
- **Layouts** (`scripts/game/room_templates.gd`): 18 layouts grew to 69. Each one has an id, tags and an
  optional weight / `min_floor`: open arenas, cover from shooters, choke points and switchbacks, pits that
  split the room, spike corridors, furniture rows, hearths, oil jars, cobwebs, skull piles, and hidden
  rewards behind rocks. `FLOOR_LIKES` tilts the pick by floor: the Cellar favours webs, barrels and oil,
  the Crypt favours pits and bones, the Chapel favours pews and hearths, and the Belfry favours spikes,
  pits and hard rooms. Layouts tagged `hard` never appear next to the start room (dist < 2).
  `pick_normal(rng, floor, dist)` stays seeded. One rock in a big group may become a soot rock, and in
  the Crypt some urns become skull piles.
- **Validator**: `godot --headless --path . -- --checkrooms` (exit code 1 on any problem). It checks all
  four mirrorings with the candelabras placed, and requires that:
  - every door connects to every other door without breaking anything;
  - every walker spawn (`e`, `h`) and chest (`T`) can be reached, at worst by shooting urns, crates or
    furniture;
  - no floor cell is sealed in for good (bombs may be needed for `$` vaults);
  - the reward cells (6..8, 4) stay walkable;
  - there are at most 2 hearths per layout, no spawns sit in door lanes, and each layout has 1 to 8 foes.

  It then builds every layout as a real `Room` (888 rooms: 4 themes x 74 layouts x 3 seeds, every room
  type) and fails if any room has more than 6 static lights or any decor piece overlaps a door slot.
- **New template characters** (also in `Room.SOLID` / `SHOT_SOLID`):
  | char | what | blocks | breaks by |
  |---|---|---|---|
  | `B` | furniture: barrel (Cellar), coffin (Crypt), pew + lectern (Chapel), fallen beam + cracked bell (Belfry). Runs join left to right | walk + shots | 4 shots or a bomb |
  | `G` / `g` | hearth: burns on touch (4 wax, like spikes) and sizzles foes; 4 shots douse it (`g`, 50 % wax drop or coin); a bomb smashes it | walk + shots | shots douse, bombs remove |
  | `O` | oil jar: one shot (any shot, enemy shots too) or a blast sets it off. Fireball r 26: 4 + 1.5 × floor damage to foes, 5 wax to Tallow if close; chains to other jars | walk + shots | 1 hit |
  | `W` | cobweb: halves walker speed (player and enemies); player embers and blasts burn it | nothing | embers / blasts |
  | `Q` | soot rock: always drops a bomb | walk + shots | bombs |
  | `Z` | skull pile: leaves bones | walk + shots | 2 shots |
  | `$` | hidden chest (never a mimic): stocked once into `data["pickups"]`, then the cell is plain floor | | |
- **Decor** (`scripts/game/room_decor.gd`, new): per room, seeded from `data["seed"]`:
  - the floor variant (0 to 2);
  - wall pieces on the top wall face (tiles 1-5 and 9-13, never on a door slot) and side-wall slots
    (y 40 and y 136);
  - one symmetric pair of animated wall lights, each a static mount, an unshaded flame and a warm
    flickering `PointLight2D` with no shadow;
  - in the Chapel, a pair of stained-glass windows that throw a coloured light pool onto the floor,
    with dust drifting in the beam;
  - flat floor decals, plus things leaning against the foot of the top wall.

  All static decor is drawn by one `_draw()` canvas item.
- **Light budget**: at most 6 static lights per room, counting candelabras and lit hearths
  (`RoomDecor.LIGHT_BUDGET`). Shops, treasure rooms and hollows get 2 fewer because their pedestals
  carry lights. Boss rooms (4 candelabras) get one pair of wall lights. Only the player's light casts
  shadows.
- **Floors** (`tools/art_rooms.py`): `room_<theme>_1/_2.png`.
  | theme | variant 1 | variant 2 |
  |---|---|---|
  | Cellar | flagstones with an iron drain | worn tiles with dirt and straw |
  | Crypt | grave slabs either side of a tiled aisle | inlaid border |
  | Chapel | red carpet runner door to door | chequered flags |
  | Belfry | boards | boards with a stone border |

  The top walls of every background are now plain. The 0x72 banners, wall holes and crypt slime that
  used to be baked in are seeded decor pieces (extracted from the 0x72 tiles and recoloured per
  theme), so shelves, windows and lights never sit on top of a baked banner. The classic floors are
  unchanged and door positions are unchanged.
- **Art** (`tools/art_decor.py` -> `assets/art/decor/`, new): 85 sprites in the 0x72 palette with a 1 px
  outline and light from the top-left (the tool asserts palette and alpha), plus one smooth light
  texture (`decor/light/window_pool.png`). Run `python3 tools/art_decor.py --review --out=<dir>` for
  contact sheets and in-room previews.

## Hooks for other streams
- `Room.slow_at(world_pos) -> float`: cobweb speed factor. I added one line each to `player.gd` `_move`
  and `enemy.gd` `_move` (non-flyers only). Keep them if you rewrite movement.
- `Room.shot_hits(wp, dmg, friendly := true)`: `shot.gd` now passes `friendly` (one-line change), so
  only player embers burn webs. Enemy shots still break urns and set off oil jars.
- `Room.blast(wp, radius, strong := true)`: bombs call it unchanged; oil uses `strong = false`.
- `Room.douse_hearth(c)` and `Room.burn_web(c)` are public if relics want them (e.g. a water relic).
- **Sounds** (audio stream): the room plays these names if they exist in `assets/audio/sfx/`, otherwise
  a stand-in: `oil_blast` (explosion), `hearth_out` (snuff_out), `web_burn` (tick),
  `furniture_break` (crate_break), `bones_break` (urn_break).
- **juice**: the stains node can go anywhere under `Room`. My layers are bg z -20, decor z -19, window
  glass -18, `floor_layer` (pits, spikes, webs) -15, doors -12, and wall flames / hollow cracks -11. z -14
  and -13 are free for stains.
- **bestiary**: `Room.path_dir(from_wp, to_wp) -> Vector2` gives a walker's steering direction: straight
  at the target when nothing solid is in between, otherwise the next step of a cached BFS flow field
  around rocks, pits and furniture, with no corner cutting. `_ai_chase` uses it (one line, plus the
  goblin jitter now wobbles around it). Please keep it, or call it from your own walker AIs: the new
  choke and switchback layouts strand straight-line chasers. Every walker spawn is guaranteed reachable.
- **autotest**:
  - `--tour` now takes one cleared room per floor (`floor_<n>_<theme>`).
  - `--tour --rooms` adds 4 hand-picked layouts per floor (`room_<n>_<id>`).
  - The bot skips pickups it cannot walk to, such as chests in rock vaults.

## Determinism
Template choice uses the floor RNG. Decor, floor variant, furniture variant and web variants derive from
`data["seed"]` and cell coordinates, so Tonight's Candle dresses every room identically for everyone.
No decor code touches the loot RNG. Hearth and jar drops use `world.rng`, like other obstacle drops.

## Credits
No third-party assets added. All decor and floor art is original, built from and matched to the CC0
0x72 DungeonTileset II palette.
