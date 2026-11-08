# Fix stream: release kit (branch `fix/release`)

The release-readiness and store findings from the 1.9.3 review: honest store pages, a fact sheet made from the
code, privacy and licences inside the game, brighter capsules, the right trailer endings, Play's 16:9 touch
screenshots, desktop and Android settings, and a phone-friendly posting guide. Gameplay, UI layout and sprites
are unchanged (the only UI change is two buttons in the Credits modal).

## What changed, before -> after

| ID | Before (1.9.3) | After |
|---|---|---|
| REL-01, C3 | Store texts promised a free demo and "free to try", said 9.5-minute candle, 8 bosses, 4 more candles, 4 Rites, 32+ monsters; 45 [CHECK]/[NEED] markers | `docs/marketing/facts.md`, written by `tools/make_facts.py` from the code (8-minute candle, 35 lodgers 20/15, 9 guardians 4/5, 6 champions, 64 relics, 6 Rites, 8 keepsakes, 6 candles, 5 special rooms, 4 omens, 52 achievements, the 1:00 AM Clock Tower rule, Kindling and Spilled Wax numbers, Android permissions). Every store file rewritten to match; no demo, Play is paid; 0 markers left; one OWNER ONLY block per file (name, email, prices). `--check` fails if facts.md is stale |
| C3 | Credits: "drawn pixel by pixel", music "made for this game", no person credited | Title > Credits and the ending roll: "one developer, with Claude (AI)"; made for this game = Tallow, 15 lodgers, 5 guardians, relics, rooms, effects, jingles; 0x72 = tiles, 20 lodgers, 4 guardians (counted at run time from `Enemy.DEFS`); music = Ninja Adventure by Pixel-boy and AAA (CC0) |
| REL-02 | Disclosure said AI "synthesizes the music", no trailer voice; "no blood" | One disclosure for Steam and itch: code and text with Claude, pixel art drawn by AI-written scripts and checked by the developer, SFX/jingles by AI-written scripts from CC0 packs, music not AI, trailer narration Kokoro TTS, nothing generated while playing. Content answers: cartoon blood (red splats stay on the floor), Music Box = coins for a random reward, no real money |
| REL-03 | No privacy policy anywhere | `PRIVACY.md` (no data, offline, no ads/analytics/accounts, saves on the device with the PC folders, Android backup and Steam Cloud copies, Share = clipboard) + Title > Credits > **Privacy** page with an Open link button. URL pattern: `https://github.com/gamertristian20122-ctrl/Claud-/blob/ccr-37a74654-pp10xa/wax-and-wane/PRIVACY.md` |
| REL-15 | "Godot Engine (MIT)" only; "Free for any use. Licences are in assets/licenses"; Kokoro licence inside every build | Title > Credits > **Licences** page: the game's copyright, the CC0 packs, `Engine.get_license_text()` and Godot's 102 third-party components with 19 licence texts (`get_copyright_info()` / `get_license_info()`); `assets/licenses/Godot_third_party_notices.txt` (written by the engine) ships in the game and the PC zips; Kokoro licence moved to `docs/marketing/voice/` |
| REL-14 | No licence file | `LICENSE`: all rights reserved, source shown for reference, third-party assets keep their licences; POST_IT step 1 asks the owner to decide public vs private |
| REL-06 | Play: free + $3.99 unlock with no billing code | Play: paid app, $2.99, no IAP or ads, decided before the first upload; why, and the catch that closed-test testers must buy a paid app (Google's testing page) with three ways to keep it cheap |
| REL-08, C4 | Capsules near-black: main mean luma 34.8 with 68% of pixels < 30, header 30.4/72%, small 46.1/70%, itch 31.5/72%, Play 31.1/74%; Tallow about 66 px wide in the main capsule | New "hero" layouts (`--keylayout=hero|hero_tall`): Tallow fights the Wax Mother (a guardian made for this game, lit by her own candles), Cellar warmth, mid-tones lifted. Tallow is 3x bigger in the main and header capsules (art scale 4 -> 12, 3 -> 9), 2.3-2.75x in the others. Judge (all PASS, table in `store_assets/README.md`): main 108.6 / 9.4%, header 114.7 / 6.7%, small 86.9 / 14.6%, vertical 118.2 / 6.2%, library capsule 118.5 / 4.4%, library hero 80.0 / 19.3%, Play 98.2 / 9.8%, itch 109.7 / 6.4%. The warm pool (luma >= 110, R-B about 114) covers 37-52% of each capsule |
| REL-09 | Every trailer ends on WISHLIST ON STEAM (no Steam page exists) | `CTA` setting in `tools/trailer_edit.py`: `itch` (default, OUT NOW ON ITCH.IO), `play` (GET IT ON GOOGLE PLAY), `steam` (WISHLIST ON STEAM), `none`; other CTAs get `_play` / `_steam` file names. Checked end to end: recorded title, cellar and hook once, then cut Short A twice from the same footage (`edit --only short_a`, plain and `CTA=steam`): both 16.85 s at -14.0 LUFS, last frames OUT NOW ON ITCH.IO and WISHLIST ON STEAM |
| REL-10 | Play phone shots 2160x1080 (2:1) only; the 16:9 set had the keyboard HUD ("Q") | `google_play/phone16x9_01..06_*_1920x1080.png`: 16:9, touch HUD (no "Q"), clock-and-candle first. The store renders now start from a seasoned save, which also removed the "BELL CLIMBER" achievement toast from screenshots 05 (versus card) and 06 (low wax) |
| REL-12 | Windows exe: CompanyName and LegalCopyright empty, export_angle=0 | `company_name` "Wax & Wane", copyright line, `export_angle=1`. Measured on a fresh export: pefile shows both strings; the 4.7.2 template links ANGLE statically (59 libANGLE paths in the exe), so no DLLs are needed and `fallback_to_angle` (default on) covers broken OpenGL |
| UX-11 | `user_data_backup/allow=false` in both Android presets | `true` in both; `aapt2` on a fresh debug export: `android:allowBackup=true` (1.9.3 APK: false) |
| REL-17 | Desktop saves in `%APPDATA%/Godot/app_userdata/Wax & Wane` | `use_custom_user_dir` + `custom_user_dir_name="WaxAndWane"`: `%APPDATA%\WaxAndWane`, `~/.local/share/WaxAndWane` (a run wrote save.cfg + run.cfg there). Android unchanged: the template's `GodotIO.getDataDir()` takes no argument and returns `Context.getFilesDir()` (dexdump) |
| REL-11 | Steam page ticked achievements and cloud | Achievements unticked and described as in-game until GodotSteam lands; Steam Cloud only after Auto-Cloud (rows for the new `WaxAndWane` folder); Full Controller Support only after a pad run on the ROG Ally |
| REL-18 | No press kit zip; file names didn't match | `tools/press_kit.sh` -> `build/WaxAndWane_presskit_<ver>.zip` (logos, icon, key art, all screenshots incl. the touch set, the loop GIF, Tallow sheets, press_kit.md, facts.md, LICENSE). Run: 1.1 MB, 30 files |
| REL-13 | No way from the build machine to the stores | `POST_IT.md`: itch.io web upload, Play Console web upload, SteamPipe GUI on the ROG Ally or steamcmd with a build account; `tools/upload_itch.sh` (butler, three channels, `--dry-run`) |

`docs/marketing/POST_IT.md` is the owner's numbered, store-by-store guide (itch.io today; Google Play closed test
-> production; Steam Coming Soon -> release) with every file, text block, form answer and cost.

## Checks run (all in this worktree, private save profiles)
- `--checkscripts`: 54 scripts ok.
- `--playtest --speed=4 --runs=2 --god`: see the result line in the final report of this stream.
- `--tour --journal` at 1600x720 with the two new pages opened (temporary tour lines, not committed): the Credits
  modal, Licences (top, Godot part, end) and Privacy all fit a 480x216 screen.
- `--tour --tower` at 1600x720: the ending credits roll shows the new lines (made for this game, 0x72, music).
- `python3 tools/store_art.py --review DIR`: judge PASS on all nine capsules; `overview.png` looked at.
- Windows and Android exports to a scratch folder for pefile, strings, aapt2 and dexdump (not kept).

## Files touched
Mine: `docs/marketing/**`, `PRIVACY.md`, `LICENSE`, README credits, `assets/licenses/`, `scripts/store_shots.gd`,
`tools/store_art.py`, `tools/trailer_edit.py` (end card + output names), `tools/press_kit.sh`,
`tools/upload_itch.sh`, `tools/make_facts.py` (new), `scripts/ui/credits_pages.gd` (new, called from
`title.gd _credits`), `export_presets.cfg` (backup, Windows company/copyright/ANGLE only), `project.godot` (custom
user dir only), `title.gd _credits`, `ending.gd _credits`.
One-line hooks outside them: `tools/build_desktop.sh` (the README.txt save-folder line) and
`docs/streams/platform.md` (the save path).

## How to re-check after the merge
```
python3 tools/make_facts.py --check      # facts.md still matches the code (re-run without --check if not)
python3 tools/store_art.py --review /abs/dir   # every image + the judge (must end with "judge PASS")
./tools/press_kit.sh                      # the press kit zip
CTA=play ./tools/make_trailer.sh edit --only trailer   # the Play cut (needs build/trailer_raw)
```
If another stream changed numbers (balance, a redrawn guardian, more relics), re-run `make_facts.py` and grep the
store texts for the old number. The credits count lodgers and guardians at run time, so they follow by themselves.

## Known issues
- The run length in the store copy ("about 5 to 20 minutes") and the Kindling / Spilled Wax numbers in the devlog
  come from the code and bot runs of 1.9.3; a balance change in another stream needs a re-read of `facts.md`.
- The press kit has one loop GIF (`loop_fight.gif`); a candle-clock and a versus-card loop would need new cuts in
  `trailer_edit.py`, which this stream may only change at the end card.
- Steam achievements need GodotSteam, 52 achievements in Steamworks and their icons: not in 2.0.0.
- The Windows build still has to be run once on real Windows (the ROG Ally) before the system requirements go live.
- The Data safety answer "no data collected" relies on Google treating Android's own Auto Backup as not collected
  by the app (the policy says so in plain words); Google's help page doesn't mention Auto Backup either way.
