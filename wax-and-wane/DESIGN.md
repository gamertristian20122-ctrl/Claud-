# Wax & Wane — design + asset contract

Android landscape roguelite in the room-to-room, twin-stick dungeon-crawler genre (Godot 4.7.2, GL Compatibility).
Everything here is original: our own hero, names, items, story. Art base = **0x72 DungeonTileset II (CC0)**.

## Pitch
You are **Tallow**, a small living candle. At midnight the old house's cellar wakes up.
Your wax is your health *and* your clock: it burns down every second, enemies melt it faster, wax
drippings rebuild it. The HUD clock runs from **12:00 AM** to **2:00 AM**. When it strikes two, your
flame goes out. Burn down through 4 floors and snuff the **Hour Fiend** before 2 AM.
As your wax shrinks, your sprite gets shorter and **your light radius shrinks** (the room gets darker).

## Screen / world geometry (all in game pixels)
- Base viewport 384x216, stretch mode `viewport`, aspect `expand`, integer scaling. Phones show ~480x216.
- Tile = 16 px. A room image is **272 x 192**: interior floor = 15x9 tiles at rect (16, 32, 240, 144).
  Left wall x 0..16, right wall x 256..272, top wall y 0..32 (2 tiles: cap + face), bottom wall y 176..192.
- Door slots (door sprite top-left positions, inside the room image):
  top `(120, 0)` 32x32 · bottom `(120, 176)` 32x16 · left `(0, 88)` 16x32 · right `(256, 88)` 16x32.
- Camera is fixed on the room centre; rooms are adjacent on a grid; only the current room is visible.

## Palette
Use the 0x72 palette only (extracted from `art_source/0x72_DungeonTilesetII_v1.7.png`), main colours:
`#222222 #483b3a #fdf7ed #da4e38 #775c55 #8f4029 #3d734f #aa8d7a #72d6ce #4ba747 #facb3e #62232f
#314152 #d3bfa9 #9f294e #5698cc #ee8e2e #417089 #49a790 #c56025 #fccba3 #d8a57d #5956bd #5f2d56
#333333 #b58057 #111111 #97da3f #b6cbcf #2a2a3a #c38d70 #8a503e #dc4a7b #e2b694 #21141b #e46e33`.
Style rules: 1 px dark outline (#222222 / #21141b) like the 0x72 characters, light from the top-left,
no anti-aliasing, no gradients, no semi-transparent pixels except glow sprites in `assets/art/light/`.

## Asset contract (exact paths; game code loads these names)
All PNG, RGBA, pixel-exact. `assets/art/...`:

### Hero (hero/)
- `flame_f0..f5.png` 9x13: candle flame loop (white-yellow core, #facb3e, #ee8e2e, #da4e38 tips). Base of flame
  (the wick point) is the bottom-centre pixel (4, 12).
- `flame_blue_f0..f5.png` same, blue flame (#cae6f5 core, #72d6ce, #5698cc, #5956bd).
- Candle body is drawn in code (wax colours #fdf7ed / #e2b694 / #d8a57d / #b58057 outline #483b3a).
- `holder.png` 18x7: brass candle dish (#facb3e/#ee8e2e/#c56025/#8f4029) with a small ring handle on the right.
- `face_open.png`, `face_blink.png`, `face_hurt.png`, `face_happy.png` 10x5: eyes (+tiny mouth) drawn on wax, transparent bg.
- `drip_f0..f2.png` 3x6 wax drip that slides down the side (optional flavour).

### FX (fx/)
- `ember_f0..f3.png` 7x7 player shot (fire spark), `ember_blue_f0..f3.png` blue version.
- `poof_f0..f4.png` 12x12 shot impact / smoke puff.
- `bullet_purple_f0..f1.png`, `bullet_green_f0..f1.png`, `bullet_water_f0..f1.png` 7x7 enemy shots.
- `explosion_f0..f6.png` 48x48 bomb blast. `scorch.png` 32x20 floor scorch decal.
- `smoke_f0..f3.png` 9x12 rising smoke wisp (when the hero is snuffed / candelabra lit).
- `light/soft_light.png` 256x256 radial white glow, smooth alpha falloff (this one may be smooth).

### Pickups (pickups/)
- `wax_small.png` 9x9 (a wax drop), `wax_big.png` 11x14 (a fresh candle stub), `bomb_pickup.png` (0x72 bomb ok),
  `coin` = use 0x72 `coin_anim`. `match_f0..f3.png` 6x12 "matchstick" pickup (optional).
- `pedestal.png` 20x12 stone item pedestal.

### Relic icons (items/) 16x16, readable at 1x on a dark background
`beeswax twin_wick blue_flame bellows lamp_oil soft_soles wax_coat ember_heart sharp_wick moth_friend
slow_burn matchbook hourglass candelabra hot_drip phoenix_feather lucky_ash will_o_wisp witching_hour
pocket_watch iron_stick snuffer_cap tallow_heart spare_wick` (`<id>.png`).

### Rooms (rooms/)
- `room_<theme>.png` 272x192 for themes `cellar` (brown stone), `crypt` (grey-blue stone), `chapel`
  (purple stone, banners), `belfry` (dark red/brown wood + stone). Built from 0x72 wall + floor tiles,
  floor varied (floor_1..8, cracks), walls full ring, **no door openings** (doors are overlaid).
- Doors per theme-independent style: `door_<dir>_<state>.png`, dir = top/bottom/left/right,
  state = open/closed, plus `door_<dir>_boss_<state>.png` (red, skull) and `door_<dir>_gold_<state>.png`
  (treasure). Sizes per slot above. "open" shows a dark passage; "closed" shows door leaves/bars.
- Obstacles 16x16 (anchored top-left on the tile): `rock.png`, `rock_b.png` (variant), `urn.png`
  (breakable), `urn_broken.png`, `pit.png` (dark hole), plus 0x72 `crate`, `column`, `skull`, `floor_spikes_anim`.
- `candelabra_unlit.png` 16x24 and `candelabra_lit_f0..f3.png` 16x24 (3 small flames): stand in room corners and
  light up when a room is cleared.
- `trapdoor_closed.png`, `trapdoor_open.png` 32x32 (hole/ladder down to the next floor; 0x72 floor_ladder ok).
- Decals 16x16 or smaller: `decal_crack_0..3.png`, `decal_cobweb.png`, `decal_bones.png`, `decal_wax_puddle.png`.

### UI (ui/)
- `clock_bar_frame.png` + pieces for the wax/time bar: a horizontal candle (lying down) ~150x14 that burns from the right.
  Provide `bar_wax_fill.png` (1 px wide column, tileable horizontally), `bar_frame_left.png`, `bar_frame_right.png`.
- `icon_coin.png`, `icon_bomb.png` 9x9, `btn_pause.png` 13x13, `btn_bomb.png` 22x22, `stick_base.png` 40x40,
  `stick_knob.png` 18x18 (pixel style, semi-transparent allowed), `panel_9.png` 24x24 nine-patch (stone/parchment)
  with 8 px margins, `button_9.png` 24x16 nine-patch with 6 px margins (+ `button_9_pressed.png`).
- `minimap_room.png` 7x5 etc. optional. `title_logo.png` "WAX & WANE" hand-pixelled logo ≤ 220x60.
- `app_icon_192.png`, `app_icon_fg_432.png`, `app_icon_bg_432.png` (Android launcher + adaptive).

### Audio (audio/)
`sfx/<name>.ogg` mono, peak-normalised, trimmed:
`shoot hit_wall hit_enemy enemy_die enemy_shoot player_hurt wax_pickup coin_pickup bomb_pickup bomb_place
explosion door_open door_close room_clear item_get chest_open urn_break crate_break boss_roar boss_die
bell_toll tick ui_click ui_back ui_open low_wax snuff_out victory shop_buy step charge teleport splash
trapdoor`
`music/<name>.ogg` loops: `title`, `floor_1` .. `floor_4` (can share), `boss`, `final_boss`, `victory_jingle`, `death_jingle`.

## Fonts
`assets/fonts/kenney_pixel.ttf`, `kenney_mini.ttf` (CC0). UI text sizes in game pixels: 8 / 16.

## Credits rule
Every third-party asset goes into `assets/licenses/` + `README.md` → Credits + the in-game Credits screen.
