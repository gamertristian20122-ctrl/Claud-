# Wax & Wane — notes for Claude

Android landscape roguelite (Godot 4.7.2, GL Compatibility, 384x216 base viewport, integer pixel scaling).
Read `README.md` (content, layout, commands) and `DESIGN.md` (asset contract, palette, geometry) first.

## About the owner
- Limited coding experience: explain in plain, phone-friendly language with short numbered steps.
- Plays on an Android phone. **Send the APK as soon as a build is done.** Keep zips under 30 MB.
- Keep the work moving; give a short plan, then do it.

## Hard rules
- Original game: never copy names, characters, art or music from existing games. Genre conventions are fine.
- One consistent pixel-art style built on the 0x72 DungeonTileset II palette. No mismatched free art, no blurry
  scaling, no gradients on sprites. Anything that "looks like AI" is a bug.
- Only CC0 / MIT / OFL assets; record each in `README.md` Credits, `assets/licenses/` and the in-game Credits.
- This repo is **public**: never commit a keystore or password. `tools/build_apk.sh` signs with the private key
  from the `FailedIdolsOfTheAbyss` repo (`../../FailedIdolsOfTheAbyss/keystore/`).
- Wax = health = clock (12:00 AM full, 2:00 AM empty). Keep that readable in every change.

## Releasing a build
1. Bump the version in `export_presets.cfg` (`version/code` +1, `version/name`), `scripts/autoload/game.gd`
   (`VERSION`) and `project.godot` (`config/version`).
2. `--checkscripts`, a few `--playtest` runs, a `--tour` and look at the screenshots.
3. `./tools/build_apk.sh`, copy to `build/WaxAndWane_vX.Y.Z.apk`, send it to the owner. Commit and push.

## Toolchain (fresh container)
Godot 4.7.2 + export templates, Android SDK at `/usr/lib/android-sdk` (build-tools 34, platform 34),
a JDK (17 or 21) — set `export/android/android_sdk_path` and `java_sdk_path` in Godot's editor settings.
`xvfb-run` for screenshots, Python 3 + Pillow + numpy + scipy for the asset tools, ffmpeg for audio.
