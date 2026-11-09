# Stream: v23/moves (Wax & Wane 2.3): special moves for every candle

The owner locked this roadmap item: "Special moves for each candle (Tea Light dash/dodge roll with
i-frames; Party Candle AOE sparkler burst; Altar Pillar ground slam stun; Moonwick short-range
blink/phase; Tallow and Black Taper their own mechanics; an ability button on the mobile UI)".
Spec: `docs/design/ROADMAP_V2.md` section 1 (the moves) and 4a (the strings groundwork). Branch `v23/moves`.

## The moves (`scripts/game/moves.gd`, class `Moves`)

| Candle | Move | What it does | Numbers (`Moves` constants) | Sound / feel |
|---|---|---|---|---|
| Tallow | **Flare Up** | Burn 2 minutes of wax to blaze for 3 s: the light grows, sparks deal x1.5 and set foes alight (big embers), a ring of eight small flames scorches lodgers that touch the candle. Refused below 5 minutes ("Too little wax"). While it is ready in a fight its price marches on the wax bar (the existing `hud.preview_cost`) | cost 2 min, 3 s, x1.5, burn 1.6 s, heat 0.6 x shot damage every 0.3 s within 13 px, cd 10 s | `burn_whoosh` + `fire_crackle`, a light pulse, a spout of sparks, shake 2, "-2 min" |
| Tea Light | **Skip** | A dash in the move direction (aim / facing when standing still), untouchable 0.3 s, a trail of spark stars; it slides along walls and stops at them | 48 px in 0.12 s (sub-stepped, so 4x bot speed cannot tunnel), i-frames 0.3 s, cd 2.5 s | `dodge`, squash into the dash, a camera kick, dust at the feet |
| Party Candle | **Sparkler** | 12 sparks fly out all round: each hits the first foe it meets (2 x shot damage, knockback 150) and pops enemy shots on its way; every enemy shot in the radius pops at once | radius 44 px, 0.2 s flight, 2 x shot damage per spark, cd 8 s | `match_strike` + `burn_whoosh`, a star flash, a light pulse, shake 2.5, hit-stop when 2+ are hit |
| Altar Pillar | **Slam** | Wind-up (rooted, a dashed gold ring closes on the real radius), then a shockwave: 2.5 x shot damage to everything in reach, lodgers shoved a step and stunned, guardians slowed; urns and skull piles break, crates and furniture crack (never oil jars or hearths) | wind-up 0.25 s, radius 40 px, stun 1.2 s (guardians: slow 1.2 s), cd 9 s | `charge` then `thud_heavy`, shockwave ring sprite on the floor, dust ring, shake 5, hit-stop 0.06 |
| Moonwick | **Blink** | Gone and back further on: over pits, spikes, cobwebs, hearths and a single tile of rubble; never through two solid tiles in a row, a wall or a door (it stops in front); lands on the nearest free spot (`Moves.blink_target`) | 56 px, i-frames 0.2 s on arrival, cd 4 s | `teleport`, a moon sparkle out and in, pale specks along the line, a pale ring |
| Black Taper | **Snuff** | The flame goes out for 2 s: the room goes dark round it, lodgers lose track (they seek and circle the spot where it went dark, `Moves.target_of`), the candle moves 15% faster and cannot shoot; it relights with a violet flash and the first volley is a black flame: x3 damage, pierces 3 more | 2 s, +15% speed, x3, pierce +3, cd 9 s | `snuff_out`, smoke wisps, `match_strike` on relight, the black-flame shot (`moves/blackflame`), "Black flame!" + a tiny hit-stop on its first hit |

All moves: never during the hold-aloft pose, the boss card, the melt-down, a pause or a room change;
the cooldown only ticks in play (Player physics after its early return). A press in the last 0.15 s of
the cooldown is kept and fires when the move is back (like the fire buffer). Moves use no seeded RNG
(visual sparkle only uses `randf()`), so seeds and Tonight's Candle are unchanged.

## Input and the HUD
- `special` action (Controls): **Left Shift** or **F**, the mouse **thumb buttons**, gamepad **LT**. The
  keepsake keeps **Q / LB / middle button** (it lost Shift and LT), the bomb keeps E / Space / RB / RT /
  right button. `Controls.glyph("special")` ("SHIFT", "LT", "SPECIAL" on touch).
- **Rebinding** (new, Settings > **Keys**): the special move, the bomb and the keepsake each get a keyboard
  key and a pad button; pick one, press the new key (Esc keeps the old); a key another action uses is
  refused ("Taken: that one is Bomb."); Reset. `Controls.rebind / reset_binds / apply_binds / bound_glyph`,
  saved in `Game.settings["binds"]`. The Controls page's key list follows the binds.
- Hints: the first-run controls line names the candle's move ("Shift: Skip"); the first fight of each
  candle's first two runs in a slot shows `Controls.special_hint()` ("Skip: press SHIFT. A quick dash; ...",
  touch: "tap the big round button"); the chalk start room has a fourth drawing (touch: a big ring with a
  star, keys: SHIFT / F, pad: LT; `tools/art_chalk.py`).
- **Mobile button** (`scripts/game/move_button.gd`, `MoveButton`): the third round button on the right
  edge, under the bomb, in one column with it and the keepsake: 34 px (the bomb is 30), a 42 px hit area
  (nearest centre wins where it meets the bomb's), the move's icon, a stepped ring of 12 segments that
  light up as it recharges, gold when ready with a cream flash ring, red when Flare Up would be refused,
  a shake when a press is turned away. It fires on the press (next physics step); a drag that starts on
  it becomes the aim stick, like the bomb's. Swap sticks moves it to the left edge with the others. With
  keys or a pad: a 30 px icon with the same ring under the keepsake, its key underneath ("SHIFT", "LT").

## Hooks in other files (one line or a few each)
- `player.gd`: `move_cd`, `move_ready()`, `use_move(dir)`, the cooldown tick after the early return,
  `* Moves.speed_k(self)` on the walk target, `* Moves.shot_mult(self)` on a volley's damage,
  `add_child(Moves.new())` in `_ready`. `run_save.gd`: `move_cd` is moment-to-moment (SKIP_PLAYER).
- `world.gd`: `Moves.on_shot_made(s, p)` in `shoot_player` (Flare Up's fire, the black flame).
- `enemy.gd`: the brain and the facing read `Moves.target_of(self, p)` (contact damage still measures
  the real candle); the jumper and the lobber too. `area_ai.gd` / `house_ai.gd`: their direct reads
  of the candle's position go through `Moves.target_of` (the real position unless a Black Taper is
  snuffed; guardians are never fooled).
- `hud.gd`: `move_btn` (made in `_ready`, placed at the end of `_layout`), the `special` action and the
  button's press in `_physics_process`. `candles.gd`: a `move` key per candle. `fx_parts.gd`: two ramps
  (`MOON`, `VOID`). `relic_fx.gd`: `RelicFx.on_move(player, id)`.
- `achievements.gd`: six entries (after `candle_box`). `journal.gd`: `_move_row` in the Candles page.
  `title.gd`: the Candle Box's move name and line. `settings_panel.gd`: the Keys page.
  `controls.gd`, `game.gd` (`binds`), `autotest.gd` (`--movescheck`, `--tour --moves`, the bot line,
  a moves line per run), `project.godot` (the `L` autoload), `export_presets.cfg` (`lang/*.json`).

## For other streams
- `RelicFx.on_move(player, id)` is the synergy hook. Two to start: the **Jet Brooch** charges two strong
  shots when a move is used; a regrowing **Glass Chimney** comes back 4 s sooner.
- Challenge Nights (v2.4) can scale a move through `Moves.cooldown(id)` and the constants; Skipping Stone,
  Last Dance, Heavy Night, Between Moons, The Long Burn and Lights Out all hang off one move each.
- `Moves.fired_frame` (the physics frame a move fired), `Moves.uses` (this run), `Game.records["move_uses"]`
  (per slot, shown in the Journal).

## Achievements (Steam API names in `platform.md`)
| id | Name | Description |
|---|---|---|
| move_skip | Close Shave | Skip right through an enemy shot. |
| move_sparkler | Party Popper | Pop 3 enemy shots with one Sparkler. |
| move_slam | Pillar Drop | Stun 3 lodgers with one Slam. |
| move_blink | Moon Hop | Blink over 3 pits in one room. |
| move_flare | Burning Bright | Snuff 3 creatures during one Flare Up. |
| move_snuff | Through and Through | Run one black flame through 3 foes. |

## Art (`python3 tools/art_moves.py [--review DIR]` -> `assets/art/moves/`)
Six 16x16 icons (skip: a tea light streaking, sparkler: a star burst on a stick, slam: a pillar on cracked
ground, blink: a crescent with sparkles, flare: a big flame, snuff: a brass snuffer and smoke), the spark
star (5x5, 3 frames), the Sparkler's flash (17x17, 3), the Slam's shockwave ring (91x91, 6 frames, r 9 to
43 with a dark rim), Blink's moon sparkle (13x13, 4), the relight flame (9x13, 3) and the black-flame shot
(7x7, 4: the ember's shape in violet-black with a pale core). Every pixel is checked against the 0x72 sheet;
1 px #222222 outline on the icons, none on sparks and flashes (like the game's ember and glint).

## Strings groundwork (ROADMAP 4a)
- `scripts/autoload/i18n.gd`, autoload **`L`** (first in the list): loads every `lang/<code>.json` (a flat
  `{"English source": "text"}` object; keys starting with `@` are notes), registers each with
  `TranslationServer` (so `tr()` and auto-translated Labels work), `L.t(key, args := {})` fills `{name}`
  placeholders. `--lang=xx` tries a table (the Language row comes in 4b).
- `python3 tools/extract_strings.py` writes `lang/en.json` from every `L.t("...")` plus the visible fields
  of the data tables (Candles, Moves, Achievements, Items relics / keepsakes / rites) and reports the old
  code's unwrapped visible strings (`--report` lists them file:line); `--check` fails if `en.json` is stale;
  `--strict FILES` fails on any unwrapped string in those files (every new script of this stream passes).
  Every new visible string of this stream goes through `L.t`.

JUDGE_PLACEHOLDER
