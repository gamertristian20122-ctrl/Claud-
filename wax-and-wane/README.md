# Wax & Wane

A room-by-room roguelite for Android phones (landscape), Windows, Linux and the Steam Deck, made with
**Godot 4.7.2** (GL Compatibility, 384x216 pixels, integer scaling).

You are **Tallow**, a small living candle. At midnight the old house wakes up. Your wax is your health
**and** your clock: it melts every second, enemies melt it faster, and wax drippings mend it. The HUD
candle runs from **12:00 AM** to **2:00 AM** (one minute of wax = one minute on the clock; a full,
unhurt candle lasts about 8 real minutes). Burn down through four floors and snuff the Belfry's
guardian before the clock strikes two. The lower your wax, the shorter you get and the smaller your
circle of light. Once you have won a night, be done by **1:00 AM** and a ladder of light opens to a
secret fifth floor, the **Clock Tower**, and the true ending.

## How to play
The game picks up whatever you touch last (screen, keys, mouse or pad) and changes the on-screen
hints, the chalk drawings in the first room and the button labels to match.

| | Phone (touch) | Keyboard + mouse | Gamepad / Steam Deck |
|---|---|---|---|
| Move | left thumb (floating stick) | W A S D | left stick or d-pad |
| Shoot | right thumb, in that direction (hold to keep firing) | arrow keys, or hold the left mouse button to fire at the cursor | right stick, or Y / A / X / B for up / down / left / right |
| Bomb | bomb button (right edge) | E or Space, right mouse button | RB or RT |
| Keepsake (when its pips are full) | keepsake button (above the bomb) | Q, middle mouse button | LB |
| Special move (v2.3, every candle has its own) | the big round button (under the bomb) | Left Shift or F, a mouse thumb button | LT |
| Pause | II (top right) or Android Back | Esc or P | Start or Back |
| Menus | tap; swipe the Journal grid to turn pages | arrows / WASD, Enter or Space, Esc back, Q / E switch pages | d-pad / left stick, A, B back, LB / RB switch pages |
| Fullscreen | | F11 or Alt+Enter | |

- **Bombs** break rocks, soot rocks and cracked walls (secret Hollows) and hurt everything nearby,
  including you.
- **Save slots and levels**: *Light the wick* opens three save slots. Each keeps its own difficulty level
  (1 Gentle: you melt slower, foes hit softer; 2 Midnight: the game as it was made; 3 Witching Hour: harder;
  4 Two O'Clock: brutal), records, Journal, unlocks, achievements and saved run. An empty slot: *New candle*,
  then pick a level. A used slot: *Continue* (its saved run), *Play*, *Level* (change it between runs; a
  saved run keeps its own level) and *Delete* (asks twice). Tonight's Candle always plays level 2.
  A 2.0 save becomes Slot 1 at level 2 (level 1 if Gentle burn was on); `save_2.0.cfg` keeps the old file.
- **Settings** (title or pause menu, shared by all slots), three pages: *Game* (music, sound, screen shake, vibration,
  effects, FPS counter, fullscreen on desktop), *Controls* (touch sticks AUTO / ON / OFF, swap
  sticks, aim assist, mouse aim on desktop, the key list) and *Keys* (move the special move, the bomb and the
  keepsake to another key or pad button; Reset puts them back). Vibration also rumbles a gamepad.
- **Special moves** (v2.3): each candle has one move on a cooldown. Tallow **Flare Up** (burn 2 minutes of wax
  for 3 s of fire: x1.5 sparks that set foes alight, a ring of heat; refused below 5 minutes), Tea Light
  **Skip** (a 48 px dash, untouchable for 0.3 s), Party Candle **Sparkler** (12 sparks all round that pop
  enemy shots), Altar Pillar **Slam** (a wind-up, then a shockwave that stuns lodgers and slows guardians),
  Moonwick **Blink** (56 px past pits, spikes, cobwebs, hearths and single tiles of rubble), Black Taper
  **Snuff** (2 s dark: lodgers lose track; then a black flame, x3 and piercing). The HUD button shows the
  recharge as a ring of 12 steps and flashes when the move is back.
- **Save & Continue**: the run is saved at the start of every floor (and when the app is paused or the
  window closes). Pause > *Save & quit*, then *Continue* on the title (the slot played last, its floor and clock)
  or on its slot card.
- The first three runs show a short controls hint; the first room of every run has the controls
  chalked on the floor for the device you are using.

## What's in it
| | |
|---|---|
| Floors | The Cellar, The Crypt, The Chapel, The Belfry (8 / 10 / 12 / 14 rooms counting the start, shop, treasure and boss rooms, plus a hidden Hollow and any special rooms; a new house every run from the run seed). Secret 5th floor: **The Clock Tower** (6-8 rooms, one treasure room and the Keeper's room; no shop, Hollow, special rooms or omens) |
| Rooms | 69 hand-made 15x9 layouts, randomly mirrored and weighted by floor (the Cellar likes webs and barrels, the Crypt pits and bones, the Chapel pews and hearths, the Belfry spikes and hard rooms), plus start, treasure, shop, boss, Hollow and special rooms. Furniture (barrels, coffins, pews, beams, long-case clocks), hearths that burn, oil jars that explode and chain, cobwebs that slow walkers, soot rocks that always drop a bomb, skull piles, spikes, pits, urns, crates and hidden chests. Every room is dressed from its seed: wall lights, banners, shelves, stained glass, floor decals. `--checkrooms` checks every layout |
| Special rooms | **The Seance** (floors 1-4, 40%): ring the bell for 3 waves and a boss-pool relic. **The Cracked Mirror** (2-4, 45%): a strong relic for 15 max minutes, for good. **The Music Box** (1-4, 40%): 3 coins a crank, it plays what it likes. **The Study** (2-4, 35%): a keepsake, two tonics or the floor's map. **The Wax Font** (1-4, 30%): feed it 4 minutes at a time; the sixth offering always pays a relic. Each has its own door and minimap mark |
| Lodgers | 35 creatures, each with a name, a line of lore and its own stain colour: 20 from the 0x72 set (Coal-Bin Shambler, Larder Thief, Bone Lodger, Hearth Devil, Hungry Chest...) and 15 of the house's own (Rose Melt, Lamp Moth swarms, Iron Snuffer, Grave Light, Sootling, Waxwork Bride, Cinder Rat, Restless Psalter, Clapper Bat, Deathwatch Beetle, Grave Hand, Gutterspout; Cog Sentry and Minute-Hand Wraith in the tower). Attacks are telegraphed (lanes, rings, flashes). Marked foes (ember / gilded / sooty / chilled) are tougher and pay out wax, coins or bombs |
| Guardians | 12, three per floor, picked by the run seed: Old Rot, The Wax Mother or The Coal Furnace (Cellar), The Gaoler, The Sexton or The Ossuary (Crypt), The Hollow Warden, The Melted Choir or The Organist (Chapel), The Great Pendulum, The Hour Fiend or The Weathercock (Belfry; always the Great Pendulum until your first win, except in seeded runs and Tonight's Candle, where the seed alone picks). The 2.0 and 2.1 guardians have 3 phases each (2.1: fire jets and smouldering coal, a heap of bones that falls apart into rolling skulls, an organ whose pipes play their lanes in turn, a weathervane rooster that blows gales across the room). Every guardian gets a versus card. Secret: **The Keeper of Hours** (Clock Tower: sweeping clock hands, stopped time, chimes) |
| Mini-bosses | 6 house champions, a lodger grown to twice the size with 6x health and one extra attack (floors 2-4, 50% a floor): The Great Sootling, The Bone Landlord, The Kitchen Devil, The Rafter King, The Deathwatch Queen, The Icebox Giant |
| Relics | 64 (24 from 1.x and 40 new: shot changers like Split Wick, Tin Sconce, Old Pipe, Stove Door; showpieces Blowlamp, Pale Taper, Tinderbox; curses Cold Wax, Shadow Puppet, Love Letter, Nightshade; helpers Matchling, Paper Lantern, Dust Bunny, Clockwork Mouse; clock relics Pendulum, Bell Rope, Cuckoo Clock, Minute Hand...). Five quality tiers; each room type (treasure, shop, boss, Smoke Altar, Hollow) draws from its own pool. Many show on Tallow as costume pieces |
| Tonics | 8 unlabelled flasks. Each run they hide 8 of 13 draughts (5 good, 2 bad, 1 odd); you learn one by drinking it. Big flasks are 1.8x stronger, for better or worse |
| Keepsakes | 8, one held at a time, charged by clearing rooms: Hand Bell (freeze), Flare Match (ember ring), Winding Key (+10 min), Smoke Jar (untouchable), Censer (poison), Oil Jug (burning pool), Music Box (charm), Hand Mirror (shots turn back) |
| Candle Rites | 6 set bonuses for holding 3 relics of one Rite: Hearth, Clock, Moth, Many Wicks, Household, Seance. Tallow's look changes with each |
| Candle Box | 6 playable candles with their own clocks and special moves: Tallow (Flare Up); Tea Light (reach the Crypt; Skip); Party Candle (x8 Kindling; Sparkler); Altar Pillar (snuff the Chapel's guardian; Slam); Black Taper (win a run: a short light, but foes out in the dark take 50% more damage, and they flash violet; Snuff); **Moonwick** (still the Keeper of Hours: pale wax, a silver dish, sparks that pierce; Blink) |
| Run twists | **Kindling**: quick kills chain into a streak that pours minutes back in. **Spilled Wax**: a hit splashes wax out to grab back; once a floor a killing blow leaves you **Guttering** at 1 minute. **Omens** (floors 2-4): Cold Draught, Tallow Moon, Long Night, Smoky Halls. **Hollows**: one secret room a floor behind a cracked, wax-seeping wall. **Smoke Altar** after some guardians (buy strong relics with max minutes) or a free **Vigil** gift when you are struggling. The Tallow Merchant's shop, chests, mimics, bell tolls at 1:00, 1:30 and 1:45 |
| Journal | From the title and the pause menu, seven tabs: Relics (64 + keepsakes + Vigil gifts), Lodgers, Guardians, Rooms (special rooms and champions), Candles, Records (totals, best finishes, Tonight's Candle history, the last 20 runs), Diary (Martha's 24 pages in story order). Unseen entries are silhouettes; new ones carry a gold dot |
| Story | Martha Fenn's diary: 24 torn pages in hollows, on marked foes and champions, in the Study, from guardians' first falls, in the Kitchen, Library and Attic and in the Clock Tower; a reading card when the room is calm; endings The Housekeeper, A Candle in Every Window and The Whole Story beside the true ending (`docs/design/STORY.md`, `docs/streams/v25_story.md`) |
| Unlocks and achievements | 18 of the new relics and 2 keepsakes move into the house as you earn achievements. 60 achievements (13 hidden; each save slot earns its own), shown as toasts and listed in Settings; Steam (when GodotSteam is present) gets every slot's achievements |
| Results | A death note (what snuffed you, with its portrait), the run's relics, anything that moved in, and the run's seed to share |
| Tonight's Candle and seeds | **Tonight's Candle**: one seeded house a night, the same for everyone, scored on your first try. **Seed**: type in a friend's seed on the title keypad. Both use the full relic pool, so a seed is the same run for everyone |
| True ending | After a first win, beat the Belfry's guardian by 1:00 AM (as the clock shows it), climb the ladder of light (+5 min), cross the Clock Tower and still the Keeper of Hours: four ending scenes, a credits roll and a results screen marked TRUE ENDING |

## Project layout
```
project.godot, export_presets.cfg (Android, Android Play, Windows Desktop, Linux), icon.png
scenes/main.tscn                  entry scene; everything else is built in code
scripts/main.gd                   screen manager, burn transitions, Android back, --checkscripts / --checkrooms
scripts/autoload/game.gd          Game: settings, the 3 save slots (records + level), save files, VERSION, clock_text()
scripts/autoload/audio.gd         Audio: music slots, SFX takes, dynamic mix, low-wax layer, per-floor reverb
scripts/autoload/art.gd           Art: texture loader (Art.tex / Art.has)
scripts/autoload/controls.gd      Controls: InputMap, last device, focus for keys / pad, cursors, fullscreen
scripts/autoload/achievements.gd  Achievements: list, toasts, Steam bridge (GodotSteam if present)
scripts/game/run_save.gd          RunSave (autoload): Save & Continue, one run per slot (user://runN.cfg)
scripts/game/world.gd             a run: FLOORS / POOLS, rooms, spawning, drops, bombs, the clock, effects
scripts/game/floor_gen.gd         floor layout (shop, treasure, boss, Hollow, special rooms, champion room)
scripts/game/room.gd              one room: background, doors, obstacles, hazards, collision, path_dir()
scripts/game/room_templates.gd    the 69 layouts, FLOOR_LIKES, the --checkrooms validator
scripts/game/room_decor.gd        seeded dressing, wall lights, stained glass, light budget
scripts/game/player.gd            Tallow (wax body drawn in code; squash, drips, melt-down)
scripts/game/costumes.gd          relic costume pieces on Tallow
scripts/game/candles.gd           the Candle Box
scripts/game/enemy.gd             Enemy.DEFS (every creature and guardian), FLOOR_HP, TOUCH, pick_boss
scripts/game/enemies/             house_ai.gd (lodger AIs), boss_ai.gd (guardians), telegraph.gd,
                                  soot_patch.gd, gallery.gd (bestiary review sheets)
scripts/game/keeper.gd            the Clock Tower's creatures and the Keeper of Hours
scripts/game/boss_intro.gd        each guardian's entrance where its fight starts (v2.4), --tour --intros
scripts/game/talk_lines.gd        v2.7: every line of the talking scenes (guardians, Martha, the opening, the endings)
scripts/game/talk_tour.gd         v2.7: --talkcheck, --tour --talk
scripts/game/tower.gd             the Clock Tower: unlock, ladder, floor 5 layout and dressing, true ending hook
scripts/game/areas.gd             the Long Night's areas of the house (Kitchen, Library, Attic + the 2.0 floors), sequence()
scripts/game/area_ai.gd           the areas' lodgers and guardians (the Stockpot, the Head Librarian, the Dressmaker's Form)
scripts/game/area_gimmicks.gd     stove tops, boiling pots, sliding shelves, shelf-doors, lanterns, dust sheets
scripts/game/specials.gd          special rooms, offers and the house champions
scripts/game/items.gd             relics, tonics, keepsakes, rites, Vigil gifts (data + stat relics)
scripts/game/relic_fx.gd          everything relics do live (shots, curses, helpers, tonics, relic pools)
scripts/game/pickup.gd            wax, coins, chests, shop goods, previews, prices
scripts/game/shot.gd              projectiles
scripts/game/juice.gd             game feel: shake, hit-stop, room-clear, boss finale, dust in the light
scripts/game/stains.gd, fx_gibs.gd, fx_parts.gd   floor stains, gibs, particles
scripts/game/boss_card.gd         the versus card
scripts/game/burn.gdshader, flame_lean.gdshader   burn transition, flame lean
scripts/game/chalk.gd             the chalked controls in the first room
scripts/game/records.gd           what the Journal remembers, the death note
scripts/game/unlocks.gd           which relics and keepsakes move in with which achievement
scripts/game/hud.gd               wax / clock bar, minimap, boss bar, touch sticks, pause menu
scripts/game/meta_tour.gd         the --tour --journal screenshot tour
scripts/ui/                       title.gd (menu, Candle Box, seed keypad, credits), slots.gd (the save slots, the level
                                  picker; slots_tour.gd its --tour --slots), results.gd, journal.gd,
                                  ending.gd (true ending + credits roll), settings_panel.gd, key_catcher.gd, ui.gd,
                                  talk.gd + talk_portrait.gd (v2.7 talking scenes), opening.gd (v2.7 story opening)
scripts/autotest.gd               play-test bot, screenshot tours, bench
scripts/audio_check.gd            --audiotest
scripts/store_shots.gd            --shots-store and --keyart staging for the store images
assets/0x72/frames/               0x72 DungeonTileset II frames (CC0)
assets/art/                       our own pixel art (see DESIGN.md for every folder)
assets/audio/                     music/ (12 slots) and sfx/ (74 files)
assets/fonts/, assets/licenses/   Kenney fonts; every licence and per-file credit list
tools/art_*.py                    art generators (rooms, decor, fx, items, monsters, specials, chalk, tower, areas, ui, icon)
tools/import_audio.py, make_audio.py   music import + loudness, SFX and jingles
tools/build_apk.sh, build_aab.sh, build_desktop.sh, android_sdk_setup.sh, store_art.py, steam/
docs/                             REVAMP.md, streams/ (notes per 2.0 work stream), marketing/ (store pages, store_assets/)
```
`android/` (Godot's Android build template, about 230 MB) is git-ignored; `tools/build_aab.sh`
re-creates it from the export templates.

## Commands
Run from `wax-and-wane/`. Add `--speed=4` to anything the bot plays to run it four times faster.
```
godot --headless --path . --import                                   # after adding/changing assets
godot --headless --path . -- --checkscripts                           # compile every script
godot --headless --path . -- --checkrooms                             # validate every layout + dressed room (exit 1 on a problem)
godot --headless --path . -- --autotest --audiotest                   # every sound and music slot + the live mix

# the bot plays full runs and prints a summary ([diag] lines per floor, [stuck] if it stalls)
godot --headless --path . -- --autotest --playtest --speed=4 --runs=3
    --god                 the bot cannot die (does the game reach the end?)
    --seed=N              fixed seeds (consecutive per run)
    --stress              a random relic in every room (ends holding all 64)
    --unlockall --candle=tea_light|party|pillar|black_taper|moonwick   (--candle alone: just that candle unlocked)
    --slot=1-3 --difficulty=1-4   the save slot to play in and its level (fresh profile: the level judge)
    --relics=a,b,c  --keepsake=id    start with these
    --savecycle           Save & quit + Continue at every floor
    --tower [--keeper [--keeperwax=N]]   start in the Clock Tower with a test kit (or at the Keeper)
    --area=kitchen|library|attic|chapel [--areadepth=N] [--areaboss2]   start on a Long Night area (floor 3, a kit); one [area] line per run
    --floors=4..7         the night's length (the Long Night: 7 floors until 3:30 AM; the [playtest] line says floor=5/7 (area))
    --nospecials          no special rooms or champions (balance baseline)
    --nocard              skip the boss versus card
    --nomoves             no special moves (v2.3 balance: the same candle with and without its move)
    --nohop               the bot walks back through cleared rooms instead of hopping from the map (v2.8 baseline)
    --tallhot=a,b,c,d,e   how much faster a tall candle burns, per floor (world.TALL_HOT; one number = every floor;
                          0 = the candle of 2.8, the v2.9 baseline)  --tallknee=0.5  where "tall" starts (TALL_KNEE)
                          Every run also prints a [wax] ledger line: the wax at the end, what the melt took (and how
                          much of that for standing tall), what hits took, what was won back, and the wax on reaching
                          each floor (floor:seconds=wax). Headless debug runs only.
    --boss=<kind>         straight into one guardian's fight with its floor's fixed kit, a line per fight
                          (time to kill, hits; the v2.1 balance check against its floor-mates)
    --device=touch|keyboard|mouse|gamepad,  --touchmouse   input to show / emulate
    --settings=swap_sticks:true,reduce_motion:true,aim:auto,magnet:false   any settings for the run (v2.7 QA)
    --screen=big|classic  v2.8: the picture's path for this run, whatever Settings > Controls > Screen says
                          (scripts/stage.gd, docs/streams/v28_screen.md); a [stage] line prints both scales.
                          --stagekw=N forces Big's world scale (N = the UI's scale must give Classic's picture);
                          --safe=l,t,r,b fakes a display safe area in screen pixels (notches);
                          --rngseed=N seeds the global generator (the same seeds and sparks every run)
    --monkey              a person's random presses on top of the bot (Back, pause, map, moves, menus, focus lost),
                          with a watchdog: [monkey] PROBLEM lines (docs/streams/v27_qa.md)
godot --headless --path . -- --autotest --qacheck                     # v2.7 QA: a probe per bug the QA pass fixed + Back /
                                                                      #   Quick restart regression probes (exit 1 on a FAIL)
godot --headless --path . -- --autotest --bench [--secs=6] [--seed=N] [--ablate]   # CPU per frame, lights, leaks
godot --headless --path . -- --autotest --movescheck                  # v2.3 special moves: every move's numbers, the
                                                                      #   key / touch -> move frame timing, rebinding (exit 1 on a FAIL)
python3 tools/extract_strings.py [--check | --report | --strict FILES]   # lang/en.json from L.t(...) + the data tables
godot --headless --path . -- --autotest --nightdump --speed=4 [--floors=N] [--dump=/abs/file.txt]
                          # every floor of 4 seeded nights, a plain one and Tonight's Candle: layouts, guardians, loot,
                          # lodgers, the floor numbers. At 4 floors it must equal docs/streams/v22_night_baseline.txt
godot --headless --path . -- --autotest --feelcheck                   # v2.6 feel: 90-degree turns, the touch stick, pans,
                                                                      #   inputs kept through a pan, the pickup magnet, Aim: Auto,
                                                                      #   the full map, Quick restart (each a number; PASS/FAIL)
                          # every --playtest run also prints [feel] lines: fight / pickup / walk / walk-back time, pans
godot --headless --path . -- --autotest --pacecheck                   # v2.8 pace: the hurry, the hop from the map, the
                                                                      #   Cellar's litters (25 probes; exit 1 on a FAIL)
godot --headless --path . -- --autotest --diarycheck                  # v2.5 story: every diary page's sources proven,
                                                                      #   no repeats, no reading card in a fight (exit 1 on a FAIL)
godot --headless --path . -- --autotest --ending=<id> [--speed=4] [--shots=/abs/dir]   # stage an ending: true,
                                                                      #   housekeeper, windows, whole_story
godot --headless --path . -- --autotest --talkcheck                   # v2.7 dialogue: every guardian's scenes, never with
                                                                      #   a live foe, Story scenes, Tonight's Candle, the bot,
                                                                      #   saves, the opening, the endings' beats (exit 1 on a FAIL)
XDG_DATA_HOME=/tmp/x godot --headless --path . -- --autotest --primercheck [--device=touch|keyboard|gamepad] [--skiponly]
                          # v2.7 onboarding: a new player's first 3 minutes per device (Light the wick -> first kill,
                          # every teaching text and its repeats), the controls primer with simulated touch / keys /
                          # pad input, Skip, returning slots / Tonight's Candle / seeds, the bot (exit 1 on a FAIL)
    --primer              a --playtest or --tour run gets the controls primer (the bot plays it through)

# screenshot tours (look at the pictures!). 1600x720 = a 480x216 phone screen
xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720 \
    -- --autotest --tour --shots=/abs/dir                             # every screen + one room per floor
    ... --tour --rooms        4 hand-picked layouts per floor
    ... --tour --gallery      every creature and guardian labelled, then each floor's lodgers in a room
    ... --tour --bosses [--only=kind]   each guardian mid-fight
    ... --tour --boss=<kind>  one guardian: its versus card, then two shots in each phase, mid-pattern
    ... --tour --intros[=kind]  every guardian's entrance, two shots each mid-animation, a skip, one with the card
    ... --tour --relictour    costumes, curses, helpers, Blowlamp, pause, shop, treasure, results
    ... --tour --specials     every special room, Seance waves, the champions, the minimap marks
    ... --tour --journal      every Journal tab, death note, seed keypad, credits, chalk start room
    ... --tour --tower        ladder, Clock Tower, the Keeper's phases, the four ending scenes, TRUE ENDING
    ... --tour --areas        the Long Night's new areas: rooms, gimmicks, lodgers, guardian cards and fights
    ... --tour --moves        each candle's special move mid-action, the move button (touch, keys, pad, swapped), the
                              Keys and Controls pages, the Candle Box and the Journal's move line
    ... --tour --night        the Night length picker (Slots, seed keypad), a 7-floor run's HUD next to a 4-floor one,
                              the Kitchen / Library / Attic banners, long-night results and Journal
    ... --tour --diary        a diary page in a room, its reading card (and the card waiting out a fight), the Diary
                              tab, every ending's cards, the results line (docs/streams/v25_story.md)
    ... --tour --talk         v2.7: the story's opening (8 shots), four guardian conversations, a fall with Martha's
                              memory, a later one-liner, the Story scenes row, Watch the beginning, an ending's beat
                              (--talk=all: every guardian's first two lines and every candle's portrait; --talk=candles: just those)
    ... --tour --pace         v2.8: the hurry, the map's rooms to go to (touch, keys), a hop, a busy room's map,
                              two Cellar rooms with litters (docs/streams/v28_pace.md)
    ... --tour --feel         v2.6: the pickup magnet mid-sweep, a hit's mark, Aim: Auto, the full map, the pause menu,
                              Restart, the Aim and Pickup magnet rows (docs/streams/v26_feel.md)
    ... --tour --primer       v2.7: the controls primer's five steps on touch, keys and pad, Swap sticks, Reduce motion,
                              How to play (pause menu, every reel step, the Journal) (docs/streams/v27_onboarding.md)
    ... --tour --platform     Continue, settings, achievements, keyboard / gamepad (also try 1280x800, 1920x1080)
    ... any tour + --layers   v2.8 Screen: Big: next to each shot (the composed screen at the screen's own size) its two
                              buffers, NN_name.world.png and NN_name.ui.png; then `python3 tools/stage_check.py <dir>`
                              rebuilds the screen from them and fails on any pixel that is not a whole-number enlargement
                              (docs/streams/v28_screen.md). --screen=classic gives the 384x216-based shots as before
    ... --tour --slots        the save slots, the level picker, a level 3 run, Level / Delete / Continue (on a copied 2.0
                              profile it checks the move into Slot 1 record by record)
    ... --herosheet           Tallow in every state at x6 (hero_states.png, hero_candles.png; + --costumes / --ingame)
    ... --shots-store [--phone]   staged store screenshots (run at 1920x1080; 2160x1080 for --phone)
    ... --keyart [--keylayout=wide|tall]   the key-art scene, no HUD

python3 tools/store_art.py [--import] [--no-render] [--review /abs/dir]   # every Steam / Play / itch image
./tools/make_trailer.sh all           # trailer + 3 shorts + store loop from the current build -> build/videos/
                                      #   (record / edit / check / stills / voice / audition / voicecheck: docs/marketing/videos.md)
./tools/build_apk.sh                  # signed APK for sideloading -> build/WaxAndWane.apk
./tools/build_aab.sh                  # Google Play bundle -> build/WaxAndWane_v<version>.aab (ends with PLAY-READY)
./tools/build_aab.sh --verify build/X.aab   # checks only
./tools/build_desktop.sh              # build/WaxAndWane_<version>_windows.zip and _linux.zip (+ a headless boot test)
./tools/build_web.sh                  # build/WaxAndWane_<version>_web.zip for itch.io (HTML, viewport 1152 x 648) + a boot
                                      #   test in headless Chromium (tools/web_smoke.js: no console errors, the title draws)
./tools/android_sdk_setup.sh          # Android platform 36 + build-tools 36.1.0 (build_aab.sh runs it)
```
Art tools: `python3 tools/art_<name>.py [--review <dir>]` rebuilds that art and writes contact sheets.
Audio: `python3 tools/import_audio.py music` and `python3 tools/make_audio.py sfx` (see
`docs/streams/audio.md`). Steam upload templates are in `tools/steam/`.

## Signing
This repository is **public**, so the release key is **not** in it. `tools/build_apk.sh` and
`tools/build_aab.sh` sign with the owner's private release key from the private `FailedIdolsOfTheAbyss`
repo (`keystore/`), expected next to this repo (`../../FailedIdolsOfTheAbyss/keystore/`; `build_aab.sh`
also looks in `$KS_DIR` and `~/FailedIdolsOfTheAbyss/keystore`, or takes `KEYSTORE` / `KEYSTORE_USER` /
`KEYSTORE_PASS`). Every update must be signed with that same key. Google Play gets the same key as its
app signing key (`docs/marketing/google_play.md`, section 6), so Play and sideloaded builds update each
other. Desktop builds are not code-signed. Bump `version/code` in the "Android" preset of
`export_presets.cfg` for each build you install over an older one (`build_aab.sh` copies it to
"Android Play").

## Credits & licences
The game itself: `LICENSE` (all rights reserved; source shown for reference). Privacy policy: `PRIVACY.md`
(no data collected; also in the game under Title > Credits > Privacy).

Every licence text the game needs is in `assets/licenses/` (shipped inside every build and in the PC zips'
`licenses/` folder, and shown in the game under Title > Credits > Licences). Every third-party asset in the
game is CC0 1.0 (public domain); the engine is MIT. The only other licence is Apache-2.0 for the trailer's
AI narrator, which is not in the game.
- **Dungeon tiles, the 0x72 creatures and guardians, chests, coins, bombs, flasks**: *16x16 DungeonTileset
  II* by **0x72** (CC0), https://0x72.itch.io/dungeontileset-ii -
  `0x72_DungeonTilesetII_CC0.txt`; how the room art uses it: `CREDITS_rooms.txt`.
- **Fonts**: *Kenney Pixel* and *Kenney Mini* by **Kenney** (CC0), www.kenney.nl - `Kenney_Fonts_CC0.txt`.
- **Sound effects**: layered and processed from **Kenney** Foley Sounds, Impact Sounds, Interface Sounds,
  Retro Sounds 1, Retro Sounds 2 and RPG Audio (CC0) - `Kenney_*_CC0.txt`; plus a few **Ninja
  Adventure** sounds (fire, fireball, wings, spirit, explosion; CC0) and original synthesis. Source of
  every file: `CREDITS_audio.txt`.
- **Music**: *Ninja Adventure Asset Pack* by **Pixel-boy** and **AAA** (CC0),
  https://pixel-boy.itch.io/ninja-adventure-asset-pack - `Ninja_Adventure_CC0.txt`, slots in `CREDITS_music.txt`:

  | Slot | Track |
  |---|---|
  | Title | 22 - Dream |
  | The Cellar | 40 - Crypt |
  | The Crypt | 21 - Dungeon |
  | The Chapel | 12 - Temple |
  | The Belfry | 24 - Final Area |
  | The Kitchen (longer nights) | 14 - Curse |
  | The Library (longer nights) | 30 - Ruins |
  | The Attic (longer nights) | 16 - Melancholia |
  | The Clock Tower | 19 - Ascension |
  | Shop | 39 - Boat |
  | Guardians (floors 1-3) | 17 - Fight |
  | Belfry guardian and the Keeper | 28 - Tension |
  | True ending and credits | 15 - Credit Theme |

  The victory and death jingles are original, synthesized for this game (`tools/make_audio.py`).
- **Engine**: Godot Engine (MIT), https://godotengine.org - `Godot_MIT.txt`; Godot's own third-party notices
  (written by the engine: `Engine.get_copyright_info()` / `get_license_info()`) - `Godot_third_party_notices.txt`.
- **Trailer narration (AI-generated)**: the narrator of the trailer and the shorts is an AI voice made with
  **Kokoro TTS** (*Kokoro-82M* by hexgrad, open weights, Apache-2.0; voice `am_michael`; misaki G2P,
  Apache-2.0), https://huggingface.co/hexgrad/Kokoro-82M - `docs/marketing/voice/Kokoro_TTS_Apache-2.0.txt`
  (kept out of the game builds). Only the videos use it, not the game. The lines and how to swap in a real voice: `docs/marketing/voice/`.
- **Original work**: design, code, the in-game text, Tallow and the other candles, the house's own 22
  lodgers and 13 guardians (the Wax Mother, the Sexton, the Hollow Warden, the Melted Choir, the Great Pendulum,
  the Coal Furnace, the Ossuary, the Organist, the Weathercock, the Stockpot, the Head Librarian, the Dressmaker's
  Form and the Keeper), the special moves' art,
  relic and keepsake icons, costumes, effects, rooms, decor, special rooms, the Clock Tower, chalk
  drawings, UI, logo, app and store icons, and the jingles were made for this game by one developer with
  **Claude** (an AI assistant): the pixel art is drawn by scripts Claude wrote (`tools/art_*.py`,
  `tools/make_audio.py`), built from and matched to the 0x72 palette, and checked by the developer.
  The other 20 lodgers and 3 guardians (Old Rot, the Gaoler, the Hour Fiend) use 0x72's
  sprites. The numbers are counted from the code in `docs/marketing/facts.md`.
- The free packs were obtained through the curated `series-ai/jam-ready-assets` library, which records
  each pack's licence.

The in-game credits (title > Credits, and the true ending's credits roll) list the same.
