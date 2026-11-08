# Stream: lightpass (pixel-art light and shaders)

Branch `revamp/lightpass`. Visual only: no gameplay numbers, no RNG use (the shaders use `FRAGCOORD`
and `TIME`; the haze seed uses the global `randf()`), so Tonight's Candle is unchanged.

## What it changes
- **Banded, dithered light** (`scripts/game/lit.gdshader`, `pixel_light.gdshaderinc`, `px_dither.gdshaderinc`).
  Godot's 2D light is a smooth radial ramp laid over crisp pixel art. Now every lit canvas item runs a
  shared `light()`: each light's strength is cut into flat bands (4 per unit of light, so Tallow's light
  has 5 rings) and neighbouring bands meet in a 4x4 Bayer checker on the game-pixel grid
  (`FRAGCOORD` = game pixels with the "viewport" stretch mode: the judge images show the dither period is
  exactly 4 px at 480x216). Only the light factor is stepped: albedo stays the palette colour, the light
  keeps its hue (chapel glass, ember red, blue flame, moonlight). Maths otherwise identical to the engine
  default (`LIGHT = COLOR * LIGHT_COLOR * LIGHT_ENERGY`, additive), verified pixel-exact before banding.
- **Hard pixel shadows**: shadowed lights (Tallow's) use `SHADOW_FILTER_NONE`, so shadow edges are crisp
  pixel steps instead of a PCF blur.
- **Waning house**: below 40 % wax, room pieces (floor, walls, decor, obstacles, stains) lose colour in
  8 steps (up to 85 % grey at an empty candle), and a dithered vignette in three steps of `#111111`
  closes in on a point between the screen centre and Tallow. Fire, embers, the flame, shots, Tallow,
  creatures, pickups and the whole HUD keep full colour (they are unshaded, use the actor material or
  live in the HUD layer), so threats read better as the house greys. The HUD's red low-wax glow is now
  stepped + dithered (`dither_alpha.gdshader`) instead of a smooth gradient.
- **Heat haze** (`heat_haze.gdshader`): small screen-reading patches over Tallow's flame (overlapping the
  tip), lit hearths and the Blowlamp jet. Whole pixel rows slide 1 px left/right at a 10 fps cadence; every
  pixel is an exact copy of a neighbour (no blur, palette intact). Hidden while its light is off.
- **Shockwave ring** (`shockwave.gdshader`): bomb blasts (radius = bomb radius) and guardian phase changes
  (radius 56): an expanding ring pushes pixels outward by 1-2 whole pixels for 0.32 s.
- **Effects: Full / Lite** (Settings > Game, `Game.settings["effects"]`, default `full` on every device).
  Lite removes the haze, the shockwaves and the vignette (the only screen-reading or full-screen passes).
  Banding and the colour loss stay: they are part of the lit material and cost nothing extra.
- **Fixes found on the way** (pixel evidence in the judge):
  - `flame_lean.gdshader` multiplied the texel by `COLOR`, which in Godot 4 already holds the texel, so
    the flame palette was squared (#ee8e2e drew as #de4f08, #facb3e as #f5a20f): 0 % of flame pixels were
    0x72 colours, now 100 %. The sputter tint (self_modulate) still reaches it (vertex colour varying).
  - The creature flash shader read the bare texture, so the sprite's `modulate` never showed: champion
    tints (ember, gilded, sooty, chilled), recoloured guardians (`"tint"`) and the 0.35 s spawn fade-in.
    `lit_flash.gdshader` uses the incoming COLOR (texture x modulate); same `flash` / `tint` uniforms.

## Hooks (one-liners in other files)
- `world._ready` and `title._ready`: `Lighting.attach(self)` (after the layers exist).
- `enemy.gd`: `_flash_shader = Lighting.flash_shader()`; `on_new_phase()` calls `Lighting.shockwave(...)`.
- `world._explode` and `world.on_boss_phase`: `Lighting.shockwave(world, pos, radius, 2.0)`.
- `room._light_hearth`: `Lighting.haze(holder, offset, size, glow_light)`; `relic_fx._ready`: the jet's haze.
- `hud.gd`: `vignette.material = Lighting.dither_material()`.
- `game.gd`: default `"effects": "full"`; `settings_panel.gd`: the Effects row + a hint.
- How materials are assigned: `Lighting` listens to `SceneTree.node_added`; any `CanvasItem` under the
  host that is not a `Control`, not inside a `CanvasLayer` and has **no material of its own** gets the
  room or actor lit material. Code that sets its own material (before or after `add_child`) wins, so
  `Art.unshaded`, the burn fade, the Keeper's grey and every other custom shader are untouched.
  **New lit shaders in other streams** should `#include "res://scripts/game/pixel_light.gdshaderinc"`
  (it brings the `light()`), and remember that in Godot 4 the fragment's incoming `COLOR` already
  contains the texture.
- `Lighting.haze(parent, offset, size, watch_light)` and `Lighting.shockwave(world, global_pos, r, amp)`
  are free for other streams to use (both respect Lite).

## Judge (outside measurements)
- `xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720
  -- --autotest --lightjudge --shots=DIR > DIR/judge.log` then `python3 tools/light_judge.py DIR [BEFORE_DIR]`.
  It writes and measures: a flat 0x72 panel under Tallow's full-wax light (luminance levels along 16 rays),
  the start room lit / unlit / albedo (light-factor levels, palette identity, unlit pixels unchanged),
  100 % vs 20 % wax (mean saturation, saturation of fire pixels), haze and shockwave on/off (every changed
  pixel must be a copy of a pixel <= 1 px / <= 2 px away), flame palette + sputter tint, and a plain vs a
  champion slug (the tint must show).
- `--bench` now also prints canvas draw calls and fps when run with a real renderer (xvfb).

RESULTS_PLACEHOLDER
