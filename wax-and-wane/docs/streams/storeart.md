# Stream: storeart (Wax & Wane 2.0, round 3)

Store art and screenshots for Steam, itch.io and Google Play. Branch `revamp/storeart`.

## One command, re-runnable on the final build
```
python3 tools/store_art.py          # renders (about 1.5 min, xvfb), then writes docs/marketing/store_assets/
python3 tools/store_art.py --no-render --review /abs/dir   # rebuild from build/store_raw/ + review sheets
```
Run it again after the Journal and the secret 5th floor are merged. The staging uses ordinary world
calls (`_start_floor`, `_jump`, `spawn_enemy`, `collect_item`, `Specials`), so new content does not
break it. New content does change what some rooms look like: look at `overview.png` again afterwards.

## What I made
- **`scripts/store_shots.gd`** (new) holds the two staging modes. `scripts/autotest.gd` gets only
  additions: two header lines, the mode switch and the dispatch.
  - `--shots-store [--phone]` stages 10 moments from seed 7. Tallow carries a fixed kit (Twin Wick,
    Moth Friend, a Hand Bell one pip short). The moments use fixed rooms and casts:
    1. a Cellar fight in the `fireplaces` layout
    2. the Hour Fiend with its clock hands forced
    3. a Chapel fight in the first room that has stained-glass windows
    4. a Seance wave
    5. the versus card
    6. low wax at 1:45
    7. the treasure choice
    8. the shop
    9. Lit at Both Ends held aloft after a fight
    10. the title
    
    Each shot snaps banners, hints, item previews and floating texts fully on or fully off, so nothing
    is ever caught half-faded. The title hides the records line, the version and any Continue button.
    `--phone` swaps in the touch HUD.
  - `--keyart [--keylayout=wide|tall]` builds the scene in a Crypt room with seed 7:
    - first, lodgers are snuffed to leave stains; gibs and drops are swept up
    - the cast is frozen in place
    - two flames are fired, and the tree pauses mid-flight
    - every other light is dimmed and Tallow's light is made strong but tight
    - a cold light is placed above the guardian
    
    It then captures several framings by changing the window's `content_scale_size`: `full`, `wide`,
    `standard` and `tall`. It also writes `keyart.json` with where everything is. Tuning flags:
    `--keyfloor --keyroom --keyguard --keytint --keydim --keylight --keyenergy --keyradius --keymoon
    --keyhit --keygap`.
- **`tools/store_art.py`** (new) runs the renders one after another, because they share one save
  file. Then it builds:
  - 10 Steam screenshots at x5 (1920 x 1080)
  - 3 Google Play phone shots at x5 (2160 x 1080, 18:9; Play's limit is 2:1)
  - 12 key-art images: every capsule, the hero, the page background, the feature graphic, the itch
    cover and the press key art
  - the logo files (Steam library logo 1280 wide; press 1280 x 720 and 640 x 360)
  - `overview.png`
  
  The capsules are listed in the `CAPSULES` table: size, art scale, crop centre, logo scale and place,
  light pool, edges.
- **`docs/marketing/store_assets/`** holds every file, a `.gdignore` and a `README.md` that says where
  each file is uploaded.

## Sizes checked
All against `docs/marketing/steam_store.md` and the Steamworks pages (Nov 2026):
- header 920x430, small 462x174, main 1232x706, vertical 748x896, page background 1438x810
- library capsule 600x900, library header 920x430
- library hero 3840x1240, with critical content in the centre 860x380 safe area
- library logo "1280 px wide and/or 720 px tall", tight, transparent: so 1280x246, not a 1280x720 canvas
- screenshots 1920x1080, 16:9
- Google Play feature graphic 1024x500, 24-bit PNG with no alpha
- itch cover 630x500

## Known issues and notes for the integrator
- **HUD:** at 16:9 (384 px wide) the floor and relic banner's 220 px band (`hud.gd` `_layout`, y 14-46)
  runs under the right end of the wax bar (y 9-19). It also runs under the left edge of the minimap
  (x 284+). At 432 px wide it only touches the bar. I did not change `hud.gd`. The relic-aloft store shot
  is taken without its banner for this reason. A fix: move the band and labels down about 6 px and
  make the band only as wide as its text, or move the banner below y 48.
- The fights are live, so a re-run can differ from the last by a few frames. `seed()` fixes splats and
  knock-backs, but the bot's timing still varies. The key art pauses the tree, so it comes out
  identical every time.
- Each render plays a seeded run and saves, like the other tours: `runs` goes up and a Continue
  snapshot is written.
- If the Hour Fiend (`big_demon`) is renamed, the boss shots fall back to floor 4's own guardian.
- The press kit lists `key_art_landscape.png` and `key_art_portrait.png`. Those are the main and
  vertical capsules (see the README).

## Best screenshots to look at
- `docs/marketing/store_assets/overview.png`
- `docs/marketing/store_assets/steam/main_capsule_1232x706.png`
- `docs/marketing/store_assets/steam/vertical_capsule_748x896.png`
- `docs/marketing/store_assets/screenshots/02_boss_fight_1920x1080.png`
