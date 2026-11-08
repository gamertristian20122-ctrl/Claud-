# Stream: lightpass (pixel-art light and shaders)

Branch `revamp/lightpass`. Visual only: no gameplay numbers, no seeded RNG (the shaders use `FRAGCOORD`
and `TIME`; the haze seed uses the global `randf()`), so Tonight's Candle is unchanged.

## What it changes
- **Banded, dithered light** (`scripts/game/lit.gdshader`, `pixel_light.gdshaderinc`, `px_dither.gdshaderinc`).
  Godot's 2D light was a smooth radial ramp over crisp pixel art. Now every lit canvas item runs one shared
  `light()`: each light's strength is cut into flat bands (4 per unit of light, so Tallow's light has 5
  rings) and neighbouring bands meet in a 4x4 Bayer checker on the game-pixel grid (`FRAGCOORD`: the world
  draws into the 384x216 / 480x216 viewport texture, so one fragment is one game pixel). Only the light
  factor is stepped: the sprite's palette colour is untouched and the light keeps its hue (chapel glass,
  ember red, blue flame, moonlight). Otherwise the maths is the engine default
  (`LIGHT = COLOR * LIGHT_COLOR * LIGHT_ENERGY`, added), checked pixel-exact before banding was switched on.
- **Hard pixel shadows**: shadowed lights (Tallow's) use `SHADOW_FILTER_NONE`: crisp pixel steps, no PCF blur.
- **Waning house**: below 40 % wax the room pieces (floor, walls, decor, obstacles, stains), and the light
  falling on them, lose colour in 8 steps (85 % grey at an empty candle), and a dark vignette in three
  dithered steps of the house's own dark closes in on a point between the screen centre and Tallow.
  The vignette is computed inside the room material, so it costs no extra full-screen pass. Fire, embers,
  every flame, shots, Tallow, creatures, pickups, props that carry their own light (candelabras, hearths)
  and the whole HUD keep full colour, so threats and the wax bar read better as the house greys.
  The HUD's red low-wax glow is stepped + dithered (`dither_alpha.gdshader`) instead of a smooth gradient.
- **Heat haze** (`heat_haze.gdshader`): small screen-reading patches over Tallow's flame (overlapping the
  tip), lit hearths and the Blowlamp jet. Whole pixel rows slide 1 px left/right at a 10 fps cadence; every
  pixel is an exact copy of a neighbour (no blur, palette intact). Hidden while its light is off.
- **Shockwave ring** (`shockwave.gdshader`): bomb blasts (radius = bomb radius) and guardian phase changes
  (radius 56): an expanding ring pushes pixels outward by 1-2 whole pixels for 0.32 s.
- **Effects: Full / Lite** (Settings > Game, `Game.settings["effects"]`, default `full` on every device).
  Lite removes the haze, the shockwaves and the vignette. Banding and the colour loss stay (no extra cost).
- **Fixes found on the way** (pixel evidence from the judge):
  - `flame_lean.gdshader` multiplied the texel by `COLOR`, which in Godot 4 already holds the texel, so the
    flame palette was squared (#ee8e2e drew as #de4f08, #facb3e as #f5a20f): 0 % of the flame's pixels were
    0x72 colours, now 100 %. The sputter tint (self_modulate) still reaches it (vertex-colour varying).
  - The creature flash shader read the bare texture, so a sprite's `modulate` never showed: champion tints
    (ember, gilded, sooty, chilled), recoloured guardians (`"tint"`) and the 0.35 s spawn fade-in.
    `lit_flash.gdshader` uses the incoming COLOR (texture x modulate); same `flash` / `tint` uniforms.
    **Visible change for the bestiary**: champions are now tinted as `CHAMP_TINT` intended.

## Hooks (one-liners in other files)
- `world._ready` and `title._ready`: `Lighting.attach(self)` (after the layers exist).
- `enemy.gd`: `_flash_shader = Lighting.flash_shader()`; `on_new_phase()` calls `Lighting.shockwave(...)`.
- `world._explode` and `world.on_boss_phase`: `Lighting.shockwave(world, pos, radius, 2.0)`.
- `room._light_hearth`: `Lighting.haze(holder, offset, size, glow_light)`; `relic_fx._ready`: the jet's haze.
- `hud.gd`: `vignette.material = Lighting.dither_material()`.
- `game.gd`: default `"effects": "full"`; `settings_panel.gd`: the Effects row + a hint.
- `autotest.gd`: `--lightjudge` dispatch; `--bench` prints canvas draw calls + fps under a real renderer.
- How materials are assigned: `Lighting` listens to `SceneTree.node_added`. Any `CanvasItem` under the host
  that is not a `Control`, not inside a `CanvasLayer` and has **no material of its own** gets the room or
  the actor lit material. Code that sets its own material (before or after `add_child`) wins, so
  `Art.unshaded`, the burn fade, the Keeper's grey and every other custom shader are untouched.
  **New lit shaders in other streams** should `#include "res://scripts/game/pixel_light.gdshaderinc"`
  (it brings `light()` and the `wane` uniform), and remember that in Godot 4 the fragment's incoming
  `COLOR` already contains the texture (do not multiply by `texture(TEXTURE, UV)` again).
- `Lighting.haze(parent, offset, size, watch_light)` and `Lighting.shockwave(world, global_pos, r, amp)`
  are free for other streams (both respect Lite).

## Judge (outside measurements)
`xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720
-- --autotest --lightjudge --shots=DIR > DIR/judge.log`, then `python3 tools/light_judge.py DIR [BEFORE_DIR]`.
Baseline = the untouched `b50ead8` tree with the same judge script copied in.

| Measure | Before | After |
|---|---|---|
| Distinct luminance levels along a ray, flat 0x72 panel under Tallow's full-wax light (max / mean of 16 rays) | 45 / 42.4 | **5 / 4.4** (target <= 6) |
| Light-factor levels per ray in the real start room (several overlapping lights; median / max) | 12 / 15-16 | 6-7 / 8 |
| Albedo frame (lights off) identical to before | - | 99.92-99.95 % (the rest = the 59-px flame fix + 1 ember) |
| Pixels no light reached before, unchanged | - | 99.91 % (same exceptions) |
| Flame pixels that are 0x72 palette colours | 0 % | **100 %** |
| Room-only mean saturation, 20 % wax / 100 % wax | 0.942 | **0.615-0.625** |
| Whole-frame mean saturation, 20 % / 100 % | 0.947-0.96 | 0.731-0.735 |
| Saturation of fire pixels at 20 % wax | 0.705 | 0.777-0.78 (fire keeps colour) |
| Champion slug tint visible (blue/red of the body, plain vs chilled) | no (0.92 vs 0.90) | **yes** (0.93 vs 1.24) |
| Haze: changed pixels that are not a 1-px copy | - | 0 of 7-16 per frame |
| Shockwave: changed pixels that are not a <= 2-px copy | - | 0 of 311-344 (one run: 1, a moving particle) |
| Packed build (`--export-pack Linux`, judge from the .pck) | - | shaders + includes load, same numbers |

### Performance
- `--autotest --bench` headless (CPU per physics step / process frame, busiest room per floor, ms avg;
  same-period pair, 4 shared cores, other streams running): physics 1.54 / 1.59 / 1.53 / 1.71 ->
  1.62 / 1.70 / 1.56 / 1.77; frame 0.49 / 0.53 / 0.41 / 0.42 -> 0.52 / 0.51 / 0.45 / 0.42.
  (First baseline run: 1.46 / 1.49 / 1.67 / 1.68 and 0.47 / 0.48 / 0.42 / 0.40.) Inside run-to-run noise;
  the pass adds no physics work.
- `--bench` under xvfb + llvmpipe (CPU-rendered GL, 1600x720 window, crowded rooms): fps
  46 / 49 / 46 / 48 -> 45 / 48 / 49 / 48; canvas draw calls avg 273 / 280 / 196 / 205 -> 277 / 306 / 218 / 206
  (max 308 / 342 / 262 / 269 -> 330 / 324 / 270 / 263): two shared lit materials split a few batches,
  plus one draw per haze patch.
- Judge room: canvas draw calls 29 -> 30 (Tallow's haze), 30 -> 31 at 20 % wax, +1 while a ring is up.
- Full vs Lite in one process (paused room, llvmpipe fps, 3 runs): full wax 94 / 114 / 123 vs Lite
  105 / 117 / 132; 20 % wax 95 / 108 / 123 vs Lite 107 / 123 / 135. So Full costs about 3-12 % of a
  CPU-rasterised frame; banding alone (Lite) shows no cost against the baseline (105-132 vs 102-114 fps).
- Full-screen passes added: **1** (the automatic 480x216 screen copy, no mipmaps, only in Full while a haze
  patch or ring is on screen). The vignette lives in the room material: 0 passes. Limit was 2.
- Shaders are GLES3 / Compatibility-safe: no compute, no derivatives, no loops, dither maths kept to
  values below 16 (mediump-exact), `filter_nearest` screen reads.

## Known issues / not done
- GPU cost on a real phone is not measured (CPU-only container). Full stays the default on phones; if a
  phone struggles, Lite drops the screen copy. The phone bench is the integrator's call.
- The platform tour's "d-pad down focus" check fails on the pause menu; it fails identically on the
  untouched baseline (not from this stream).
- Dust motes keep Juice's light-only CanvasItemMaterial (smooth light, but they are single pixels).
- Shadows are hard now; very long shadow wedges from tall props are stronger than the old soft ones.
