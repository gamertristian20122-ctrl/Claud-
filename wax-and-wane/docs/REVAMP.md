# Wax & Wane 2.0: the revamp brief

The owner wants v1.1 turned into a game they can sell on **Steam, itch.io and Google Play**: one that
looks, sounds and plays like a polished indie roguelite in the room-to-room twin-stick genre. Every work
stream reads this file first, then `README.md`, `DESIGN.md` and `CLAUDE.md`.

## The bar
- **Juicy and alive.** Every action has feedback: squash and stretch, hit-flash, sparks, stains that stay
  on the floor, sounds with variation, screen shake and hit-stop in proportion. Rooms are full of hand-placed
  detail, flickering wall lights and drifting dust. Nothing sits still and nothing is silent.
- **Deep.** Many relics that change how you play and combine in surprising ways. A real bestiary and
  bosses with readable, telegraphed patterns. Secrets, unlocks and a journal so the game rewards
  hundreds of runs.
- **Readable on a phone and on a monitor.** It has to work with touch, keyboard and mouse, and a gamepad
  (Steam Deck). Wax = health = clock (12:00 AM full, 2:00 AM out) stays obvious at all times.
- **Original.** We work in the genre but copy no names, characters, art, music or level layouts from
  any existing game. Our identity: a living candle in a haunted house, wax, wicks, soot, bells and clocks.
- **Never looks AI-made.** One pixel-art style built on the 0x72 DungeonTileset II palette (see
  `DESIGN.md`): 1 px dark outline, light from the top-left, no anti-aliasing, no gradients on sprites, no
  blurry scaling, no mixed art styles. Text is short, specific and in the game's voice, never generic.

## Engine facts that bite
- Godot 4.7.2, GL Compatibility, 384x216 viewport (phones show about 480x216), integer scaling, nearest filtering.
- Rooms are 272x192 images. The interior is 15x9 tiles at (16,32). The camera is fixed per room. Objects
  in a room are children of the `Room` node (room-local). **Movement and collision use `global_position`
  against `Room.blocked(world_pos, r)`.**
- Floors and loot use seeded RNGs (`hash("%d:%d" % [run_seed, n])`; loot `hash("%d:loot:%d")`).
  Keep anything new deterministic from those seeds so Tonight's Candle (the daily) stays the same for everyone.
- Text uses Kenney Pixel (8/16 px). Shared UI helpers are in `scripts/ui/ui.gd`; art loads through
  `Art.tex("folder/name")` and `Art.has()`; sounds through `Audio.play(name, db, pitch_var, pitch)`.
- GDScript: give variables explicit types where inference fails ("Cannot infer type" errors). A new
  `class_name` needs `godot --headless --path . --import` before other scripts can see it.

## How the streams work
Each stream runs in its **own git worktree**. When you start:
1. `cd <worktree>/wax-and-wane`, create your branch (`git checkout -b revamp/<stream>`), and run
   `godot --headless --path . --import` once. It takes a minute or two.
2. Do your work. **Commit often** on your branch. Your final commit must include everything.
3. Before you finish, all of these must pass:
   - `godot --headless --path . -- --checkscripts` (no errors)
   - `stdbuf -o0 godot --headless --path . -- --autotest --playtest --speed=4 --runs=2 --god` (both runs
     reach the end; `--god` makes the bot unkillable)
   - one normal `--playtest --speed=4 --runs=2`, which must not crash
   - a screenshot tour (`xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3
     --resolution 1600x720 -- --autotest --tour --shots=/abs/dir`). **Look at the screenshots yourself** and
     fix anything ugly, broken or unreadable.
4. Report your branch name, the final commit hash, what you built, the files you touched, new hooks other
   streams need to know about, and a list of 2–4 screenshot paths that best show your work.

### Merge-safety rules (several streams edit the same codebase at once)
- Stay inside your **owned files** (listed per stream). In someone else's file, keep edits to a few lines.
  A one-line call into your own code is ideal, e.g. `Juice.on_enemy_killed(self, e)`.
- Put new systems in **new files** (`scripts/game/<thing>.gd`, `tools/art_<thing>.py`, `assets/art/<folder>/`).
- Never reformat, reorder or rename existing code you don't own. Don't rename existing asset files.
- Don't edit `README.md`, `CLAUDE.md` or `DESIGN.md`. Write your notes, including credits for new free
  assets, to `docs/streams/<stream>.md`. The integrator merges the docs.
- Do keep `scripts/autotest.gd` working. You may add to it, for example a tour shot of your feature, or
  teaching the bot to handle a new mechanic.
- Don't bump the version and don't build APKs: the integrator does both.
- Free assets: only **CC0 / MIT / OFL**. The library at `/opt/assets/jra` and its catalogue
  `/opt/assets/jra_files.txt` (repo `series-ai/jam-ready-assets`) are available. Download a file with
  `curl -L https://media.githubusercontent.com/media/series-ai/jam-ready-assets/main/<path>`
  (git LFS is blocked). opengameart.org is reachable too. Put each licence text in `assets/licenses/`.

## Streams (round 1)
| Stream | Owns |
|---|---|
| `juice` | `player.gd`, `shot.gd` visuals, `main.gd` screen transitions, `title.gd` presentation, new `scripts/game/juice*.gd` / fx files, the `fx_*` section at the bottom of `world.gd` |
| `rooms` | `room.gd`, `room_templates.gd`, `floor_gen.gd`, `tools/art_rooms.py`, new `tools/art_decor.py`, `assets/art/rooms/` |
| `relics` | `items.gd`, `pickup.gd`, new `scripts/game/relic_fx.gd` + costume overlays, `tools/art_items*.py`, `assets/art/items/` |
| `bestiary` | `enemy.gd`, new `scripts/game/enemies/*`, `world.gd` `FLOORS`/`POOLS` + boss choice, `tools/art_monsters.py`, `assets/art/monsters/` |
| `platform` | new `scripts/autoload/controls.gd`, the input + layout parts of `hud.gd`, `settings_panel.gd`, `game.gd` settings/save, `export_presets.cfg`, desktop build scripts, save & continue |
| `audio` | `audio.gd`, `assets/audio/`, `tools/make_audio.py`, new `tools/import_audio.py`, `default_bus_layout.tres` |
