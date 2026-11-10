# Stream: v28/screen (Wax & Wane 2.8) - a bigger picture

A fresh look at 2.7 measured it: the room covered about 40% of a 1080p phone and about a third of a 720p phone,
and 720p / 1440p phones and the Steam Deck showed the game inside a black border (the picture used 81% of the
glass). A scout's cold read of the screenshots said the same thing in other words: "the rooms are big and mostly
empty, and the sprites are tiny". This stream makes the room fill the screen's height on every device. Branch
`v28/screen`. No gameplay change, no version bump, no APK.

## What changed

**Settings > Controls > Screen: Big / Classic** (`Game.settings["screen"]`, default `big`).

- **Classic** is the picture the game always had: one 384x216-based picture, enlarged by one whole number.
- **Big** draws the world at its own whole-number scale, the biggest that still shows the room wall to wall
  (250 x 180 art pixels), while the menus and the HUD keep their own scale and their 384x216-at-least layout:

| Screen | Classic | Big: world | Big: menus + HUD |
|---|---|---|---|
| 1920x1080 (monitor, 16:9 phone) | x5 | **x6** | x5 (384x216) |
| 2560x1440 | x6, bordered | **x8** | x6 (427x240), no border |
| 2400x1080 (20:9 phone) | x5 | **x6** | x5 (480x216) |
| 1600x720 (20:9 phone) | x3, bordered | **x4** | x3 (534x240), no border |
| 1280x800 (Steam Deck) | x3, bordered | **x4** | x3 (427x267), no border |
| 1280x720 (itch.io frame, small laptop) | x3, bordered | **x4** | x3 (427x240), no border |
| 1152x648 | x3 | x3 | x3 (the same picture as Classic) |
| 1024x768 (4:3) | x2, bordered | **x4** | x2 (512x384), no border |

The rule (`Stage._fit`): `ku = floor(min(W / 384, H / 216))`, `kw = max(ku, floor(min(W / 256, H / 180)))`.
180 rows is the room from the top of its top wall to the foot of its bottom wall, and it is the height 720, 1080,
1440 and 2160 all divide by, so on those screens the walls meet the top and bottom edges exactly. A top door's
arch (12 rows above the wall) is cut by the screen's edge when the view is exactly 180 rows; a taller view
(the Steam Deck's 200 rows, 4:3) shows it.

A desktop window: the project's 1536x864 window is 384x216 x4, where Big can do no better than Classic. On a
screen with room for it, Big opens **1600x900** instead (the room at x5, wall to wall in height; menus at x4).
The browser build: give itch.io a **1280 x 720** frame (was 1152 x 648).

## How it works (scripts/stage.gd)

`Stage` is the new root of the main scene (`scenes/boot.tscn`); it owns `Main` and decides how the picture reaches
the glass. In Classic it adds Main as a plain child and leaves the root viewport as project.godot sets it
(viewport / expand / integer): the old path, untouched. In Big it switches the root to the screen's own resolution
and puts two low-resolution buffers under it: `world_vp`, shown `kw` times enlarged, and over it `ui_vp`, shown `ku`
times enlarged (a `SubViewportContainer`, so touches, clicks and keys go in as before). Main lives inside `ui_vp`,
so every screen, menu and HUD still sees the same "viewport" it always saw. Both buffers share one `World2D`: a
run's world node gets a visibility-layer bit that `ui_vp`'s cull mask leaves out and `world_vp`'s takes, so the
world is drawn once, in the world buffer, under a canvas transform copied from the run's own `Camera2D` before
every frame (shake, the punch-in, room pans and boss zooms follow by themselves). The UI buffer is transparent and
is laid over the world with premultiplied alpha. Nothing in the world was moved in the scene tree: lights, shadows,
the banded pixel light, haze and shockwaves are the same nodes and shaders in a low-resolution buffer, only larger
on the glass.

Hooks: `world._ready` / `_exit_tree` (`Stage.attach_world` / `detach_world`); `main.goto` (`Stage.boundary`: a
changed Screen setting takes hold between two screens: at once on the title, when the night ends in a run);
`hud._mouse_aim` and `Lighting`'s low-wax vignette (`Stage.to_ui` / `to_view` / `view_size`: where a world thing
is on the glass); `Controls` (its `_input` / `_unhandled_input` run from the UI buffer's first child in Big, at
the moment they always ran: after the screen's nodes, before its Controls; focus is read from `Stage.ui_viewport`);
`Achievements` (its toast layer moves into the UI buffer); `autotest._shot` and `store_shots._snap`
(`Stage.grab`: the composed screen).

The HUD in Big: the layout is the one every size already used, with three additions. On 16:9 the coin and bomb
counters stack inside the left gutter (side by side they stood on the floor's corner). The gauge and the minimap,
which now stand on the room's corners, thin out to 40% while Tallow or a lodger is underneath
(`hud._fade_under`). Classic keeps its HUD exactly.

## Before -> after

Picture: `docs/streams/img/v28_screen_before_after.png` (the real X screen, Classic left, Big right; a 1080p
monitor above, a 720p phone below).

The picture's box was read from grabs of the real X screen (`Xvfb` at that size, the game fullscreen, `ffmpeg
-f x11grab`). The room's share is its walls (250 x 180 art pixels) at the scale the `[stage]` line reports; the
pixel judge below proves the world really is that whole-number enlargement.

| Screen | Classic: picture on the glass | Classic: room (width x height = share of the screen) | Big: picture | Big: room |
|---|---|---|---|---|
| 1920x1080 | full | 1250x900 px: 65% x 83% = **54%** | full | 1500x1080 px: 78% x 100% = **78%** |
| 2560x1440 | 2304x1296, border all round | 1500x1080: 59% x 75% = **44%** | full | 2000x1440: 78% x 100% = **78%** |
| 2400x1080 (phone) | full | 1250x900: 52% x 83% = **43%** | full | 1500x1080: 62.5% x 100% = **62.5%** |
| 1600x720 (phone) | 1440x648, border all round | 750x540: 47% x 75% = **35%** | full | 1000x720: 62.5% x 100% = **62.5%** |
| 1280x800 (Steam Deck) | 1152x720, border all round | 750x540: 59% x 67.5% = **40%** | full | 1000x720: 78% x 90% = **70%** |
| 1280x720 (itch.io frame) | 1152x648, border all round | 750x540: 59% x 75% = **44%** | full | 1000x720: 78% x 100% = **78%** |
| 1152x648 | full | 750x540: 65% x 83% = **54%** | full | the same (x3 is all 648 rows hold) |
| 1024x768 (4:3) | 768x576, border all round | 500x360: 49% x 47% = **23%** | full | 1000x720: 98% x 94% = **92%** |

Tallow (16 art pixels tall) is 80 -> 96 screen pixels on a 1080p screen, 48 -> 64 on a 720p phone and the Steam
Deck, 96 -> 128 at 1440p.

## Judges and results (all on the merged 2.8.0 + this stream)

- **Classic is the old path.** Reference: the untouched 2.8.0 build's `--tour --gui` at 1600x720 with
  `--fixed-fps 60 --rngseed=28` (two runs of the untouched build agree on 9 static screens to the pixel; the other
  8 differ only inside the room's box, by flame flicker and sparks, which run on the wall clock). After the change,
  `--screen=classic`: the same 9 static screens are pixel-identical except the Controls page, which now has the new
  Screen row; the other 8 differ only inside the room's box, as two untouched runs do. `[stage] classic: screen
  1600x720, ui 480x216 x3, world 480x216 x3`.
- **Big composes exactly.** `--tour ... --layers` saves each shot's two buffers; `tools/stage_check.py` rebuilds
  the screen from them (world enlarged kw times, UI enlarged ku times and laid over) and compares it with the
  game's own picture: identical wherever the UI is absent or opaque, within 1 of 255 where it is translucent (the
  UI buffer is 8 bits per channel). 1920x1080: 118 shots over six tours, 0 failed. 1600x720: 110 shots over five
  tours, 0 failed. 1280x800: 36 shots, 0 failed. 1280x720: 17 shots, 0 failed.
- **Big at one scale is Classic.** `--screen=big --stagekw=3` at 1440x648 against the same reference: outside the
  room's box no channel differs by more than 1 of 255 (the new Screen row aside).
- **Layout**: `--tour`, `--tour --gui`, `--tour --feel`, `--tour --primer`, `--tour --platform` with `--fit` in Big
  at 1920x1080 and 1600x720, plus `--tour --pace` at 1920x1080, `--tour` at 1280x800 and `--tour --gui` at
  1280x720: 0 `[fit]` lines, 0 SCRIPT ERROR, 0 FAIL lines in all 13 runs. A fake notch (`--safe=96,0,48,0` at
  1600x720): the HUD moves in, 0 `[fit]` lines.
- **Headless, in Big** (a dummy 64x64 display gets the whole 384x216 picture, both scales 1, as Classic):
  `--checkscripts` 92 ok; `--checkrooms` exit 0; `--primercheck` PASS (default and `--device=touch`);
  `--feelcheck` PASS; `--movescheck` PASS (0 failed); `--qacheck` 0 failed; `--talkcheck` 48 checks, 0 failed;
  `--diarycheck` 42 checks, 0 failed; `--pacecheck` 0 failed; `--nightdump` equals
  `docs/streams/v22_night_baseline.txt`; `--playtest --god --runs=1 --speed=4 --seed=7` WIN, 0 SCRIPT ERROR.
  (`--feelcheck` and `--talkcheck` first failed: a paused game stopped the UI buffer's container from handing
  input on, so the map and a talking scene could not be closed. Fixed: the container always processes, Main keeps
  pausing as it did.)
- **`--bench`** (headless, CPU per frame, seed 5): physics step avg 1.31 ms in Big, 1.44 ms in Classic; process
  frame avg 0.74 ms vs 0.81 ms. No worse (the difference is noise). The extra work is on the GPU: one more
  full-screen pass (two textured quads at the screen's own size); not measurable here.
- **The pitch deck's shots**: `--autotest --shots-store --storeboss=pendulum --meltstrip` at 1920x1080 now saves
  16 pictures at **1920x1080**, the composed screen (menus and HUD x5, the room x6): use them as they are, no
  enlarging. `--screen=classic` gives the 384x216 pictures as before (tools/store_art.py passes it, because it
  composes its store pictures from that size).

## Known limits

- **No real phone or desktop GPU was tried.** Everything above ran on Mesa's software renderer. Compositing two
  buffers, its cost on a low-end phone, and notches on real hardware are untested. Screen: Classic is the way back.
- A top door's arch is cut by the screen's edge when the view is exactly 180 rows (1080p, 720p, 1440p). The Steam
  Deck's 200 rows and 4:3 show it whole.
- On a 16:9 screen with touch controls the sticks and buttons lie on the room's edges (there is no gutter to hold
  them). With keys, a mouse or a pad nothing covers them.
- 1152x648 and the project's 1536x864 window hold no extra step of scale: there Big is Classic's picture. Hence the
  1600x900 window and the 1280x720 frame.
- The Screen switch takes hold between two screens (the title lights itself again; a run keeps its picture until
  it ends), never in the middle of one.
- Translucent UI over the world can differ from Classic by 1 of 255 per channel.
- Tool modes that read the picture pixel by pixel at 1x keep Classic by themselves: `--herosheet`, `--keyart`,
  `--lightjudge`, `--artjudge`, `--shotjudge`, `--designcheck`, `--trailer`.
- The mouse pointer's shape over menu buttons in Big was not checked (it cannot be seen under Xvfb).
