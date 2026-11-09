# Wax & Wane — notes for Claude

Landscape roguelite for Android, Windows, Linux and the Steam Deck (Godot 4.7.2, GL Compatibility, 384x216
base viewport, integer pixel scaling). Read `README.md` (content, layout, commands, credits) and `DESIGN.md`
(asset contract, palette, geometry) first. How each 2.0 system works and its hooks: `docs/streams/*.md`.

## About the owner
- Limited coding experience: explain in plain, phone-friendly language with short numbered steps.
- Plays on an Android phone. **Send the APK as soon as a build is done.** Keep zips under 30 MB.
- Keep the work moving; give a short plan, then do it.
- **No more videos** (trailer, shorts, loops) unless the owner asks again: the 2.0.0 cuts in `build/videos/` are final.

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

## Where things stand (handoff, 2026-11-09)
- **Queue after v2.1 + Long Night batch 1:** `docs/design/ROADMAP_V2.md` (special moves -> Challenge Nights ->
  diary pages -> translations -> Boss Rush; Long Night batch 2 as a side track). Design of the long night:
  `docs/design/LONG_NIGHT.md`.
- Latest build: **2.7.0** (versionCode 14), APK only, sent to the owner, built from the first REAL playtest (the
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
  page + the `L` strings autoload; `docs/streams/v23_moves.md`). The store files (AAB, desktop zips, press kit)
  are still **2.0.0**: rebuild them all for the next store release.
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
