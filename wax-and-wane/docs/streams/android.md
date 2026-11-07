# Google Play app bundle (stream `android`)

A Play-ready `.aab` (target SDK 36 / Android 16, arm64, signed with the existing release key) from one
command, with bundletool checks. Branch `revamp/android`. The sideload APK (`tools/build_apk.sh`,
preset "Android") is unchanged and still builds.

## The command (re-run it on the final build)
```
./tools/build_aab.sh                          # -> build/WaxAndWane_v<version>.aab, ends with PLAY-READY
./tools/build_aab.sh --verify build/X.aab     # checks only
```
It needs the private key like `build_apk.sh`. It looks in `$KS_DIR`, `../../FailedIdolsOfTheAbyss/keystore`,
`~/FailedIdolsOfTheAbyss/keystore` and `/home/user/FailedIdolsOfTheAbyss/keystore`, or takes
`KEYSTORE` / `KEYSTORE_USER` / `KEYSTORE_PASS`. Nothing secret is written into the repo or the logs.
About 2 to 3 minutes when everything is cached.

Steps it runs:
1. `tools/android_sdk_setup.sh`: cmdline-tools if missing (dl.google.com), licences, and the platform +
   build-tools that Godot's template asks for. It reads them from `android_source.zip`'s `config.gradle`,
   so a Godot upgrade picks the right ones. Godot 4.7.2 wants `platforms;android-36` and
   `build-tools;36.1.0`. It also sets `export/android/android_sdk_path` / `java_sdk_path` in Godot's
   editor settings if they are missing.
2. Build template: unzips `android_source.zip` into `android/build` and writes `android/.build_version`
   and `android/build/.gdignore`, the same as Godot's "Install Android Build Template". This only
   happens when the Godot version changes or the folder is missing.
3. Copies `version/code` and `version/name` from the "Android" preset into "Android Play", so the
   release checklist stays the same: bump the "Android" preset, and the script follows it. If it
   changed anything it says so; commit `export_presets.cfg` then.
4. `godot --export-release "Android Play"`. A Gradle failure caused by the network
   (429, 5xx, timeouts) is retried up to 4 times with 30/60/120 s backoff. The Gradle log is
   `build/build_aab.log`.
5. Checks with bundletool 1.18.3 (downloaded once from the GitHub release, sha256-pinned, cached in
   `~/.cache/waxandwane/`). It runs `validate` and dumps the manifest: package, versionCode, minSdk 24,
   targetSdk 36, not debuggable, permissions (only VIBRATE allowed). It builds a universal APK signed
   with the release key, then runs `aapt2 badging` (the label is "Wax & Wane" in every language), the
   16 KB checks (ELF LOAD alignment of every `.so` in the bundle, `zipalign -c -P 16` on the universal
   APK), and confirms the bundle and the APK are signed by the release key's certificate. Reports go
   to `build/aab_check/`.

## Decisions
- **`android/` is git-ignored.** The template is about 230 MB (two prebuilt Godot AARs) and is
  re-created exactly from the export templates. We don't change any template file except the mirror
  line below, which the script re-applies.
- **Maven Central mirror.** `repo.maven.apache.org` answered HTTP 429 to Gradle here (6 artifacts on
  the first try: bcpkix, jaxb-runtime, jopt-simple, grpc-protobuf, grpc-netty...; the plugin portal
  redirects there too). The script adds
  `maven { url "https://maven-central.storage-download.googleapis.com/maven2/" }` (Google's mirror of
  Maven Central) before `mavenCentral()` in the template's `settings.gradle` / `build.gradle`. With it
  the first build succeeded with no retries. `MAVEN_MIRROR=none` turns it off. Other hosts Gradle uses:
  services.gradle.org (wrapper), dl.google.com / maven.google.com (Android), plugins.gradle.org. All
  of them were reachable.
- **Preset "Android Play"** (`preset.3`): Gradle build, AAB, min SDK 24, target SDK 36, arm64-v8a only.
  Play only requires 64-bit code; 32-bit armeabi-v7a is optional and left out to keep it small.
  Same package `com.tallow.waxandwane`, same icons, same version, release-signed through the
  `GODOT_ANDROID_KEYSTORE_RELEASE_*` variables. Only permission: VIBRATE (a normal permission, needed by
  `Input.vibrate_handheld` in `game.gd`). Custom feature tag `play`, so `OS.has_feature("play")` can
  later switch on Play Billing. `compress_native_libraries=true`, the same as the sideload APK
  (`extractNativeLibs=true`) and what Godot's template does by default for min SDK 24. The libraries
  are still 16 KB aligned, so Play's 16 KB check passes.
- **Signing.** The bundle is signed with the existing key (alias `failedidols`, RSA 2048, valid to 2054).
  `docs/marketing/google_play.md` section 6 tells the owner to give Play that same key as the app
  signing key (PEPK upload). That makes it the upload key too, and Play and itch.io builds can update
  each other.

## What the v1.9.0 bundle looks like
`build/WaxAndWane_v1.9.0.aab`, 35 MB. Modules: `base` (code, `lib/arm64-v8a`) +
`assetPackInstallTime` (the game data). The universal APK has the same 2,425 asset files as the
sideload APK. Manifest: `isGame=true`, `appCategory=game`, `allowBackup=false`, `userLandscape`
orientation, not debuggable. Android 16's large-screen orientation and resize rules skip games, so
landscape stays locked on tablets.

## Merge notes
- `export_presets.cfg`: the new preset is appended as `[preset.3]`. If another stream also added a
  `preset.3`, renumber one of them. Godot stops reading at the first missing number.
- `.gitignore`: one line, `android/`.
- The integrator's release steps gain one line: after `build_apk.sh`, run `./tools/build_aab.sh` and keep
  `build/WaxAndWane_vX.Y.Z.aab` for Play. Version bumps stay in the same three places.
- CLAUDE.md "Toolchain" can now say: Android platform 36 + build-tools 36.1.0
  (`tools/android_sdk_setup.sh` installs them).

## Known issues / not done
- No emulator or phone in the container, so the bundle hasn't been installed or launched. Its
  universal APK has the same contents, manifest, permissions and native libs as the sideload APK,
  which does run on the owner's phone. The first real test is the Play closed test (or
  `bundletool install-apks` with a phone over USB).
- The NDK (29.0.14206865 in the template's config) isn't installed and isn't needed. Godot's prebuilt
  libraries are already stripped (no `.symtab` / `.debug_*` sections; the same bytes as in the
  sideload APK). Play may show a "native debug symbols" warning; ignore it.
- Play Billing (the free-to-try unlock in `google_play.md` section 2) isn't in this build. When it's
  added, the plugin brings `com.android.vending.BILLING`. Add that to the allowed permissions in
  `verify_aab()`.
