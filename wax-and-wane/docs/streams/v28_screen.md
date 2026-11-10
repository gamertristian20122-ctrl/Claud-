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
which now stand on the room's corners, thin out to 30% while Tallow or a lodger is underneath
(`hud._fade_under`). Classic keeps its HUD exactly.

