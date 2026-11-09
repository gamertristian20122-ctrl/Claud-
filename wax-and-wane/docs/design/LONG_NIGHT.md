# The Long Night: runs of 4 to 10 floors (v2.2 design)

The owner asked for a slider that sets a run's length from 4 floors up to 10, "to have more fun things", and
chose: **more floors = a longer night**, with **new areas of the house** (own monsters, hazards, guardians).

## The rule
- Before a run (the slot's Play flow, next to the Candle Box) a **Night length** slider picks **4 to 10 floors**.
  It is remembered per save slot. Default 4 (today's game). Tonight's Candle always uses 4.
- **Every floor past four adds 30 minutes to the night.** The night ends at 2:00 AM for 4 floors, 2:30 for 5,
  3:00 for 6, 3:30 for 7 ... **5:00 AM (dawn) for 10.** Wax is still minutes: a full candle holds the whole
  night (120 + 30 x (floors - 4) minutes). Melt per second, hit damage and pickups keep their minute values.
- The candle's body, the HUD bar and its notches show the **fraction** of the night left, so a 10-floor candle
  looks the same as a 4-floor one at the same fraction (no giant candles). The clock shows the real time.
- **The Belfry is always the last floor** (its guardians are the finales). The Clock Tower stays the secret floor
  above the last floor: it opens after a first normal win when the Belfry falls with at least **half the night
  left** (1:00 AM on a 4-floor night, 2:30 AM on a 10-floor night).
- Difficulty ramps by **position in the run**, not by area: creature health, contact damage, melt and wax
  income use tables indexed by depth and stretched over the run's length, so floor 1 is always gentle and the
  last floor is always the hardest. The save slot's difficulty level (1-4) multiplies on top.

## The house, floor by floor
Floors are built as `[Cellar, Crypt] + middle + [Belfry]`, with the middle filled in this order and the Chapel
always the floor just before the new upper areas:

| Night | Floors |
|---|---|
| 4 | Cellar, Crypt, Chapel, Belfry (today) |
| 5 | Cellar, Crypt, **Kitchen**, Chapel, Belfry |
| 6 | Cellar, Crypt, Kitchen, **Library**, Chapel, Belfry |
| 7 | Cellar, Crypt, Kitchen, Library, Chapel, **Attic**, Belfry |
| 8 | ... Chapel, **Conservatory**, Attic, Belfry (batch 2) |
| 9 | ... Library, **Ballroom**, Chapel, Conservatory, Attic, Belfry (batch 2) |
| 10 | ... Library, Ballroom, **Gallery**, Chapel, Conservatory, Attic, Belfry (batch 2) |

Until batch 2 is in, the slider goes up to 7.

## New areas (batch 1)
Each area has: 2-3 room backgrounds + decor + wall lights in the 0x72 palette style, its own music slot (a CC0
Ninja Adventure track not used yet), a lodger pool (existing lodgers that fit + **2 new lodgers**), **one new
guardian** (plus one existing guardian that fits, so each area has two), and **one gimmick** that makes its rooms
play differently. Names are original and house-themed.

- **The Kitchen**: copper pots, ovens, flour sacks, hanging ladles, a long table. Gimmick: stove tops that glow
  on and off with a clear warning (burn when lit) and boiling pots that spill a scalding puddle when shot.
  New lodgers: a pot-lid crab (shielded from the front), a flour ghost (leaves a cloud that hides shots).
  Guardian: **THE STOCKPOT** (a bubbling iron pot with ladle arms: boiling arcs, spills, calls kitchen pests).
- **The Library**: tall shelves, reading lamps, ladders, drifting pages. Gimmick: bookshelves that slide along
  their rails on a timer (moving cover) and a hidden shelf-door in some rooms. New lodgers: a bookworm that
  tunnels through shelves, an inkblot that splits into slowing ink puddles. Guardian: **THE HEAD LIBRARIAN**
  (a tall hushing shade: rings of "hush" that briefly snuff Tallow's shots, flying books in patterns).
- **The Attic**: rafters, trunks, dust sheets, a round window with moonlight. Gimmick: deep dark (the light is
  smaller up here) with lanterns you can light by shooting them, and dust sheets that hide what is behind them.
  New lodgers: a dress-form mannequin that moves only in the dark, a trunk mimic. Guardian: **THE DRESSMAKER'S
  FORM** (a headless dress form with pins: pin volleys, spinning sheets, a sewing-needle dash with a lane warning).

## Code contract (so the streams can work in parallel)
- `scripts/game/areas.gd` (class `Areas`): the area table (id, name, theme, dark colour, music, lodger pool,
  guardians, gimmick) for every area including the four existing floors, and `Areas.sequence(n_floors)` ->
  the ordered list of area ids for a night. `world.gd` builds floors from it (replacing the hard-coded
  `FLOORS`/`POOLS` lookups by depth); `LAST_FLOOR` becomes the night's floor count.
- Art for an area lives in `assets/art/areas/<id>/` (and room backgrounds as `rooms/room_<theme>*.png` like the
  existing themes), made by `tools/art_areas.py`. Room dressing per theme goes through `room_decor.gd`'s
  theme tables (one entry per new theme).
- New lodgers and guardians: `Enemy.DEFS` entries + AI in `scripts/game/area_ai.gd` (one dispatch line in
  `enemy.gd`).
- Test flags: `--area=<id>` starts a run on that area (as the floor at its usual depth), `--floors=N` sets the
  night length, `--tour --areas` screenshots every area.
