# Wax & Wane — design + asset contract

Landscape roguelite in the room-to-room, twin-stick dungeon-crawler genre (Godot 4.7.2, GL Compatibility).
Everything here is original: our own hero, names, items, story. Art base = **0x72 DungeonTileset II (CC0)**.

## Pitch
You are **Tallow**, a small living candle. At midnight the old house's cellar wakes up.
Your wax is your health *and* your clock: it burns down every second, enemies melt it faster, wax
drippings rebuild it. The HUD clock runs from **12:00 AM** to **2:00 AM**. When it strikes two, your
flame goes out. Burn down through 4 floors (Cellar, Crypt, Chapel, Belfry; two possible guardians each)
and snuff the Belfry's guardian before 2 AM. Do it by **1:00 AM** and a ladder of light leads to the secret
**Clock Tower** and the Keeper of Hours: the true ending.
As your wax shrinks, your sprite gets shorter and **your light radius shrinks** (the room gets darker).
Our identity: a living candle in a haunted house: wax, wicks, soot, bells and clocks.

## Screen / world geometry (all in game pixels)
- Base viewport 384x216, stretch mode `viewport`, aspect `expand`, integer scaling. Phones show ~480x216.
- Tile = 16 px. A room image is **272 x 192**: interior floor = 15x9 tiles at rect (16, 32, 240, 144).
  Left wall x 0..16, right wall x 256..272, top wall y 0..32 (2 tiles: cap + face), bottom wall y 176..192.
- Door slots (door sprite top-left positions, inside the room image):
  top `(120, 0)` 32x32 · bottom `(120, 176)` 32x16 · left `(0, 88)` 16x32 · right `(256, 88)` 16x32.
  Nothing (decor, lights) may overlap a door slot; `--checkrooms` fails if it does.
- Camera is fixed on the room centre; rooms are adjacent on a grid; only the current room is visible.
- Z layers in a room: background -20, decor -19, window glass -18, chalk -17, floor layer -15 (the stain image
  first, then pits, spikes, webs), doors -12, wall flames / hollow cracks -11.
- Light budget: at most 6 static lights per room (`RoomDecor.LIGHT_BUDGET`); only Tallow's light casts shadows.

## Palette
Use the 0x72 palette only (extracted from `art_source/0x72_DungeonTilesetII_v1.7.png`), main colours:
`#222222 #483b3a #fdf7ed #da4e38 #775c55 #8f4029 #3d734f #aa8d7a #72d6ce #4ba747 #facb3e #62232f
#314152 #d3bfa9 #9f294e #5698cc #ee8e2e #417089 #49a790 #c56025 #fccba3 #d8a57d #5956bd #5f2d56
#333333 #b58057 #111111 #97da3f #b6cbcf #2a2a3a #c38d70 #8a503e #dc4a7b #e2b694 #21141b #e46e33`,
plus the sheet's other colours, e.g. `#cae6f5` (pale flame / moonlight), `#f78697` (rose wax), `#7b8994` (pewter).
The art tools check every pixel against all 66 colours of the sheet (`art_rooms.sheet_palette()`) and fail
on anything else.
Style rules: 1 px dark outline (#222222 / #21141b) like the 0x72 characters, light from the top-left,
flat fills with one shade, no anti-aliasing, no gradients, fully opaque pixels. The only smooth,
semi-transparent images are the light textures in `*/light/` folders. Nothing is resampled: the 2x
champions are redrawn (Scale2x, then the outline thinned back to 1 px), and store art is scaled by whole
numbers with nearest-neighbour only.

## Asset contract (exact paths; game code loads these names)
All PNG, RGBA, pixel-exact. `assets/art/...`, loaded with `Art.tex("folder/name")`. Animations are
`<name>_f0..fN.png`. Each folder is written by a re-runnable tool (`python3 tools/art_<x>.py [--review DIR]`).

### Hero (hero/) - `art_hero_fx_items.py --hero` ("Tallow, reborn", concept in `art_source/hero_reborn/`)
- The approved concept's `draw.py` is the source of truth: the tool imports it for the dish, faces and flames.
- Tallow's wax body is drawn in code (`Player.shape()` / `Player.paint_body()`): a gumdrop 13 px wide (15 at
  the belly) with an overhanging lip, a wavy melted edge, a wax tear on each side, two stub arms and rosy
  cheeks; 1 px #21141b outline, light from the top-left. One row melts every 18 minutes of wax, from the
  belly first (120 wax = 12 rows, 72 = 9, 30 = 7, then he sinks into the dish). Each candle in
  `Candles.LIST` sets `body_w`, its four wax colours, `cheek`, and `ink` / `straight` / `foil` / `stripes`.
  Tallow: #fdf7ed wax, #e2b694 shade, #c38d70 deep, #f78697 cheeks. He is self-lit (unshaded) while lit.
- `flame_<idle|trail|flare|mid|small|blown>_f*.png`: 9x12 canvases, the wick tip at (4, 11) left transparent:
  idle 7x10 (4 frames), trail (moving right; mirrored for left), flare (shot / happy), mid 5x8, small 3x5,
  blown (hurt). `flame_blue_<kind>_f*.png` the same in #cae6f5 / #72d6ce / #5698cc / #5956bd.
- `holder_back.png` 19x3 (drawn behind the body at (-9, -7)) and `holder.png` 23x5 (the bowl row, the rim and
  the ring handle, over the body at (-9, -5)); `holder_full.png` 23x7 both. Brass #facb3e/#ee8e2e/#c56025/#8f4029.
- `face_<open|blink|brave|shout|worried|blink_worried|tired|blink_tired|hurt|happy>.png` 11x6: 2x3 eyes and the
  mouth; x = eye centre - 5, y = the eyes' top row. Cheeks are drawn in code in each candle's colour.
- `hero_preview.png` 24x27: the full-wax idle frame (results screen).
- `flame_f0..f5.png` 9x13 (the old flame) stays for the HUD wax bar, the Kindling streak and the title logo.

### FX (fx/) - `art_hero_fx_items.py`, `art_fx2.py`, `art_monsters.py`
- `ember_f0..f3.png` 7x7 player shot, `ember_blue_f0..f3.png` blue version, `ember_big_f0..f3.png` 9x9.
- `poof_f0..f4.png` 12x12 shot impact / smoke puff. `smoke_f0..f3.png` 9x12 rising smoke wisp.
- Enemy shots 7x7, two frames: `bullet_purple`, `bullet_green`, `bullet_water`, `bolt_page`, `bolt_ring`,
  `bolt_wax`, `bolt_bone`, `bolt_cog` (`Shot` loads `fx/<kind>`).
- `explosion_f0..f6.png` 48x48 bomb blast. `scorch.png` 32x20 floor scorch decal.
- `splat_0..9.png` (up to 32x20; 8 and 9 are the boss splats) and `gib_0..5.png` (4-6 px): baked into the
  floor stains, recoloured per creature from its `stain` colour. `glint_f0..1.png` relic glint.
- `light/soft_light.png` 256x256 radial white glow, smooth alpha falloff (light texture).

### Pickups (pickups/)
- `wax_small.png` 9x9 (a wax drop), `wax_big.png` 11x14 (a fresh candle stub), `bomb_pickup.png`,
  coins = 0x72 `coin_anim`, tonics = 0x72 `flask_*` / `flask_big_*`. `match_f0..f3.png` 6x12.
- `pedestal.png` 20x12 stone item pedestal.

### Items (items/) - `art_hero_fx_items.py`, `art_items2.py`
- Relic icons `<id>.png` 16x16 for all 64 relics in `Items.RELICS` (+ `wax_seal`), readable at 1x on a dark
  background. Keepsake icons `ks_<id>.png` 16x16 for the 8 keepsakes.
- Helpers `fam_<bunny|coal|lantern|matchling|mouse>_f0..1.png` (6x6 to 10x14).
- `items/fx/`: relic shot sprites `spark(_blue)_f0..1` 7x7, `ghost_f0..3` / `ring_f0..3` 9x9,
  `bigflame(_blue)_f0..3` 13x14, `jug` 8x9.
- `items/costume/`: pieces worn on Tallow (chimney 17x20, sconce, pipe + `puff_f0..2`, apron, bow, brooch_f0..1,
  key_f0..1, feather, berries, `flame_small_f0..1`), placed by `Costumes._geo()` from the body height.

### Creatures (monsters/) - `art_monsters.py`, `art_monsters_bosses.py`
- `<kind>_<anim>_f0..f3.png`; `idle` and `run` always (4 frames each), optional `atk`, `rise`, `grab`,
  `mound`, `sing`. Feet on the bottom row, centred. `Enemy.frames_for(kind)` uses these first, else the 0x72 frames.
- Sizes: small 16x16, tall 16x18 to 16x22, guardians 32x34 to 48x40, the Keeper 48x56.
- Flat fills, one shade on the back and underside, 2 px eyes, 8-neighbour #222222 outline like the 0x72 creatures.
  Each creature has a distinct silhouette and colour (the Lamp Moth is ash grey so it never reads as Moth Friend).

### Rooms (rooms/) - `art_rooms.py`
- `room_<theme>.png` and variants `room_<theme>_1/_2.png`, 272x192, themes `cellar` (brown stone), `crypt`
  (grey-blue stone), `chapel` (purple stone), `belfry` (dark red/brown wood + stone), `tower` (wainscot,
  brass rail, boards / parquet). Built from 0x72 wall + floor tiles, plain top walls (banners etc. are decor),
  **no door openings** (doors are overlaid).
- Doors: `door_<dir>_<state>.png`, dir = top/bottom/left/right, state = open/closed, plus
  `door_<dir>_boss_<state>.png` (red, skull) and `door_<dir>_gold_<state>.png` (treasure). Sizes per slot above.
- Obstacles 16x16 (anchored top-left on the tile): `rock.png`, `rock_b.png`, `urn.png`, `urn_broken.png`,
  pits `pit_0..15.png` (autotiled by which neighbours are pits: N=1 E=2 S=4 W=8; `pit.png` fallback),
  plus 0x72 `crate`, `column`, `skull`, `floor_spikes_anim`.
- `candelabra_unlit.png` and `candelabra_lit_f0..f3.png` 16x24; `trapdoor_closed.png`, `trapdoor_open.png` 32x32.
- Decals 16x16 or smaller: `decal_crack_0..3.png`, `decal_cobweb.png`, `decal_bones.png`, `decal_wax_puddle.png`.

### Decor (decor/) - `art_decor.py`
Recoloured per theme by the tool; placed from the room seed by `room_decor.gd`, all drawn in one canvas item.
- Top wall face: `wall_*` 16x16 (banners, chains, herbs, holes, niches, webs, goo, rope, gears), 32x16 (shelf,
  votives + `wall_votives_glow_f0..1`, wine rack), windows `wall_window_<a|b|c>` 16x18 + `_glass`, clocks.
- Side walls: `side_*` 8x16. Wall lights: `sconce_<theme>_top` / `_side` with flames `flame_torch_f0..3` 7x8,
  `flame_glass_f*`, `flame_candle_f*` (2-3 px), `fire_f0..3` 10x8 (hearths).
- Floor bits `floor_*` (16x8 to 16x16). Furniture and hazards `prop_*`: barrel, coffin, pew (`_l/_m/_r` runs),
  kneeler, lectern, beam (`_l/_m/_r`), bell, hearth / hearth_cold, oil_jar, skull_pile, soot_rock, web (a-c),
  tower_case 16x30, tower_crate.
- `decor/light/window_pool.png` 48x64: stained-glass light pool (light texture).

### Special rooms (specials/) - `art_specials.py`
- Doors `door_<dir>_<style>_<state>.png`, styles `seance`, `mirror`, `musicbox`, `study`, `font`, same sizes and
  joints as the room doors.
- Props: `bell_f0..3` + `bell_done` 23x31, `mirror_f0..3` / `mirror_veiled` / `mirror_broken` 24x36 + `mirror_shards`,
  `musicbox_f0..3` / `musicbox_broken` 24x25, `lectern_f0..1` 22x30, `font_0..6` + `font_spent` 24x25,
  `seance_circle` 96x52 (chalk ring), `seance_candle` 4x6. Offer icons `offer_<map|tonics|veil>` 16x16.
- Minimap marks `map_<seance|mirror|musicbox|study|font|mini>` 5x4, `map_unknown` ("?") 3x5.
- Champions `mini_<kind>_<idle|run>_f0..3.png` (32x46 max): every frame of the lodger at 2x (Scale2x, no new
  colours), outline thinned back to 1 px.

### Chalk (chalk/) - `art_chalk.py`
`chalk_<move|aim|bomb|keep>_<touch|keys|pad|mouse>.png` and `chalk_wax_time.png` (30x34 to 62x40): the
controls chalked on the first room's floor. Two flat colours only (#d3bfa9 strokes, #b6cbcf accents), fully
opaque; the game draws them at one alpha (0.5), lit like the floor. Lines drop one pixel in ten, never two in a row.

### Clock Tower (tower/) - `art_tower.py`
- `room_keeper.png` 272x192 (the Keeper's room with the great floor dial); tower room backgrounds are
  `rooms/room_tower*.png`; sconces are `decor/sconce_tower_*`.
- `gear_f0..5` 34x34 (wall gears), `window_slats` / `window_slats_glow` 16x16, floor bits `floor_<cogs|key|oil|
  screws|spring|weight>`, `ladder_f0..3` 18x72 (the ladder of light), `holder_silver.png` 23x5 + `holder_silver_back.png` 19x3 (Moonwick's dish, `art_tower.py --holder`).
- True ending scenes `end_house`, `end_dial`, `end_window` 192x96 (shown at x2; moving parts drawn in code).
- `tower/light/moon_slats.png` 64x88: striped moonlight (light texture).
- Round things (gears, dials) are rasterised from fixed integer maths, never resampled.

### UI (ui/) - `art_ui.py`, `art_platform.py`, `art_icon.py`
- Wax/time bar, 14 px tall: `bar_frame_left.png` (10 px), `bar_frame_right.png` (4 px), `bar_wax_fill.png` and
  `bar_wax_empty.png` (1 px wide columns, tiled horizontally).
- `icon_coin.png`, `icon_bomb.png`, `icon_medal.png` / `icon_medal_off.png` 9x9, `btn_pause.png` 13x13,
  `btn_bomb.png` 22x22, `stick_base.png` 40x40, `stick_knob.png` 18x18, `panel_9.png` 24x24 nine-patch with
  8 px margins, `button_9.png` / `button_9_pressed.png` 24x16 nine-patch with 6 px margins.
- Keys / gamepad focus: `focus_9.png` (gold notched ring 1 px outside a button), `focus_slot.png`.
  Cursors: `cursor_arrow.png`, `cursor_cross.png` (scaled by the game's integer pixel scale).
- `title_logo.png` 210x41 "WAX & WANE" hand-pixelled logo. App icons: `app_icon_192.png`, `app_icon_fg_432.png`,
  `app_icon_bg_432.png` (Android adaptive), `app_icon.ico` (Windows, 16-256 px, pixel-exact).

### Audio (audio/)
- `sfx/<name>.ogg` mono, trimmed, loudness-matched; extra takes `<name>_2.ogg`, `<name>_3.ogg`... are picked
  at random by `Audio.play("<name>")`. The full list of names and what each is for: `docs/streams/audio.md`.
  Unknown names are silent, so new sounds can be called before they exist.
- `music/<slot>.ogg` loops at -16 LUFS: `title`, `floor_1` .. `floor_5`, `shop`, `boss`, `final_boss`, `ending`,
  plus the one-shot `victory_jingle` and `death_jingle`. Tracks per slot: `assets/licenses/CREDITS_music.txt`.

## Fonts
`assets/fonts/kenney_pixel.ttf`, `kenney_mini.ttf` (CC0). UI text sizes in game pixels: 8 / 16. Text over the
floor gets a 1 px dark outline (`UI.outlined`).

## Credits rule
Every third-party asset goes into `assets/licenses/` + `README.md` → Credits + the in-game Credits screens
(title > Credits and the true ending's credits roll).
