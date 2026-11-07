# Stream: specials (Wax & Wane 2.0, round 2)

Special rooms and mini-bosses: something to find on every floor. Branch `revamp/specials`.

## The rooms
Each special room is a new dead end hanging off one ordinary room (it touches nothing else), with its
own door style on both sides of the doorway and its own minimap mark. They start open (cleared): you
can always walk in, look, and leave.

| Room | Floors | Chance | What it does |
|---|---|---|---|
| **The Seance** | 1-4 | 60% | A brass bell on a frame inside a chalk ring with five candles. Walk into it or shoot it: the doors lock and 3 waves of five lodgers arrive (this floor with a heavy; then half from the floor below with a flyer and a heavy; then all from below with two heavies, the last one marked; the Cellar's seance is 3 / 4 / 4 with one heavy). Called-up lodgers are pale half-spirits that leave no drippings. A chime and "2 of 3" between waves. Clearing pays a relic from the **boss** pool and 4-6 coins. Leaving before ringing is free. |
| **The Cracked Mirror** | 2-4 | 45% | A dark door with a "1 [wax]" toll mark in front of it; the first step through costs 1 minute. Inside, a pier glass offers a tier 3-4 relic for **15 max minutes, for good** (the Smoke Altar's `cost_wax` code in `pickup.gd`, reused), or "Leave It" (veil the glass, +2 min). Taking one crumbles the other. The mirror shatters or is veiled. |
| **The Music Box** | 1-4 | 40% | Walk into it: 3 coins a crank, the key turns and the dancer spins for ~1 s with ticking, then a tune: nothing 28 / coins back x2 22 / wax 16 / a bomb 12 / a tonic 9 / a lodger climbs out (doors lock until it is gone) 7 / a relic 6 (tier 0-2, the spring then breaks). Each result has its own line of text and sound. |
| **The Study** | 2-4 | 35% | A lectern; take one of three, the others crumble: a keepsake (never the one you hold), two unlabelled tonics, or "Read the Map" (every room of the floor, hollows too, and what each special room is). |
| **The Wax Font** | 1-4 | 30% | Walk into the basin: it melts 4 minutes away, a pip on its rim lights up and the wax inside rises. Odds of a payout by offering: 12 / 22 / 34 / 48 / 65 / 100%. Offerings 1-3 pay coins (3 + n) or a chest; from the 4th the payout is a relic and the font is spent. After each miss it says the next odds ("It drinks. Next: 5 in 10"), and the first-visit hint says the sixth always pays. |

You must step away from a prop before using it again, so walking past never spends twice.

## Mini-bosses
Floors 2-4, 50%: one ordinary room at distance 2+ from the start is a champion's room, with an open
layout (`open` tag, no spikes, no `hard`). On entry the doors lock and a lodger of the floor appears at
**twice the size** (a real 2x redraw, see Art), 6x health, heavy, contact damage 9 (lodgers 6-7, guardians 8), collision radius x1.5 (max 8), a red glow, a
name banner (no versus card) and the boss bar with its name. It keeps its own AI and adds one attack:

| Floor | Champion | From | Extra attack (telegraphed) |
|---|---|---|---|
| 2 | THE GREAT SOOTLING | Sootling | ring of 10 shots in a puff of soot |
| 2 | THE BONE LANDLORD | Bone Lodger | aimed 5-bone fan |
| 3 | THE KITCHEN DEVIL | Hearth Devil | double ring of 12 |
| 3 | THE RAFTER KING | Rafter Leaper | every landing throws a ring of 10 sound waves |
| 4 | THE DEATHWATCH QUEEN | Deathwatch Beetle | double ring of 8 ticks |
| 4 | THE ICEBOX GIANT | Icebox Corpse | aimed 3-shot water fan (and its death burst) |

Guaranteed reward on top of the normal room reward: a tier 1-2 relic (40%) or a chest (60%).

## Minimap
Special rooms show as **"?"** once seen (next to a visited room) until you step in. The Dowsing Rod and
the House Deed show every special room with its mark (even far away), and the Study's map does too.
Marks (5x4): bell (Seance), glass (Mirror), note (Music Box), book (Study), drop (Font). With the House
Deed an unbeaten champion's room shows a red mark.

## Achievements (in `achievements.gd`)
| id | Name | Description |
|---|---|---|
| seance | Spirits Answered | Ring the Seance bell and see it through. |
| mirror_deal | Looking Glass | Strike a bargain with the Cracked Mirror. |
| music_box | The Lucky Tune | Wind a relic out of the Music Box. |
| font_5 | Generous Wick | Feed the Wax Font five times in one run. |
| mini_boss | Big Game | Snuff a house champion. |
| mini_all | Trophy Wall (hidden) | Snuff all six house champions (tracked in `Game.records["minis_beaten"]`). |

## Determinism and Save & Continue
- Placement runs in `FloorGen.generate` after the hollow, from the same floor RNG, so Tonight's Candle
  builds the same house for everyone. Loot (relics, tunes, font payouts, wave lodgers) uses `world.rng`
  (the loot RNG). Room state lives in the cell dictionaries (`rung`, `wave`, `fed`, `toll`, `cranks`...).
- Run-long state (`font_uses`, champions beaten this run) is saved through `world.save_extra()` /
  `load_extra()` (`"specials"` key). A continued run rebuilds the floor from its seed, so a floor's rooms
  come back fresh, as every other room does.

## Files
- `scripts/game/specials.gd` (new): room data, dressing, logic, offers (`Specials.Offer extends Pickup`),
  mini-bosses, `pick_relic`, the bot's `bot_target`, the tour.
- `scripts/game/floor_gen.gd`: `_add_specials`, `_add_mini`.
- `tools/art_specials.py` (new) -> `assets/art/specials/` (127 files).

### Hooks in other files (one or two lines each)
- `world.gd`: `_build_room` -> `Specials.on_build(self, r)`; `_on_enter_room` -> `if Specials.on_enter_room(self): return`
  (a champion room handles its own entry); end of `_clear_room` -> `Specials.on_clear(self)`;
  `_spawn_pickup_node` -> `var p: Pickup = Specials.new_pickup(rec)` (offers rebuild as offers);
  `save_extra` / `load_extra` -> `"specials"`.
- `room.gd`: door style (`elif Specials.door_style(ntype, data["type"]) != ""`), door art from
  `specials/door_<dir>_<style>_<state>`, and in `shot_hits` a player shot on the prop cell calls
  `Specials.prop_shot` (rings the bell).
- `pickup.gd`: a paid `cost_wax` record with a `"pact"` key calls `Specials.on_pact()` instead of setting
  `world.pact = "smoke"` (so the mirror does not count as a Smoke Altar pact).
- `room_decor.gd`: special rooms get 2 fewer decor lights (their prop has a light), like shops.
- `hud.gd`: `_draw_minimap` -> `Specials.draw_map_mark(minimap, world, d, pos)`.
- `achievements.gd`: six entries in `LIST`.
- `autotest.gd`: `--tour --specials`, and in `drive()` `Specials.bot_target(w)`.
- `enemy.gd`: untouched. The champion is an ordinary `Enemy` scaled after `_ready` (frames, hp, radius,
  shadow, light); its extra attack runs from `Specials` on enemy time (`e.later`, `time_scale_enemies`).

## For other streams
- `Specials.TYPES`, `Specials.INFO` (name / sub / floors / chance / hint), `Specials.MINIS` (name, sub,
  floor, extra) for the Journal. `Specials.is_special(type)`, `Specials.known(world, cell)`.
- Sounds used (all exist): `bell_toll`, `bell_small`, `summon`, `snuff_out`, `door_burst`, `dodge`,
  `coin_pickup`, `clock_tick_fast`, `unlock`, `wax_bubble`, `bomb_pickup`, `item_get`, `relic_fanfare`,
  `sizzle`, `chest_open`, `page_flip`, `boss_roar`, `gib`, `enemy_shoot`, `burn_whoosh`, `thud_heavy`, `splash`.
  Audio stream: a short music-box tune (`music_box_tune`) and a glass crack (`glass_crack`) would suit.
- Endgame stream: special rooms roll only on floors listed in `INFO[t]["floors"]` (1-4); champions on 2-4.
- The bot: rings the bell when it has more than 65 wax, winds the box twice when it has 9+ coins,
  feeds the font twice above 75 wax, all within 14 s of entering; it takes offers like pickups.

## Art (`python3 tools/art_specials.py [--review=<dir>]`)
Everything is drawn as character grids in the 0x72 palette (the tool asserts palette and alpha), 1 px
#222222 outline, light from the top-left, solid contact shadows.
- Doors (5 styles x 4 sides x open/closed) reuse the frame, leaf and corridor rules of `art_rooms.py`, so
  they line up with every wall: slate-blue stone + brass bell (Seance), black stone + pewter + cracked glass
  (Mirror), rose lacquer + gold winding key (Music Box), green stone + open book (Study), pale wax with
  drips (Font).
- Props: bell frame (4 swing frames + rung out), pier glass (glint loop, veiled, shattered), music box
  (crank + dancer loop, sprung), lectern (page lifts), font (7 wax levels + spent), chalk ring, candle stub,
  glass shards, three offer icons, six map marks + "?".
- Champions: every frame of the six lodgers at 2x with Scale2x (no new colours, clean diagonals), then the
  outline, now 2 px thick, is thinned back to 1 px so they match the house's art.
- No third-party assets added.

## Tests
See the end of this file (filled in when the stream finished).
