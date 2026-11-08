# Stream notes: fix/ui (UI, UX and text fixes from the v1.9.3 review)

Branch `fix/ui`. One commit per finding (the message starts with the IDs and carries the numbers).
Every fix was checked from outside: a probe on the real screens, a measurement, or a tour shot.

## How to judge the UI now
- `--tour ... --fit` (any tour): after every shot `FitCheck.scan()` (`scripts/ui/fit_check.gd`) prints
  `[fit] <shot> OFF '<text>'` for text or buttons leaving the visible screen and
  `[fit] <shot> OVER '<a>' x '<b>'` for text landing on text from another layer or another part of the
  HUD (`set_meta("fit_group", ...)` marks pieces laid out together; things under an open modal, inside
  a scrolling list, or sliding (`fit_skip`) are not judged).
- Probes used for the numbers below live outside the repo (the scratchpad `ui/tools/`): results,
  title, HUD, chalk, intro and the QA flow probe. They drive the real screens.

## What changed (before -> after)

| IDs | Change | Check |
|---|---|---|
| UX-01 QA-01 REL-07 C7 | `results.gd`: the info scrolls inside a panel capped at the screen above the buttons; Light another / Share / Title are pinned 4 px above the bottom edge. Unlock news: 2 rows (two relics share one row when it fits) + "+N more in the Journal"; relics: one row of 16, a longer collection shows 15 and a "+N" button that opens the rest; seed line in DIM (4.6:1, was #775c55 2.3:1). | First win, 20 relics, 7 unlocks, tower hint: panel ran 9 px off the bottom, buttons showed 7 of 24 px -> content 138 px of a 166 px cap, buttons at y 188-212 (384x240: 212-236). FitCheck 0 at 480x216, 384x240, 384x216 for 5 cases (first win, true ending, tower death, 64 relics, daily). |
| QA-07 UX-12 C8 (REL-07) | `achievements.gd`: the toast queue is held (no 3 s cap) during a floor/relic banner, the boss card, a boss fight, the pause menu, the end of the run, the Ending, a screen change and the Results; a toast already up is pulled (and shown again later if it had been up less than 1.2 s). On the title (its bottom edge is now the button row) a rare unlock waits for the next run. 0.4 s between toasts, 3+ at once = one "3 ACHIEVEMENTS" toast, lines wrap at 180 px. Lane: top centre between the wax bar and the minimap when it fits, else under the HUD (y 46 at 384 px). Results list what was pending ("ACHIEVEMENTS: ...") instead of a toast. | Main tour: no toast on the floor banners (26-29), the versus card (30) or the results (36); relic tour: none on PAUSED; tower tour: none on the keeper banner or the ending cards; 384x216 toast clear of the bar and minimap. |
| QA-09 REL-16 | `controls.gd`: `_screen()` returns null while main.goto() swaps screens; modal callbacks capture instance ids. | QA flow probe (Save & quit, Give up): 2 "Lambda capture was freed" + 2 SCRIPT ERRORs -> 0. |
| QA-18 UX-14 REL-16 | `autotest.gd` platform test expects Journal under Resume, waits for the title's opening, checks the quit prompt opened. | `--tour --platform`: `fails=1` -> `fails=0` at all three sizes. |
| QA-04 UX-10 | `hud.preview_item()`: a preview wider than the screen - 16 px splits into "NAME - what it does" / "Costs ... [Rite]" (2 lines max); no bottom copy while the banner names the same item. `pickup.gd` (1 line): "Costs 15 max minutes (7 now)". | All 88 offers, game font: mirror/altar lines wider than 384 px: 32 (old words) / 24 (new) -> 0 lines over 368 px after the split. |
| QA-05 UX-13 C14 | Floor 5 reads "The Clock Tower - above the bells" (results stats), ", above the bells" (death note, Journal run record), "snuffed above the bells" / "done by .., above the bells" (Share). | Tower tour 22/23 and results probe; `--designcheck --share` PASS. |
| QA-11 | `hud._place_banner()`: subtitle wraps to 2 lines between the clock/coins column and the minimap, band sized to the text; at 384 px the banner sits below the wax bar. | Relic tour 384x216: the 290 px "Shots burst into three sparks..." line no longer starts on the bomb icon. |
| QA-12 | `journal.gd` JSlot draws only the part of a portrait inside its cell; tall ones show from the head down. | Journal tour 04: the unseen guardian no longer spills over the Sexton. |
| QA-13 | "Keeper of Rites": "Complete all six Candle Rites." (Items.RITES has 6). | |
| QA-19 | `candles.gd` (text): Pillar "Starts with 15 spare minutes", unlock "Snuff the Chapel's guardian (floor 3)". | world.gd unlocks it on either floor-3 guardian. |
| QA-20 | Pause menu: Journal / Settings are two halves like Save & quit / Give up. | Relic tour 08. |
| QA-21 | `boss_card.gd`: the HUD fades out under the versus card (back for the pause menu and at the end). | FitCheck flag "The Belfry 4/4 x THE HOUR FIEND" on shot 30 -> none. |
| QA-02 | `title.gd`: Light the wick / Tonight's Candle / seed Light ask "YOUR CANDLE IS STILL LIT" [Keep it] / [Light new] when a run is saved; only Light new clears it. | Title probe: Keep it -> snapshot kept. |
| UX-05 | Title buttons 24 px tall (were 20), 4 px gaps (were 2): big actions in the right column, Journal / Seed / Settings / Credits on a row along the bottom edge; candle arrows 24x24; keypad keys 34x24 with 4 px gaps (were 30x18, 2 px). First Tonight's Candle: a one-tap card ("Only your first try counts"). | Title probe: FitCheck 0 at all three sizes (title, with Continue, prompt, card, keypad). |
| QA-22 REL-20 | On desktop (`OS.has_feature("pc")`) the bottom row ends in Quit (the existing "BLOW OUT THE CANDLE?" prompt). | Title probe shots. |
| UX-04 | Boss fights: a first-time tip (`Game.tip`, marked by a 1-line hook: Game meta `tip_frame`) waits until the fight ends; other hints are one outlined line at the top (y 48, 66 at 384 px) without the band. | HUD probe: PASS (tip held, then shown; hint at y 48, band alpha 0). |
| C11 | Banners and hints shown in a special room, treasure room, shop or hollow fade (0.25 s) once Tallow is in another room. | HUD probe: Music Box banner + hint gone 0.4 s after leaving. |
| C10 | `world.fx_text()`: minute rewards landing in the same frame at the same spot merge ("+4 min  CLEAN  QUICK"), and a Kindling chain is one line that counts up ("KINDLING x3 +1", "BLAZE x5 +2", "BLAZE x6 +1" -> "BLAZE x6  +4 min") instead of a stack. | HUD probe: 3 same-frame texts -> 1 label; a 3-kill chain -> 1 label. |
| UX-06 | Chalk at alpha 0.8 (was 0.5) with a 1 px ink under-stroke; touch hint "Left thumb: move  Right thumb: aim + shoot  Bomb: right button". | Chalk on/off frame pairs: median contrast 2.77:1 -> 4.53:1 (lowest 2.74 -> 4.37). |
| UX-07 | The intro's button is "Begin" and ignores presses for 0.8 s (`UI.hold_presses`); Journal > Records starts with "How to play". | Double Return 0.9 s apart on a fresh keyboard profile: intro skipped (FAIL) -> intro stays (PASS). |
| UX-08 (basic) | Swap sticks on touch: hint words swap (`Controls.thumb()`), the chalk's MOVE/AIM and BOMB/KEEPSAKE trade sides, the bomb / keepsake buttons move to the left edge. | Chalk probe `--swap` at 384x216. |

## The judge (final code, `--fit`, profiles in /tmp/ui_profile_N)

| Tour | 1600x720 (480x216) | 1280x800 (384x240) | 1920x1080 (384x216) |
|---|---|---|---|
| `--tour` (36 shots) | 0 SCRIPT ERROR, 0 fit flags | 0, 0 | 0, 0 |
| `--tour --journal` (27) | 0, 0 | 0, 0 (5 before the How to play card was shortened) | 0, 0 (6 before) |
| `--tour --platform` (11) | 0, 0, `fails=0` | 0, 0, `fails=0` | 0, 0, `fails=0` |
| `--tour --specials` (31) | 0, 0 | 0, 0 | 0, 0 |

The first-win results screen of the main tour (seed 7, fresh profile: 2 relics, 7 unlocks, 5
achievements, the tower hint) fits at all three sizes with the button row on screen.

Release checks on the final code: `--checkscripts` 0 failed; `--checkrooms` 0 problems (69 layouts,
1110 dressed rooms); `--playtest --speed=4 --runs=2 --god`: 2 of 2 reach the end (true ending, floor 5,
12:27 / 12:39 AM); a normal `--playtest --speed=4 --runs=2`: both lost in the Crypt, 0 SCRIPT ERRORs
(no balance numbers were changed in this stream).

## Hooks outside this stream's files (for the merge)
- `scripts/game/world.gd`: `_intro()` button text + one `UI.hold_presses(...)` line (UX-07); a
  self-contained `_merged_text()` block in front of `fx_text()` (C10).
- `scripts/game/pickup.gd`: the cost wording line (QA-04).
- `scripts/autoload/game.gd` `tip()`: `set_meta("tip_frame", ...)` (UX-04).
- `scripts/game/meta_tour.gd`: the Records entries it shows moved down one (How to play is first).
- `scripts/game/candles.gd`: the Pillar's `line` and `unlock_text` (QA-19, text only).

## Known issues / not done
- UX-08: the gamepad has no stick swap; the Settings toggle still shows on every device.
  `relic_fx.gd` still says "Hold the right thumb" for the Stove Door / Blowlamp tip.
- UX-10: no "Large text" option (out of scope here).
- Toasts that unlock while the Results screen is up (rare) wait and are dropped on the title.
