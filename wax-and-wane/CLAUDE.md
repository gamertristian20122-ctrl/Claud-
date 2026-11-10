# Wax & Wane — notes for Claude

Landscape roguelite for Android, Windows, Linux and the Steam Deck (Godot 4.7.2, GL Compatibility, 384x216
base viewport, integer pixel scaling). Read `README.md` (content, layout, commands, credits) and `DESIGN.md`
(asset contract, palette, geometry) first. How each 2.0 system works and its hooks: `docs/streams/*.md`.

## About the owner
- Limited coding experience: explain in plain, phone-friendly language with short numbered steps.
- Plays on an Android phone. **Send the APK as soon as a build is done.** Keep zips under 30 MB.
- Keep the work moving; give a short plan, then do it.
- Store wording (2026-11-10): say only what a store requires. No licence words ("CC0") in paste-ready store
  text, and the AI disclosure names only what players see or hear that was made with AI (still all of it, and
  still true). Licences stay recorded in `README.md`, `assets/licenses/` and the in-game Credits.
- **No more videos** (trailer, shorts, loops) unless the owner asks again: the 2.0.0 cuts in `build/videos/` are final.
  2026-11-10, the owner: "forget about the trailer". Do not list a new trailer as something the game needs. On a
  store where no trailer is posted, take the trailer-voice sentence out of the AI disclosure
  (`docs/marketing/steam_store.md` 6, `itch_page.md` 1); everything else in it stays.

## Hard rules
- Original game: never copy names, characters, art or music from existing games. Genre conventions are fine.
- One consistent pixel-art style built on the 0x72 DungeonTileset II palette. No mismatched free art, no blurry
  scaling, no gradients on sprites. Anything that "looks like AI" is a bug.
- Only CC0 / MIT / OFL assets; record each in `README.md` Credits, `assets/licenses/` and the in-game Credits
  (`scripts/ui/title.gd` `_credits` and the credits roll in `scripts/ui/ending.gd` `_credits`).
- This repo is **public**: never commit a keystore or password. `tools/build_apk.sh` and `tools/build_aab.sh`
  sign with the private key from the `FailedIdolsOfTheAbyss` repo (`../../FailedIdolsOfTheAbyss/keystore/`).
- Wax = health = clock (12:00 AM full, 2:00 AM empty). Keep that readable in every change.
  The night never starts before midnight: show times with `Game.clock_text()` (spare wax reads "+N min").
- Keep runs deterministic: floors and loot come from the seeded RNGs (floor RNG, `world.rng`), so Tonight's
  Candle and typed-in seeds are the same house for everyone. Visual-only randomness uses `randf()`.

## Releasing a build
1. Bump the version in three places: `export_presets.cfg`, **"Android" preset** (`version/code` +1,
   `version/name`; `build_aab.sh` copies both into "Android Play", commit the file if it says so; the
   Windows and Linux presets use the project version), `scripts/autoload/game.gd` (`VERSION`) and
   `project.godot` (`config/version`).
2. Check: `--checkscripts`, `--checkrooms`, `--playtest --god --runs=2` (both reach the end), a few normal
   `--playtest` runs, a `--tour` (plus the tour of anything you touched). Look at the screenshots.
3. `./tools/build_apk.sh`, copy to `build/WaxAndWane_vX.Y.Z.apk` (the sideload APK), send it to the owner.
4. `./tools/build_aab.sh` -> `build/WaxAndWane_vX.Y.Z.aab` for Google Play; it must end with `PLAY-READY`.
5. `./tools/build_desktop.sh` -> `build/WaxAndWane_<ver>_windows.zip` / `_linux.zip` for Steam
   (`tools/steam/` templates, one depot per OS) and itch.io. It boots the Linux build as a smoke test.
   `./tools/build_web.sh` -> `build/WaxAndWane_<ver>_web.zip` (itch.io, played in the browser); it boots it in
   headless Chromium and fails on a console error.
6. If anything visible changed: `python3 tools/store_art.py` and check `docs/marketing/store_assets/overview.png`.
7. Commit and push.

## Toolchain (fresh container)
- Godot 4.7.2 on PATH + export templates in `~/.local/share/godot/export_templates/4.7.2.stable/`.
- Android SDK at `/usr/lib/android-sdk` and a JDK 17 or 21. `./tools/android_sdk_setup.sh` installs
  cmdline-tools, the licences, **platform 36 + build-tools 36.1.0** (read from Godot's template, so it follows
  Godot upgrades) and sets `export/android/android_sdk_path` / `java_sdk_path` in Godot's editor settings.
  `build_aab.sh` runs it for you.
- `android/` (Godot's Gradle build template, ~230 MB) is git-ignored. `build_aab.sh` re-creates it from the
  export templates and adds a Maven Central mirror line (`MAVEN_MIRROR=none` turns that off). Gradle needs
  services.gradle.org, dl.google.com / maven.google.com, plugins.gradle.org; bundletool 1.18.3 is
  downloaded once from GitHub into `~/.cache/waxandwane/`.
- `xvfb-run` for screenshots; Python 3 + Pillow + numpy + scipy for the art and store tools; ffmpeg for audio
  (`tools/import_audio.py` caches its sources in `~/.cache/wax_and_wane_audio`).
- Browser automation (agent-browser skill): `npm i -g agent-browser && agent-browser install`.

## Test commands (from `wax-and-wane/`; full list with every flag in `README.md` > Commands)
```
godot --headless --path . --import                        # after adding/changing assets or a new class_name
godot --headless --path . -- --checkscripts               # compile every script
godot --headless --path . -- --checkrooms                 # layouts + dressed rooms (exit 1 on a problem)
godot --headless --path . -- --autotest --audiotest       # sounds, music slots, live mix
stdbuf -o0 godot --headless --path . -- --autotest --playtest --speed=4 --runs=2 --god   # both must reach the end
godot --headless --path . -- --autotest --playtest --speed=4 --runs=4 [--seed=N] [--nospecials]   # balance
godot --headless --path . -- --autotest --playtest --speed=4 --tower [--keeper] [--god] # Clock Tower / Keeper
godot --headless --path . -- --autotest --bench           # CPU per frame, lights, leaks
xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720 \
    -- --autotest --tour --shots=/abs/dir   # + --rooms / --gallery / --bosses / --relictour / --specials /
                                            #   --journal / --tower / --platform for each area
```
Use 1600x720 (a 480x216 phone screen) for tours. Give each bot batch its own profile
(`XDG_DATA_HOME=/tmp/x godot ...`) so runs, unlocks and saves don't leak between tests; `--unlockall`
unlocks every candle, relic and keepsake.

## Balance
Target (fresh profile, no unlocks, the `--playtest --speed=4` bot, 12 runs per setting on fresh seeds; the bot
ignores most telegraphs, so people do better): about half the runs win, most losses come in the Crypt, and only
strong runs beat the Belfry by 1:00 AM and climb to the Clock Tower. Single batches swing by +-15%. The special
rooms carry a lot of the bot's wins, so tune with them in (compare with `--nospecials`). Knobs:
- `world.DRAIN_PER_SEC`: the base melt (a full 120-wax candle lasts 8 minutes unhurt on floor 1), times
  `world.FLOOR_DRAIN` per floor `[1.0, 1.1, 1.3, 1.45, 1.2]`. Wax income per floor: `KINDLE_CAP`, `QUICK_WAX`,
  `WAX_ODDS`; a low wick gets up to `STEADY_ADD` (15) minutes on reaching floors 3-4 (`STEADY_BELOW` 40).
- The tall candle (v2.9, `world.tall_k`): wax above `TALL_KNEE` (0.5 of the night's candle: the wider notch on
  the wax bar and the Clock Tower's line) melts faster, in a straight line up to x(1 + `TALL_HOT[floor]`) at a
  full candle, `TALL_HOT` = `[0.5, 1.5, 2.0, 2.0, 2.0]`; `LEVELS[n]["tall"]` scales it (Gentle 0.5). It taxes a
  rich run and leaves a thin candle alone. Read a run's `[wax]` ledger line before turning any melt or income
  knob (`docs/streams/v29_clock.md`); `--tallhot=0` plays the 2.8 candle.
- `Enemy.TOUCH` = `[5, 6, 7, 7, 7]`: contact damage per floor. The early floors are the strongest knob on
  the win rate. `Enemy.FLOOR_HP` = `[1.0, 1.35, 1.85, 2.4, 3.0]`: creature health per floor (floor 5 = tower).
  Guardian health: `hp` in `Enemy.DEFS`. Marked foes: `world.champ_chance()`. Drops: `world._plain_drop`.
- Relic odds: `RelicFx._weight` (tier weights `[10, 8, 5.5, 3, 1.4]`, per pool). Locked items: `Unlocks.TABLE`.
- Special rooms: `Specials.INFO[t]["chance"]` (Seance 0.4, Mirror 0.45, Music Box 0.4, Study 0.35, Font 0.3),
  `MINI_CHANCE` 0.5, `MINI_HP` 6, `MINI_TOUCH` 9, `SEANCE_TIER` 2, `WAVE_SIZE` / `WAVE_SIZE_CELLAR`,
  `MIRROR_COST` 15, `FONT_ODDS`, `TUNES`, and the champion's relic chance (25%, `Specials._cleared`).
- Clock Tower: opens only after a first normal win, if the Belfry falls by `Tower.UNLOCK_CLOCK` (60 = 1:00 AM,
  as shown on the clock); `Tower.ARRIVAL_WAX` (+5 min), `Enemy.FLOOR_HP[4]`,
  `DEFS["keeper"]["hp"]` (380), `Keeper.HAND_HIT` (9), `Keeper.MIN_PHASE`, `Keeper.MAX_SENTRIES` (3), the
  per-phase cooldowns in `Keeper.tower_keeper` and `chime_t`. Test with `--tower [--keeper --keeperwax=N]`.
- Candles: `Candles.LIST` (`wax`, `drain`, `speed`, `damage`, `hit`, `light`, `dark_hit`...): sidegrades, never
  a hard mode (the Black Taper: Tallow's wax and melt, a short light, x1.5 damage to foes beyond it).
- Difficulty (v2.1): `world.LEVELS`, one level per save slot (1 Gentle, 2 Midnight = every number above,
  3 Witching Hour, 4 Two O'Clock); `world.difficulty()` feeds the melt, foe damage, foe health, marked foes and
  drip wax. Tonight's Candle is always 2. Judge a level on a fresh profile with `--difficulty=N`
  (`docs/streams/v21_slots.md`). 2.1.0 bot wins (8 runs each): 8 / 6 / 3 / 2. Level 4's foe damage x1.4 is a
  cliff for the bot (0 of 20); it ships at x1.35.

## Installed skills (repo-level, `/.claude/skills`; sources pinned in `/skills-lock.json`)
- Game: godot-export, godot-animation, godot-nodes-scenes, godot-ui-control, game-feel, game-audio,
  pixel-art-sprites, roguelike, steam-publish.
- Testing and pages: agent-browser (a real browser), copywriting, seo-audit, frontend-design,
  design-taste-frontend, impeccable, ui-ux-pro-max, web-design-guidelines, build-awwwards-quality-sites,
  core-web-vitals, gsap-core, gsap-performance, gsap-scrolltrigger, threejs-fundamentals, scroll-world.
- Other: memory-management, find-skills. (`/.agents/skills` holds the same set minus game-audio,
  godot-export, pixel-art-sprites and roguelike.)

## Where things stand (handoff, 2026-11-10)
- Latest build: **2.9.0** (versionCode 16): APK, AAB, Windows + Linux zips and the browser build. Two things:
  - **The bigger picture** (`docs/streams/v28_screen.md`, merged from `v28/screen`): Settings > Controls >
    Screen, **Big** (the default) draws the room at its own whole-number scale, wall to wall in height, under a
    HUD at the old scale (`scripts/stage.gd` owns Main; hooks `Stage.attach_world`, `Stage.to_ui`, `--screen=`,
    `--stagekw=`, `--safe=`, `tools/stage_check.py`); **Classic** is the old picture. The room covers 62% of a
    phone screen instead of 35-43%. Never run on a real phone or GPU yet: if it is slow there, Classic is the
    fallback. The browser frame for itch.io is now 1280 x 720.
  - **The clock** (`docs/streams/v29_clock.md`): the bot's new wax ledger showed kills paying back twice what
    the melt took, so the candle stood near full all night. Now a tall candle burns fast (the Balance knobs
    above). At Midnight: **14 of 20 wins, 12:57 AM at the win** (10 of 16 on the houses every version was judged
    on, 4 of 4 on fresh ones; the 2.8 burn: 5 of 6, 12:21 AM); Gentle 7 of 7; Witching Hour 1 of 4, Two O'Clock
    3 of 4; a 7-floor night 2 of 2. Missed: the aim was wins after 1:15 AM. No run
    that reached the Belfry lost (all 20 losses in 64 nights came in the Crypt or the Chapel): if the end of the
    night should bite, look at what the Belfry and its guardian pay and cost, not at the melt.
  - Also: the creature glow shader's engine error is gone (logs are clean apart from exit-time leak notices).
- 2.8.0 (versionCode 15) came from a fresh look at a recorded run and six measured bot runs
  (`docs/streams/v28_pace.md`): Tallow hurries x1.6 in quiet rooms (`Player.HURRY`), the full map hops to a
  cleared room (`world.warp_to`, `FullMap`), the Cellar's small lodgers come as litters of one-ember runts
  (`world.RUNTS` / `FOLLOWERS`, `Enemy.runt`), and a first launch goes straight from Light the wick into the
  first night (`Game.first_night`). 67% of a run is fighting, 12% walking between rooms (2.7.0: 51% / 28%).
  Judges: `--pacecheck` (25 probes), `--tour --pace`. The night baseline was regenerated on purpose then.
- The browser build (`./tools/build_web.sh`) is the **whole game**, not a demo: do not post it as a free page
  unless the owner wants that. A real demo (say the first two floors, behind a `demo` export feature) is not
  built.
- **Publisher pitch kit** (the owner wants to pitch publishers): `docs/marketing/pitch/` (README first): a
  checked publisher list with routes and AI positions, paste-ready form answers, emails, the honest "how it was
  made" statement, a contract checklist, eight 2.8.0 screenshots, and a 12-slide deck (a Slides artifact,
  https://claude.ai/artifact/5EfjaS3ebsXf4U64zk4nHR, private to the owner; its source is not in the repo). The
  pitch always says the art and code were made with an AI assistant; never help hide that. Owner-only blanks:
  name, email, country, price, dates, the ask, a guardian if under 18. The trailer still shows 2.0: re-record it
  only if the owner asks (no-videos rule).
- **Free-art swap (asked 2026-11-10, waiting on the owner's choice):** the owner wants every picture and sound
  my programs made replaced by found, human-made free assets ("don't generate anything"), the diary pages
  removed and the talk scenes kept. Size: about 1,160 PNGs under `assets/art/` (hero parts, 27 creatures, 13
  guardians, 73 item icons, fx, decor, 24 baked room backgrounds, specials, tower, chalk, primer, talk, ui).
  Source found: the public library `series-ai/jam-ready-assets` (where `tools/import_audio.py` already gets the
  music; clone with `GIT_LFS_SKIP_SMUDGE=1`, fetch a PNG from
  `https://media.githubusercontent.com/media/series-ai/jam-ready-assets/main/<path>`; each pack has its own
  `License.txt`, licence table in its README). Usable CC0, human-made: `ninja-adventure` (64 monsters, 20
  bosses, a flame character "Flam", 130 item + 121 skill icons, FX, UI theme, facesets, input prompts),
  `0x72-dungeon-tileset-ii`, Kenney (tiny-dungeon, roguelike-interior, ui-pixel-pack, input-prompts-pixel, the
  audio packs, music-jingles), `ansimuz-gothicvania-*`, `foozle-lucifer-*`, `takogame-halloween-icons`, Pixel
  Frog. **Never use `angais-pixel-art-atlas` / `codepawl-pixel-art-atlas-models`: AI-generated.** Hard parts told
  to the owner with a side-by-side picture (`build/free_art_preview.png`): Tallow is drawn by code as a candle
  that shrinks and makes faces (`player.gd`), no pack has him; no pack has a pendulum, a stockpot, an organist
  either, so guardians would be renamed and their talk lines re-fitted; the diary pages carry three endings
  (`Diary.ENDINGS`); and with my talk lines kept Steam still needs one sentence about the text. Do nothing big
  until the owner answers (go all / go but keep Tallow / stop).
- Not done from the 2.8 plan: **Flag a bug** (a pause-menu button that copies a report code; not built).
- The owner asked for game work only, lean: no pitch, research or reviewer agents unless asked; one thing at a
  time; small bot batches (they cost time, not usage: run them in the background and read only the
  `[playtest] run` and `[wax]` lines).
- **Queue after v2.1 + Long Night batch 1:** `docs/design/ROADMAP_V2.md` (special moves -> Challenge Nights ->
  diary pages -> translations -> Boss Rush; Long Night batch 2 as a side track). Design of the long night:
  `docs/design/LONG_NIGHT.md`.
- 2.7.0 (versionCode 14), APK only, was built from the first REAL playtest (the
  owner's friend: fun, but the tutorial was weak and repetitive, the story should be characters talking, "a few
  bugs", "lacking something"): v2.7 onboarding (an animated learn-by-doing controls lesson on a slot's first run,
  `scripts/ui/primer.gd`, every hint once per slot, How to play replay; `docs/streams/v27_onboarding.md`,
  `--primercheck`), v2.7 dialogue (talking scenes with all 16 guardians on first meeting and fall, an animated
  opening, Tallow's voice, ending beats, Settings > Story scenes; `scripts/ui/talk.gd`, `talk_lines.gd`,
  `opening.gd`; `docs/streams/v27_dialogue.md`, `--talkcheck`) and v2.7 QA (12 found, 6 fixed: a pause during a
  hit freeze crawled at 1/20 speed, reading cards in slow motion, the Swap-sticks banner, stove embers; the minimap
  opens the map only in a quiet room; `docs/streams/v27_qa.md`, `--qacheck`, `--monkey`, `--settings=`). A first
  run: the opening, then the lesson (the old 12:00 AM card only shows when there is no lesson).
- 2.6.0 held v2.6 the GUI overhaul (a candlelit
  wood-and-brass UI kit in `assets/art/ui/` from `tools/art_ui2.py`, built into one Theme by `UI.theme()` and
  installed by `UI.install()` in main.gd: every screen uses it, no screen restyles itself; a new title, the HUD
  clock+wax gauge, results tiles, Reduce motion; `docs/streams/v26_gui.md`, before/after in
  `docs/streams/img/`) and v2.6 feel (pickup magnet, Aim Assist/Auto/Off, snappier rooms, hit direction, the full
  map, Quick restart; `docs/streams/v26_feel.md`). Watch the magnet's buff at the next balance batch.
- 2.5.0 added on top of 2.3.0 the v2.4 boss intro
  animations (every guardian makes a 1.4-2.0 s entrance, any tap skips; `scripts/game/boss_intro.gd`,
  `docs/streams/v24_boss_intros.md`) and v2.5 the story (`docs/design/STORY.md`: Martha Fenn, the housekeeper, made
  Tallow so the house could rest; 24 diary pages, the Diary tab, three new endings, `--diarycheck`, `--ending=<id>`;
  `docs/streams/v25_story.md`). The owner chose to KEEP the AI-drawn art (a swap of the guardians for free
  Ninja Adventure bosses was started and cancelled) and to label it honestly in the store forms.
- 2.3.0 held v2.1 (three save slots with
  difficulty 1-4, a 2.0 save moves into Slot 1; the Black Taper as a sidegrade; four new guardians; bigger self-lit
  enemy shots, Normal / Large), v2.2 (the night-length slider, 4 to 7 floors, with the Kitchen, Library and Attic;
  `docs/streams/v22_night.md`, `v22_areas.md`) and v2.3 (a special move per candle + the ability button + the Keys
  page + the `L` strings autoload; `docs/streams/v23_moves.md`). The AAB, desktop zips, browser zip and store
  screenshots were rebuilt at **2.9.0**; the press kit zip and the trailer still show 2.0.0.
- The owner asked to keep bot balance judging light (credits): quick checks only (checkscripts, checkrooms, one
  god run, the relevant tour), small batches when a number really moved. Long nights after the merge: 7 floors
  2 of 5, 5 floors 2 of 3. Per-candle win rates with the moves were not measured (only Tallow: 3 of 8 with or
  without Flare Up).
- Next in `ROADMAP_V2.md`: step 2 Challenge Nights (now v2.6; steps 3 diary + intros are done), with Long Night batch 2 (Conservatory, Ballroom,
  Gallery; the slider to 10) as the side track. Small follow-ups: the hot stove tops could glow more on a phone;
  with Swap sticks on a 384-wide screen a banner subtitle can run off the right edge (`hud._place_banner`); the
  chalk drawings show default keys after a rebind.
- A four-reviewer studio review (critic, QA, mobile UX, release manager; all findings in
  `docs/streams/fix_*.md`) scored 1.9.3 at 6.5/10; its blockers and majors are fixed in 2.0.0.
- Balance on 2.0.0 (12 fresh-seed bot runs): 7 wins, normal wins finish around 1:08 AM, 2 of 7 wins reach the
  Clock Tower, losses in the Crypt/Chapel; forced `--tower --keeper` runs lose to the Keeper in phase 3.
- Posting: `docs/marketing/POST_IT.md` (store by store), `facts.md` (`tools/make_facts.py`), store art
  (`tools/store_art.py`, judge PASS), trailer + shorts (`./tools/make_trailer.sh all`; `CTA=play|steam` cuts),
  press kit (`./tools/press_kit.sh`), privacy policy `PRIVACY.md`, `LICENSE` (all rights reserved).
- Not done / owner-only: developer name, contact email, prices, store accounts and fees; one real run of the
  Windows zip on the ROG Ally; real-phone performance of Effects Full vs Lite (Kobiton, once connected);
  Steamworks achievements/cloud (no GodotSteam yet; the store copy does not promise them).
- Usage limits stopped parallel agent teams several times: run at most 2-3 agents at once and commit after
  every step.
