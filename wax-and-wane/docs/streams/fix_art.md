# Stream: fix/art (art and readability fixes from the v1.9.3 review)

Branch `fix/art`. Findings: **C5** (art half: the Hollow Warden), **C6** (guardians and champions blend into
the floor), **UX-03** (creatures vanish in Tallow's hard shadows), **UX-02** (player and enemy shots told
apart only by hue), plus the stretch goal from **C9** (house touches on the most-seen stock lodgers).
Visual only: no balance numbers, no seeded RNG, no UI scripts.

## What changed (before -> after)

### C5 - the Hollow Warden has its own body
- Before: `Enemy.DEFS["necro_boss"]` was `"sprite": "ogre"` with a lavender tint: the Gaoler's bare-armed
  ogre in the chapel, although its lore talks about robes.
- After: an original 36x40 guardian drawn in `tools/art_monsters_bosses.py` (`warden_frame`, `build_warden`):
  a pewter cowl and robe over a ragged hem that never touches the floor, a wine stole with gold fringe, a black
  void in the hood with two cold eye-lights, and a brass lantern on a chain from an empty sleeve. 4 idle,
  4 run (it glides, the lantern swings), 4 atk (lantern raised, eyes flare). Same conventions as the other
  guardians (0x72 palette only, 1 px #222222 outline, flat fills + one shade, feet/hem anchored at the bottom).
- `necro_boss` drops `sprite` / `tint`; its eye-lights and lantern glass are `glow_px`, so they shine in the
  dark chapel. `_ai_boss_vicar` plays `atk` for the spiral and the summon (two one-line hooks).
- Every consumer already read `def.get("sprite", kind)` / `def.get("tint")`: the gallery, the Journal
  portrait, the boss versus card, the death note and the results picture all show the new art.
- Not done here (other streams): making the Great Pendulum the first-win Belfry guardian (`pick_boss`) and the
  store / trailer boss shots.

### C6 - guardians and champions read against the floor
`scripts/game/creature_glow.gd` + `creature_glow.gdshader`: one extra unshaded draw of the current frame over
the sprite, added by `Enemy._ready` (`CreatureGlow.attach(self)`) to guardians, special-room champions, marked
foes and anything with `glow_px`:
- a 1 px rim just outside the dark outline, only on the side that faces Tallow's candle (the candle catching
  the edge): warm `#fccba3` for guardians and champions, the aura colour for marked foes;
- guardians carry a soft pale light pool that follows them round the arena (`PointLight2D`, colour
  (0.74, 0.8, 0.96), energy 0.55, scale 0.42; not the Keeper, whose tower has its own light);
- guardians stand on a ground shadow ~3/4 of their width (`Enemy._boss_shadow`, was a fixed 22x5 blob).

| Judge: each guardian across a dark room from Tallow | before | after |
|---|---|---|
| brightest 10 % vs floor (WCAG), min of 8, full wax | 2.70 (Gaoler), 2.73 (Sexton), 3.21 (Old Rot) | **8.08** |
| same at 25 % wax | 2.70 | **8.13** |
| median, full / 25 % wax | 4.45 / 4.08 | 9.25 / 9.25 |
| the review's crop measure, min full / 25 % wax (below 3:1) | 1.96 / 2.04 (4 / 5 of 8) | 3.94 / 4.04 (0 / 0) |
| whole-body median vs floor, median of 8 | 1.21 | 1.75 |

### UX-03 - creatures in Tallow's hard shadows
- **Shadow floor.** `lighting.gd` gives Tallow's light a twin that only creature sprites see (light mask bit 9,
  `CREATURE_BIT`; marked by its `height` 16, which only `LIGHT_POSITION.z` exposes), with shadows on and a white
  shadow colour. `lit_flash.gdshader` (creatures only) makes the twin add nothing where his light reaches; in his
  shadow the engine swaps the twin's light for its shadow colour times `SHADOW_MODULATE`, which the shader sets
  to `shadow_floor` (0.7) of his light. So a lodger behind a pot keeps 70 % of the candle light while the floor
  under it stays in hard shadow. Rooms, Tallow and pickups are untouched (their shaders never see the twin).
  `pixel_light.gdshaderinc` now exposes `px_light()`; shaders that need their own `light()` define
  `PX_OWN_LIGHT` first.
- **Glowing eyes.** `Enemy.DEFS[kind]["glow_px"]` lists palette colours that give off their own light (added
  over the lit sprite by the glow pass, x0.8 for lodgers): eyes of the slugs, imp, Hooded Mourner, Clapper Bat,
  Sootling, Gutterspout, the Rose Melt's wick, the Cinder Rat's embers, the Snuffer's and the Lamp Moth's red
  sparks, the Cog Sentry's lens. The Puddle Lump had nothing light on it at all: it now has a rainwater glint in
  each eye hole (`tools/art_monsters.py` `build_house_touches`).

| Judge: every lodger of each floor behind a 14 px occluder (57 per row) | before | after |
|---|---|---|
| in shadow, full wax: min / median brightest-10 % contrast | 1.22 / 1.81 | **4.67** / 9.65 |
| in shadow, 25 % wax | 1.21 / 1.84 | **3.32** / 7.47 |
| creatures below 3:1 in shadow (full / 25 % wax) | 47 / 44 of 57 | **0 / 0** |
| lit reference (no occluders), min | 2.47 (Puddle Lump) | 3.01 |
| the review's crop measure (contrast.py on the sprite rect + 3 px), in shadow: median full / 25 % wax | 1.51 / 1.46 | 5.04 / 3.84 |
| same, creatures below 3:1 (full / 25 % wax) | 49 / 50 | 9 / 21 |

"Brightest 10 %" is the review's "ink" measured on the creature's own pixels (shot A minus shot B) against the
floor right round it. The review's crop measure is reported for comparison only: on a 16 px creature it mixes
floor into the "ink" and creature into the "background", so it is below 3:1 for 10-11 of 57 creatures even
fully lit with no shadow at all (before: Larder Thief 1.97, Sootling 2.21; after: Tincture Doctor 1.97) and cannot be the pass mark.

### UX-02 - friend or foe by shape and lightness
- Every enemy shot is now a dark-rimmed token (1 px #21141b all round) with a white-hot core of at least a
  quarter of its inside, and the rest in the darkest tones of its hue: plum, moss and black-water orbs, a
  plum wax bead with a drip, a white sound ring, a bone, a page with ink lines. Tallow's embers stay bright
  flames with no dark rim (dark-rim share of the edge: enemy shots 50-100 %, player shots 0 %).
- The Clock Tower cog is white enamel with ivory teeth (was gold, dE 7-12 to the ember). Pewter, as the review
  suggested, measured dE 17-22 to the Blue Flame's ember under protanopia, so it is ivory instead.
- `tools/art_fx2.py` owns all eight shots (`ENEMY_SHOTS`, `ORB_SHAPE` / `ORB_TONES`); `art_hero_fx_items.py`
  (orbs) and `art_tower.py` (cog) hand over to it in one line each, `art_monsters.py` takes its bolts from it.

| dE76 of mean colour to the ember / blue ember (normal, protan, deutan) | before | after |
|---|---|---|
| bullet_green vs ember, protanopia / deuteranopia | 3 / 13 | 51 / 58 |
| bolt_cog vs ember (normal / protan / deutan) | 12 / 9 / 7 | 45 / 44 / 42 |
| bullet_water vs blue ember (normal / protan / deutan) | 15 / 12 / 11 | 33 / 31 / 31 |
| worst pair over all eight shots | 3 | **30.2** (bolt_wax vs blue ember, protan) |
| floor contrast (tools/design_contrast.py rule), worst bullet | 3.75 | **6.05** |

The UX review's own `bullet_de.py` on the new sprites agrees (min 30 for normal / protan / deutan; tritanopia
min 29, cog vs ember and green vs blue ember).

### Stretch (C9, "asset flip"): house touches on the three stock lodgers met first
Same size, same AI, the stock 0x72 frames with a few pixels of the house (`tools/art_monsters.py`
`shambler`, `larder_thief`, `damp_slug`; written as `monsters/<kind>_idle|run_f*.png`, which
`Enemy.frames_for` prefers over the stock frames):
- **Coal-Bin Shambler** (tiny_zombie): a cap of coal dust and two coal-bright sparks in its eye holes (glow).
- **Larder Thief** (goblin): wears a stolen candle end on its head, still lit (the flame glows).
- **Damp Slug** (tiny_slug): has crawled into a brass candle cup and wears it as a shell.

## Hooks (one-liners in other files)
- `scripts/game/enemy.gd`: DEFS (`necro_boss` art, `glow_px` entries), `_ready` adds `CreatureGlow.attach(self)`
  and the guardian shadow, `_boss_shadow()`, two `play_anim("atk", ...)` lines in `_ai_boss_vicar`.
  `_damage` and `pick_boss` are untouched.
- `scripts/autotest.gd`: `elif args.has("artjudge"): await ArtJudge.run(self)`.
- `tools/art_hero_fx_items.py`, `tools/art_tower.py`: one line each handing the enemy shots to `art_fx2.py`.
- `tools/art_monsters.py` no longer deletes the Clock Tower creatures' frames when it clears its folder.

## For other streams
- New creature art: list its light-giving colours in `glow_px` (eyes, flames). They must not be used elsewhere
  on the sprite (the pass matches exact colours).
- New lit shaders for creatures should include `pixel_light.gdshaderinc` as before; only `lit_flash.gdshader`
  handles the twin. A new shadowed light would need its own twin to keep the shadow floor.
- New enemy shots: draw them in `art_fx2.ENEMY_SHOTS` and run `python3 tools/design_bullets.py --judge DIR`.

## Judges and commands
```
python3 tools/design_bullets.py --judge DIR [--floors FLOORSHOTS]   # UX-02: dE table, floor contrast, CVD sheet
xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720 \
    -- --autotest --tour --artjudge --shots=DIR [--set=shadow|bosses|cards [--only=<kind>]]
python3 tools/art_judge.py DIR [BEFORE_DIR]                         # UX-03 / C6 contrast tables
```
Baseline numbers come from the untouched `e3a03f4` tree with the judge script copied in; the after numbers from
the final tree (`--artjudge`, all sets). Screenshots of both runs are listed in the hand-off.

## Known issues / not done
- The twin light adds one more shadow-map pass for Tallow's light; its GPU cost on a real phone is not measured
  (CPU-only container). If a phone struggles, Lite could drop the twin (creatures then go dark in shadow again).
- The 40 px Warden and the 56 px Keeper crowd the top row of the bestiary's `--tour --gallery` guardian sheet
  (the sheet's layout, not the art).
- The finding's suggested pewter cog was replaced by ivory (see UX-02); tritanopia stays at dE 29 for two pairs.
- README / store copy still say the stock lodgers are 0x72 (they still are, with house touches): the store
  stream may want to word the remix.
