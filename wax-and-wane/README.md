# Wax & Wane

A room-by-room roguelite for Android phones (landscape), made with **Godot 4.7.2** (GL Compatibility).

You are **Tallow**, a small living candle. At midnight the old house wakes up. Your wax is your health
**and** your clock: it melts every second, enemies melt it faster, and wax drippings mend it. The HUD
candle runs from **12:00 AM** to **2:00 AM**. Burn down through four floors and snuff the **Hour Fiend**
before the clock strikes two. The lower your wax, the shorter you get and the smaller your circle of light.

## How to play
- **Left thumb:** move (floating stick). **Right thumb:** shoot in that direction (hold to keep firing).
- **Bomb button** (right edge): breaks rocks, hurts everything nearby, including you.
- **II** (top right): pause. Android Back also pauses.
- Desktop testing: WASD move, arrow keys shoot, Space/E bomb, Esc pause.

## What's in it
| | |
|---|---|
| Floors | The Cellar, The Crypt, The Chapel, The Belfry (8 → 14 rooms each, generated every run) |
| Rooms | 18 hand-made layouts (randomly mirrored), plus start, treasure, shop and boss rooms |
| Enemies | 16 kinds: chasers, hoppers that splash water, archers, chargers, leapers, ring-casters, summoners, flask-throwers, a mimic chest |
| Bosses | Old Rot, The Gaoler, The Hollow Vicar, The Hour Fiend (3 phases: fans, dashes, sweeping clock hands, bell tolls) |
| Relics | 25 (Twin Wick, Blue Flame, Moth Friend, Hourglass, Phoenix Feather, Pocket Watch...) + 4 tonics |
| Other | Shops, chests, mimics, urns and crates, spikes, pits, bombs, candelabras that light up when a room is cleared, bell tolls at 1:00 / 1:30 / 1:45 |

## Project layout
```
project.godot, export_presets.cfg, icon.png
scenes/main.tscn              entry scene; everything else is built in code
scripts/main.gd               screen manager, fades, Android back button
scripts/autoload/             Game (settings, records, save), Audio (music + SFX pool), Art (texture loader)
scripts/game/world.gd         a run: floors, rooms, transitions, spawning, drops, bombs, effects, clock
scripts/game/room.gd          one room: background, doors, obstacles, candelabras, spikes, collision grid
scripts/game/floor_gen.gd     floor layout generator      scripts/game/room_templates.gd   15x9 room layouts
scripts/game/player.gd        Tallow (the wax body is drawn in code and shrinks with your wax)
scripts/game/enemy.gd         every creature and boss     scripts/game/shot.gd   projectiles
scripts/game/items.gd         relics + tonics             scripts/game/pickup.gd wax, coins, chests, shop goods
scripts/game/hud.gd           wax/clock bar, minimap, boss bar, twin-stick touch controls, pause menu
scripts/ui/                   title, results, settings, UI helpers
scripts/autotest.gd           play-test bot + screenshot tour
assets/0x72/frames/           0x72 DungeonTileset II frames (CC0)
assets/art/                   our own pixel art (hero, fx, pickups, relic icons, rooms, UI)
assets/audio/                 sound effects (Kenney, CC0, processed) + synthesized music
tools/                        asset generators (Python) and the APK build script
```

## Commands
```
godot --headless --path . --import                                   # after adding/changing assets
godot --headless --path . -- --checkscripts                           # compile every script
godot --headless --path . -- --autotest --playtest --speed=4 --runs=3 # bot plays full runs, prints a summary
xvfb-run -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720 \
    -- --autotest --tour --shots=/abs/dir                             # screenshots of every screen
./tools/build_apk.sh                                                  # signed APK -> build/WaxAndWane.apk
```

## Signing
This repository is **public**, so the release key is **not** in it. `tools/build_apk.sh` signs with the
owner's private release key from the private `FailedIdolsOfTheAbyss` repo (`keystore/`), expected next to
this repo (`../../FailedIdolsOfTheAbyss/keystore/`). Every update must be signed with that same key.
Bump `version/code` in `export_presets.cfg` for each build you install over an older one.

## Credits & licences
- Dungeon tiles, creatures, chests, coins, bombs, flasks: **0x72 — 16x16 DungeonTileset II** (CC0),
  `assets/licenses/0x72_DungeonTilesetII_CC0.txt`.
- Fonts: **Kenney Pixel** and **Kenney Mini** by Kenney (CC0), `assets/licenses/Kenney_Fonts_CC0.txt`.
- Sound effects: **Kenney** audio packs (CC0) — see `assets/licenses/` and `assets/licenses/CREDITS_audio.txt`.
- Hero, effects, pickups, relic icons, room compositions, UI and logo: original pixel art made for this game
  (`tools/art_*.py`), built from / matched to the 0x72 palette.
- Music: original, synthesized for this game (`tools/make_audio.py`).
- Engine: Godot Engine (MIT).
- Asset packs were obtained via the curated `series-ai/jam-ready-assets` library, which records each
  pack's licence.
