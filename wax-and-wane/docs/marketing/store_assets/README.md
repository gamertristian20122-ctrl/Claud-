# Store assets: Steam, itch.io, Google Play

Every picture here comes from the game itself. The game stages each moment and renders it at its own
pixel size: `scripts/store_shots.gd`, run through `scripts/autotest.gd`. Then `tools/store_art.py`
scales the renders up by whole numbers with nearest-neighbour only: no blur and no smoothing. The
darkness around the key art is stepped and dithered on the game's pixel grid, never a smooth gradient.
The only text on any capsule is the WAX & WANE logo. Steam does not allow review quotes, awards or
"sale" text on capsules.

`overview.png` is a contact sheet of every file, shown at about the size each store displays it.

**Since 2.0.0 the capsules use the "hero" key art:** Tallow about three times bigger than before, in one warm
pool of light, beside the Wax Mother (a guardian made for this game) lit by her own candles. Every run of
`tools/store_art.py` ends with a brightness judge, so the art never sinks into Steam's dark page: each capsule
needs a mean luma of at least 70/255 with fewer than 35% of its pixels below 30. At 2.0.0:

| Capsule | Mean luma | Pixels below 30 |
|---|---:|---:|
| header 920x430 (and library header) | 114.7 | 6.7% |
| small 462x174 | 86.9 | 14.6% |
| main 1232x706 | 108.6 | 9.4% |
| vertical 748x896 | 118.2 | 6.2% |
| library capsule 600x900 | 118.5 | 4.4% |
| library hero 3840x1240 | 80.0 | 19.3% |
| Play feature graphic 1024x500 | 98.2 | 9.8% |
| itch cover 630x500 | 109.7 | 6.4% |

(1.9.3, for comparison: main 34.8 with 68% below 30, header 30.4 / 72%, small 46.1 / 70%, itch cover 31.5 / 72%.)
The page background stays dark and quiet on purpose (Steam draws the page text on it), so it is not judged.
`--review DIR` also writes `small_capsule_on_steam.png`: the small capsule at Steam's real 231 x 87 and
184 x 69 sizes on Steam's #1b2838 page.

## Re-make everything (after the final build)

```
cd wax-and-wane
python3 tools/store_art.py --import    # about 2 minutes: imports, renders, then writes every file below
python3 tools/store_art.py             # the same without the import (when no asset changed)
python3 tools/store_art.py --no-render # rebuild from the last renders in build/store_raw/ (seconds)
python3 tools/store_art.py --review /abs/dir   # also: each capsule at the size Steam shows it
```
Needs Godot 4.7.2 on PATH, `xvfb-run`, and Python 3 with Pillow and numpy. Afterwards, open
`overview.png` and the review sheets and check them: no text on top of other text, no half-faded
banners, no empty rooms.

You can also run the renders on their own:
- `-- --autotest --shots-store --shots=/abs/dir` takes the gameplay shots. Run it at
  `--resolution 1920x1080`. Add `--phone` (at 2160x1080) for the touch HUD.
- `-- --autotest --keyart [--keylayout=tall|hero|hero_tall] --shots=/abs/dir` takes the key art
  (`hero` and `hero_tall` are the capsules; `wide` is still used for the page background).
- Each render runs on its own throw-away save profile with every achievement already earned, so no
  first-time toast lands on a picture and a player's save is never touched.

## Steam (Steamworks: Store Page Admin, then Graphical Assets)

| File | Size | Upload as |
|---|---|---|
| `steam/header_capsule_920x430.png` | 920 x 430 | Store assets: **Header Capsule** |
| `steam/small_capsule_462x174.png` | 462 x 174 | Store assets: **Small Capsule** (the logo nearly fills it; Steam makes the 184 and 120 px versions) |
| `steam/main_capsule_1232x706.png` | 1232 x 706 | Store assets: **Main Capsule** |
| `steam/vertical_capsule_748x896.png` | 748 x 896 | Store assets: **Vertical Capsule** |
| `steam/page_background_1438x810.png` | 1438 x 810 | Store assets: **Page Background** (optional; dark and quiet, so it does not compete with the page) |
| `steam/library_capsule_600x900.png` | 600 x 900 | Library assets: **Library Capsule** |
| `steam/library_header_920x430.png` | 920 x 430 | Library assets: **Library Header** (same picture as the header capsule) |
| `steam/library_hero_3840x1240.png` | 3840 x 1240 | Library assets: **Library Hero**. It has no logo or text. Tallow is inside the centre 860 x 380 safe area. |
| `steam/library_logo_1280x246.png` | 1280 x 246 | Library assets: **Library Logo**. It is 1280 wide on a transparent background. In the preview tool, choose **left bottom**: the left of the hero is dark. |
| `screenshots/01_...` to `09_...` | 1920 x 1080 | **Screenshots**, in this order. All nine are gameplay. |
| `screenshots/10_title_1920x1080.png` | 1920 x 1080 | Optional. Steam asks for menus only when they are special, so this one is for press. |

The two icons are already in `../icons/`: `steam_client_256.png` and `steam_community_184.png`.

Steam asks you to mark at least four screenshots as suitable for all ages. Use 02 (boss fight),
05 (boss card), 07 (treasure) and 09 (shop): they have no splats on the floor.

## Google Play (Play Console: Store presence, then Main store listing, then Graphics)

| File | Size | Upload as |
|---|---|---|
| `google_play/feature_graphic_1024x500.png` | 1024 x 500, 24-bit PNG | **Feature graphic** |
| `google_play/phone16x9_01_cellar_fight_1920x1080.png` to `phone16x9_06_relic_aloft_1920x1080.png` | 1920 x 1080, 16:9 | **Phone screenshots**, all six in number order (01 shows the clock and the candle), and the same six as **7-inch and 10-inch tablet screenshots** |
| `google_play/phone_01_..._2160x1080.png` to `phone_03_...` | 2160 x 1080, 2:1 | optional extra phone screenshots |

The phone shots use the touch HUD (sticks, bomb and keepsake buttons, no keyboard letters). Play asks games for
at least four 16:9 landscape screenshots of 1920 x 1080 or more before it recommends them, hence the 16:9 set;
2160 x 1080 (2:1) is the widest phone shape Play accepts at all. The app icon is `../icons/google_play_512.png`.

## itch.io (Edit game, then Uploads and images)

| File | Size | Upload as |
|---|---|---|
| `itch/cover_630x500.png` | 630 x 500 | **Cover image** |
| `screenshots/06_low_wax`, `01`, `02`, `03`, `04`, `07` | 1920 x 1080 | **Screenshots**, in this order (`itch_page.md` puts the low-wax shot first) |

## Press kit (`../press_kit.md`)

| File | Size | Use |
|---|---|---|
| `press/keyart_1920x1080.png`, `press/keyart_3840x2160.png` | 16:9 | Key art with no logo |
| `press/keyart_logo_1920x1080.png` | 1920 x 1080 | Key art with the logo |
| `press/logo_1280x720.png`, `press/logo_640x360.png` | transparent | The logo (press kit sizes) |
| `steam/main_capsule_1232x706.png` | 1232 x 706 | `key_art_landscape.png` in the press kit |
| `steam/vertical_capsule_748x896.png` | 748 x 896 | `key_art_portrait.png` in the press kit |

## What is in the pictures

- **Capsules and key art ("hero"):** the Cellar, warm. Tallow, close up and lit by its own flame, fires two
  flames at the Wax Mother, who is lit by her own candles; one of her Melt Drops waits behind her. A clean
  floor (no splats), so the art also suits the all-ages slots. The landscape capsules use `hero`; the portrait
  ones use `hero_tall` (the Wax Mother behind, Tallow in front).
- **Page background ("wide"):** a Crypt room at night, Tallow in a strong flame light, four lodgers, the
  Sexton in a cold light at the back; dimmed so the page text stays readable.
- **Screenshots** (seed 7, Tallow carrying Twin Wick and Moth Friend):
  1. a Cellar fight
  2. the Hour Fiend's clock hands
  3. the Chapel's stained-glass light
  4. a Seance wave
  5. the Hour Fiend's versus card
  6. low wax at 1:45 AM
  7. the treasure choice
  8. Lit at Both Ends held aloft
  9. the Tallow Merchant's shop
  10. the title screen
