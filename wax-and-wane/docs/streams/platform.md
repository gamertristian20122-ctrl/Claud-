# Platform & Steam readiness (stream `platform`)

Keyboard, mouse and gamepad play; menus you can drive without touching the screen; Save & Continue;
achievements (local now, Steam later); Windows and Linux builds. Everything below is in the
`revamp/platform` branch.

## Controls (`scripts/autoload/controls.gd`, autoload `Controls`)

| Action | Keyboard | Mouse | Gamepad |
|---|---|---|---|
| move | WASD | | left stick, d-pad |
| shoot | arrow keys | hold left button: fire at the cursor (Settings > Controls > Mouse aim) | right stick, or Y / A / X / B for up / down / left / right |
| bomb | E, Space | right button | RB, RT |
| keepsake | Q | middle button | LB |
| special (v2.3, the candle's move) | Left Shift, F | thumb buttons (XBUTTON1 / 2) | LT |
| pause | Esc, P | the II button | Start, Back |
| menus | arrows / WASD, Enter / Space, Esc back, Q / E switch pages | click | d-pad / left stick, A, B back, LB / RB switch pages |
| fullscreen | F11, Alt+Enter | | |

- Actions live in the InputMap (`move_*`, `shoot_*`, `bomb`, `keepsake`, `special`, `pause`, `ui_page_prev/next`,
  plus extra events on the built-in `ui_*`). v2.3: `special`, `bomb` and `keepsake` can be rebound (Settings >
  Keys; `Controls.rebind(action, event)`, `reset_binds()`, `bound_glyph(action, pad)`, saved in
  `Game.settings["binds"]`; a key another action uses is refused). Movement uses physical keys, so AZERTY works.
- Deadzones: move 0.22 (circular), aim 0.35 (the right stick fires in its direction once pushed past it).
- **Input flow:** `Hud._physics_process` (runs before the world, `process_physics_priority = -10`) sets
  `hud.move_vec` / `hud.aim_vec`: touch sticks first, then `Controls.move_vector()` / `aim_vector()`,
  then the mouse. The world reads them as before; the autotest bot still overrides them in
  `world._physics_process`. Bomb / keepsake are `Input.is_action_just_pressed` in the HUD, so a key
  that resumes the pause menu never drops a bomb. The old hard-coded keyboard block in
  `world._physics_process` is gone (it is all in the InputMap now).
- **Last device:** `Controls.device` is `touch` / `keyboard` / `mouse` / `gamepad`, signal
  `device_changed`. Touch sticks and the bomb button only show while touch is in use
  (Settings > Controls > Touch: AUTO / ON / OFF). The keepsake button stays (it is also the charge
  display) and shows its key underneath ("Q", "LB"). The mouse cursor hides while a gamepad is used.
  A gamepad that disconnects mid-run pauses the game.
- **Cursors:** pixel arrow + crosshair (`assets/art/ui/cursor_*.png`, `tools/art_platform.py`), scaled
  to the game's integer pixel scale. The crosshair shows during play when mouse aim is on.
- On desktop the mouse no longer emulates touch (`--touchmouse` turns it back on for testing touch UI).
- Device-aware text: `Controls.controls_hint()`, `intro_line()`, `keepsake_hint()`, `glyph(action)`.
- Tours/tests: `--device=touch|keyboard|mouse|gamepad`. The main `--tour` forces touch so its shots
  keep showing the phone HUD.

## Menus with keyboard / gamepad

- `UI.button` buttons take focus; the focus frame is `assets/art/ui/focus_9.png` (gold notched ring
  1 px outside the button, cream corners) and the label turns gold. Icon slots use
  `UI.focusable_slot(tb)` (`focus_slot.png`), e.g. the relics in the pause menu, which now show
  their text as you move over them.
- Focus only shows for keys / gamepad (`gui/common/show_focus_state_on_pointer_event` stays at its
  default, and Controls grabs focus with `hide_focus` for touch / mouse players).
- Every `UI.modal` registers itself (`Controls.on_modal_opened`, one line in `ui.gd`): focus jumps to
  the modal's default button (`set_meta("default_focus", true)`) or its first Button, is kept inside
  the top modal, and returns to the button that opened it when it closes. Title and results get
  focus automatically too (Controls finds `main.current` / its `root`).
- `ui_move` sound on keyboard / gamepad navigation (`Audio.play("ui_move")`, silent if missing:
  **audio stream: please add `sfx/ui_move.ogg`**, a soft tick; optional `sfx/achievement.ogg`).
- `ui_cancel` (Esc / B) goes back on every screen. On the title it closes a modal, else asks
  "BLOW OUT THE CANDLE?" on desktop (phones still close at once). LB / RB page through the
  Candle Box on the title, the settings pages and the achievements list
  (`Controls.set_page_handler(root, callable)`).
- The pause menu: Resume, Settings, then **Save & quit** | Give up.

## Settings (`settings_panel.gd`)

Two pages so it fits 384x216: **Game** (Music, Sound, Screen shake, Vibration, Effects, FPS
counter, Fullscreen on desktop) and **Controls** (Touch AUTO/ON/OFF, Swap sticks, Aim assist, Mouse
aim on desktop, a key list). Achievements button + Back at the bottom. New `Game.settings`:
`fullscreen` (false), `mouse_aim` (true), `touch_controls` ("auto"). Vibration also rumbles gamepads.
Window: 1536x864 by default, resizable, minimum 768x432; a window that would not fit the screen
(Steam Deck desktop mode) opens at the largest whole multiple of 384x216 that does.

## Save & Continue (`scripts/game/run_save.gd`, autoload `RunSave`)

- At the start of each floor the run is snapshotted to `user://run.cfg` (atomic tmp + rename):
  seed, floor, candle, daily flag, the omens so far (a rebuilt floor must roll the same omen), the
  relic pool, **every plain Player script variable** (final values: damage, fire_delay, shots, wax,
  wax_max, charred, coins, bombs, relics, rites, keepsake, charge, gutter_used, colours...), and the
  run counters (`WORLD_KEYS`: kills, rooms, run_time, best streak, hits, pact, altar, bomb radius,
  bells rung / paid, candles unlocked this run).
- Continue rebuilds that floor from the seed (same layout, same loot rolls) and restores the stats:
  relics are re-applied on a clean slate (so visuals like the blue flame, moths and any costume
  overlays come back), then every stored value is written back on top, so the numbers are exact.
  `--tour --platform` checks the round trip field by field (0 mismatches).
- Written at floor start, re-flushed on window close, app pause / focus loss and the Android back
  button. Deleted the moment the world is `finished` (death, win, give up).
- On desktop the window's X now saves and quits (it used to only pause).
- Title: "Continue / Floor 3 - 12:41 AM" (the in-game clock at the start of that floor) on top of
  the menu, focused by default.
- **Hooks in other files (one line each):** `world._ready`: `_start_floor(RunSave.begin(self))`;
  last line of `world._start_floor`: `RunSave.on_floor_start(self)`; `title.gd`:
  `RunSave.add_continue_button(menu, main)`.
- **For other streams:** a new Player stat is saved automatically (any plain `var` that does not
  start with `_`; moment-to-moment state goes in `SKIP_PLAYER`). A new world variable a run must keep
  goes in `RunSave.WORLD_KEYS`, or give the world `save_extra() -> Dictionary` and
  `load_extra(d)`. Relic effects that spawn nodes should be safe to apply again on a fresh player.

## Achievements (`scripts/autoload/achievements.gd`, autoload `Achievements`)

`Achievements.unlock(id)`, `is_unlocked(id)`, `count()`, `show_toast(id)` (no unlock; tours),
`open_list(parent)` (paged list, from Settings), signal `unlocked(id)`. Stored in
`Game.records["achievements"]` (id -> unix time) and `Game.records["rites_done"]`. The toast is a
small pixel panel at the top centre for 2 s (waits for a floor / relic banner to clear first), on its
own CanvasLayer, never blocks input. Most triggers are read from the running world every frame
(`_watch`), so no hooks were needed in other streams' files; new mechanics can call `unlock()`.

**Steam:** if a GodotSteam singleton exists (`Engine.has_singleton("Steam")`), it calls
`steamInitEx()`, then `setAchievement(id)` + `storeStats()` on every unlock, re-sends every locally
earned achievement at start, and runs `run_callbacks()` each frame. Create the achievements in
Steamworks with **exactly these API names**:

| API name (id) | Name | Description | Hidden |
|---|---|---|---|
| first_snuff | First Snuff | Snuff out your first creature. | |
| night_shift | Night Shift | Snuff 100 creatures. | |
| chimney_sweep | Chimney Sweep | Snuff 1,000 creatures. | |
| floor_crypt | Down the Stairs | Burn your way down to the Crypt. | |
| floor_chapel | Holy Smoke | Reach the Chapel. | |
| floor_belfry | Bell Climber | Climb into the Belfry. | |
| boss_cellar | Cellar Cleared | Snuff the guardian of the Cellar. | |
| boss_crypt | Crypt Sealed | Snuff the guardian of the Crypt. | |
| boss_chapel | Last Rites | Snuff the guardian of the Chapel. | |
| boss_untouched | Not a Scratch | Snuff a guardian without a scratch. | |
| win | Before Two | Snuff the Hour Fiend before two. | |
| win_early | Early to Bed | Win before 1:00 AM. | |
| win_tea_light | Small Mercies | Win as the Tea Light. | |
| win_party | Party's Over | Win as the Party Candle. | |
| win_pillar | Pillar of Wax | Win as the Altar Pillar. | |
| win_black_taper | Darkest Hour | Win as the Black Taper. | |
| win_plain | Plain Wax | Win with four relics or fewer. | yes |
| tonight | Same Time Tomorrow | Light Tonight's Candle. | |
| tonight_win | Tonight's the Night | Win Tonight's Candle. | |
| kindling_8 | Inferno | Reach a x8 Kindling streak. | |
| kindling_12 | Wildfire | Reach a x12 Kindling streak. | yes |
| mantel | Cluttered Mantel | Carry 12 relics in one run. | |
| hollow | Someone Hid This | Bomb your way into a Hollow. | |
| smoke_pact | Smoke Pact | Pay minutes at the Smoke Altar. | |
| customer | Regular Customer | Buy from the Tallow Merchant. | |
| ks_hand_bell | Hush | Ring the Hand Bell. | |
| ks_flare_match | Strike a Light | Light the Flare Match. | |
| ks_winding_key | Wind It Back | Turn the Winding Key. | |
| ks_smoke_jar | Up in Smoke | Open the Smoke Jar. | |
| rite | Candle Rite | Complete a Candle Rite. | |
| rite_all | Keeper of Rites | Complete all six Candle Rites. | |
| guttering | Clinging On | Live through a Guttering. | |
| two_oclock | Two O'Clock | Melt all the way down to 2:00 AM. | yes |
| candle_box | Full Candle Box | Unlock every candle. | |
| win_level3 | Spellbound | Win a night on level 3 (Witching Hour) or higher. | |
| win_level4 | Dead of Night | Win a night on level 4 (Two O'Clock). | |
| move_skip | Close Shave | Skip right through an enemy shot. | |
| move_sparkler | Party Popper | Pop 3 enemy shots with one Sparkler. | |
| move_slam | Pillar Drop | Stun 3 lodgers with one Slam. | |
| move_blink | Moon Hop | Blink over 3 pits in one room. | |
| move_flare | Burning Bright | Snuff 3 creatures during one Flare Up. | |
| move_snuff | Through and Through | Run one black flame through 3 foes. | |

Bosses are matched by floor, not by boss kind, so a new boss line-up (bestiary stream) keeps working.
The medal icons (`icon_medal.png` / `icon_medal_off.png`) are 9x9; Steam needs 64x64 JPG/PNG icons per
achievement (to do in R3 with the store kit).

## Desktop builds

- `export_presets.cfg`: new **Windows Desktop** and **Linux** presets (x86_64, embedded pck, no code
  signing, the Android preset untouched). Windows uses `assets/art/ui/app_icon.ico` (16, 32, 48, 64,
  96, 128, 192, 256 px, all pixel-exact; made by `tools/art_platform.py`) for the exe and
  `config/windows_native_icon` for the window. File/product version default to the project version.
- `./tools/build_desktop.sh` -> `build/WaxAndWane_<ver>_windows.zip` and `_linux.zip` (exe + licences +
  a short README), then boots the Linux build headless with the bot (`--quit-after`) and fails on any
  script error. `SKIP_SMOKE=1` skips the boot test.
- Saves (2.1: `save.cfg` = settings + the slot played last, `slot1.cfg`-`slot3.cfg` = each save slot's level,
  records and achievements, `run1.cfg`-`run3.cfg` = their saved runs; 2.0 had `save.cfg` + `run.cfg`) live in
  `%APPDATA%\WaxAndWane\` on Windows and `~/.local/share/WaxAndWane/` (2.0.0: `use_custom_user_dir`)
  on Linux / Steam Deck: use them all for Steam Auto-Cloud (`*.cfg` in that folder).
- Steam (R3): one depot per OS from those zips' contents; launch options `WaxAndWane.exe` (Windows) and
  `WaxAndWane.x86_64` (Linux). Templates for `steamcmd` are in `tools/steam/` (fill in the App and
  Depot IDs). The Steam Deck checklist items we already meet: full controller play with no setting
  changes, controller glyphs while using a pad (LB / RB / START), 1280x800 supported, smallest text
  8 px x3 = 24 px tall at 1280x800 (minimum is 9 px).

## Screens checked

`--tour --platform` at 1600x720 (phone-shaped 480x216), 1280x800 (Steam Deck) and 1920x1080:
title with Continue + focus, both settings pages, achievements list, a continued run, keyboard
play, gamepad pause menu, the toast, results.

## Credits

No third-party assets: cursors, focus frames, medals and the 16 px icon are original pixel art
(`tools/art_platform.py`) in the 0x72 palette; the larger icon sizes reuse the existing app icon.
