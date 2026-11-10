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
`<name>_f0..fN.png`.

**Since 2.10 (the owner's rule: "don't generate anything", keep the candles):** only the candles are still drawn
by scripts: `hero/`, `items/costume/`, the flames and sparks in `items/fx/`, `pickups/match`,
`tower/holder_silver*` and the app icon. Every other picture is a found one from a human-made CC0 pack, put
under the same file names by `python3 tools/free_art.py` (a pack file, a crop of one, or whole pieces laid edge
to edge; no pixel changed; the table in that tool says what each file is, and
`assets/licenses/CREDITS_free_art.txt` lists every file). A picture that is not there shows nothing
(`Art._placeholder`), and a few things are plain shapes the game draws itself (`Stains._shape`, `UIShapes`, the
flat menu boxes in `UI.FLAT`). So the sections below are the file names and sizes the code expects; where they
describe how a picture was drawn, that is the 2.9 art and history now. The drawing scripts that are left
(`art_hero_fx_items.py`, `art_items2.py`, `art_talk.py`, `art_tower.py`, `art_icon.py` and the helpers they
import) still write the old pictures too: run `tools/free_art.py` after any of them.

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
  v2.7 (`art_talk.py`, the talking scenes): `face_<open|worried|tired|happy>_talk` (the other mouth for the 2-frame
  talk), `face_teary`, `face_teary_talk`, `face_blink_teary` (worried eyes, a #cae6f5 / #72d6ce tear under each),
  built from the concept's own eyes and mouths.
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

### The Long Night's areas (areas/<area>/) - `art_areas.py` (v2.2, docs/streams/v22_areas.md)
- Rooms `rooms/room_<kitchen|library|attic>(_1|_2).png` (Kitchen: orange brick caps, a cream-and-blue tiled
  backsplash, quarry tiles / a slate-and-terracotta scullery / flags round a rag rug; Library: green caps, damask over a
  walnut dado, a green carpet / a runner / a compass star; Attic: pine caps, planks and rafters, pale dusty boards /
  a loft hatch / a dressmaker's patterns). Sconces `decor/sconce_<area>_top|side`, wall pieces `decor/wall_<area>_*`,
  side pieces `decor/side_<area>`, furniture `decor/prop_<area>_*` (Kitchen tables `_l/_m/_r`, range, block, sacks;
  Library shelves `_l/_m/_r`, the sliding shelf `prop_library_slide`, desk, globe, book stack; Attic dust sheets
  `sheet_a/b/c` over a wardrobe, chair and mirror, and the trunk).
- `areas/<area>/floor_*` and `foot_*` floor / wall-foot decals; gimmick props: `kitchen/stove` + `stove_glow_f0..2`
  (warning, hot), `kitchen/pot` + `pot_steam_f0..3` + `pot_spilt`, `kitchen/scald_f0..2` 32x20 (drawn unlit),
  `kitchen/flour_f0..3` 24x20, `library/rail_l|m|r`, `library/shelfdoor_f0..3` 32x30, `attic/lantern_off|on|glow`
  10x15, `attic/window_round(_glass)` 22x22, `attic/sheet_fly_f0..3` 20x16, `attic/light/moon_round.png` (light texture).
- Creatures `areas/<area>/<name>_<idle|run|atk>_f0..3` (Enemy.DEFS `sprite` = "areas/<area>/<name>"):
  lid_crab, flour_ghost (Kitchen), bookworm, inkblot, ink_drop (Library), mannequin, trunk (Attic) 16x16 to 16x22;
  guardians stockpot 44x40, librarian 32x52, dress_form 40x48. Enemy shot `fx/bolt_pin_f0..1` 7x7 (UX-02 recipe).

### The talking scenes (talk/) - `art_talk.py` (v2.7, docs/streams/v27_dialogue.md)
- `martha_f0|f1|blink|smile.png` 24x24: Martha Fenn as a memory, a sepia bust (the palette's warm browns only), shown
  x2 in a talk portrait (mouth shut / open, a blink, eyes creased in a smile).
- `martha_stand|match|light.png` 36x52: Martha at her kitchen table (story/end_kitchen scale), facing right: hands
  folded, a struck match held up, a long match reaching to the wick (its flame at (32, 2)).
- `open_cellar.png` 192x96: the opening's cellar (stone walls, flags, the stairs up to a lit door, barrels, the coal
  heap, Martha's chalk circle); the opening lights it from the candle in code.
- Guardians' talk portraits are their own first idle frame, a 24x24 crop x2 (`TalkLines.SPEAKERS` "crop").

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
- v2.6 UI kit, `art_ui2.py` ("candlelit wood and brass"; how it is used: `docs/streams/v26_gui.md`). Nine-patches
  (margins in brackets): `kit_panel.png` 24x24 [8] mahogany frame + brass corner brackets, `kit_drip.png` 30x11 /
  `kit_drip_small.png` 15x11 wax poured on a panel's top rail (overlays), `kit_card.png` 12x12 [4], `kit_inset.png`
  10x10 [3], `kit_plate.png` 16x16 [5] brass plate, `kit_strip.png` 16x12 [5/4] dark ribbon with brass ends;
  buttons 24x24 [6/6/6/7] `kit_btn(_hover|_pressed).png` dark oak, `kit_btn_primary(...)` brass,
  `kit_btn_danger(...)` red wax, `kit_btn_disabled.png`; `kit_focus.png` 12x12 [4] gold ring (drawn 2 px outside),
  `kit_focus_flame.png` 7x10; `kit_tab(_on).png` 16x16 [5/5/5/4]; `kit_track(_fill).png` 12x7 [4/3],
  `kit_knob.png` 7x10 flame knob; `kit_switch_on|off.png` 20x11; `kit_orn_l|r.png` 18x7 heading flourishes,
  `kit_sep.png` + `kit_sep_gem.png` 7x7; `kit_slot.png` 18x18 [3] icon socket; `kit_seal.png` 12x12, `kit_medal.png`
  15x15. HUD: `hud_digits.png` / `hud_digits_hot.png` 88x12 (0-9 and ':' in 8x12 cells, drawn 7 px apart, the
  colon 4), `hud_clockplate.png` 12x12 [4], `hud_chip.png` 10x10 [3], `hud_coin.png` / `hud_bomb.png` 12x12,
  `boss_frame.png` 16x10 [5/4]. Icons 11x11: `ico_journal|seed|settings|credits|quit|flame|flame_dark|moon|clock|
  stairs|skull|page|relic|rooms|back`. Title: `title_books.png` 36x16 (Tallow's stand).
- v2.7 controls primer (primer/) - `art_primer.py`: `thumb.png` 11x18 (a thumb, nail first), `key.png` /
  `key_down.png` 16x16 nine-patches [5/5/5/6] (an ivory keycap, the pressed one lit gold and 1 px lower; words drawn
  in code), `pad.png` 48x30 (a gamepad from above) + `pad_cap(_on).png` 7x7 + `pad_lb|rb|lt|rt.png` overlays,
  `mouse.png` / `mouse_left.png` 11x16, the wax dummy `dummy_f0..f2.png` 18x26 (sway frames) + `dummy_hit.png`.

### Audio (audio/)
- `sfx/<name>.ogg` or `.wav`: since 2.10 each is ONE pack file, copied byte for byte by `tools/free_sounds.py`
  (nothing layered, synthesized, trimmed or re-encoded). `scripts/autoload/sfx_pack.gd`, written by that tool,
  holds the dB that brings each file to the level the mix (`Audio.VOLUME`) was made for and the speed it plays
  at. Extra takes `<name>_2`, `<name>_3`... are picked at random by `Audio.play("<name>")`. What each name is
  for: `docs/streams/audio.md`. Unknown names are silent, so new sounds can be called before they exist.
- The low-wax warning is the clock: `low_wax_tick`, struck faster and faster by `Audio._process`.
- `music/<slot>.ogg` loops at -16 LUFS: `title`, `floor_1` .. `floor_5`, `shop`, `boss`, `final_boss`, `ending`,
  plus the one-shot `victory_jingle.wav` and `death_jingle.wav` (the pack's own jingles, as they are). Tracks
  per slot: `assets/licenses/CREDITS_music.txt`.

## Fonts
`assets/fonts/kenney_pixel.ttf`, `kenney_mini.ttf` (CC0). UI text sizes in game pixels: 8 / 16. Text over the
floor gets a 1 px dark outline (`UI.outlined`).

## Credits rule
Every third-party asset goes into `assets/licenses/` + `README.md` → Credits + the in-game Credits screens
(title > Credits and the true ending's credits roll).
