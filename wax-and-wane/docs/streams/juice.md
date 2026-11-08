# Stream: juice (game feel and effects)

Branch `revamp/juice`. Everything here is visual or feedback only; no balance, loot or RNG changes
(all juice randomness uses the global `randf()`, never the seeded floor/loot RNGs, so Tonight's Candle
stays identical for everyone).

## What it adds
- **Tallow** (`scripts/game/player.gd`, 2.0 look "Tallow, reborn"): idle breathing (a belly row), squash and
  stretch when starting and stopping (belly rows + 1 px width), little hops while running with swinging arms,
  a 1 px recoil and a flare (or a dip of the smaller flames) on every shot, a hurt squish with a white flash,
  the hurt face, flailing arms, a torn flame and wax knocked off, the side tears that run down while walking
  and drop off as wax dots on the floor, the face following the clock (worried / tired), a
  guttering flame with smoke threads below 20% wax, "hold aloft" for 0.9 s when a relic, tonic or keepsake
  is taken (icon above the flame, gold glint; Tallow cannot move or be hurt meanwhile), and a 1.2 s melt-down
  on death (the body sinks into the dish, wax spills down and spreads on the floor, the flame shrinks and
  pops into smoke, the room goes dark) before the results screen.
- **Floor stains** (`scripts/game/stains.gd`): one `Stains` sprite per room bakes every splat, gib, wax drop
  and bomb scorch into a single 240x144 image (one draw call, capped at 900 stamps a room). Images are kept
  per floor by Juice, so a room still shows its history when you come back. Splats are coloured per creature.
- **Gibs** (`scripts/game/fx_gibs.gd`): 4-8 chunks per kill on a fake-z arc, one bounce, then they soak into
  the stain image. Max 48 in flight.
- **Particles** (`scripts/game/fx_parts.gd`): one capped pool per layer drawn in one `_draw`: wall-impact
  sparks, hit sparks, muzzle puffs, flame embers (more while moving fast or with the Hearth rite), wax drops,
  smoke, door dust. Colour ramps only, no alpha fades. Dust motes use a light-only material so they show only
  inside candle light.
- **Shots** (`scripts/game/shot.gd`): a 3-pixel spark trail behind player embers, sparks off walls and on hits.
- **Boss intro card** (`scripts/game/boss_card.gd`): ~1.8 s, the tree is paused (the boss cannot act), two
  slanted bands slide in, the guardian at nearest x3 with its name, Tallow x2 with the time left, speed
  streaks, a landing flash and shake, `Audio.play("boss_sting")`. Any key, tap, click or pad button skips it.
  Then letterbox bars and a quick camera punch-in on the boss as it appears. The play-test bot passes it
  (tested `--god --runs=2`: both runs beat all four bosses).
- **Boss finale**: four escalating flashes, poofs, sparks and gib bursts, 0.4 s slow motion after the hit-stop,
  then one huge splat (`fx/splat_8`/`splat_9`) with a ring of smaller ones.
- **Screen transitions** (`scripts/game/burn.gdshader`): paper-burn dissolve on a 2 px grid with a 4-step ember
  edge (#fdf7ed, #facb3e, #ee8e2e, #8f4029). `main.gd` uses it for every screen change (cover, then the dark
  burns away); the world's trapdoor fade uses it too. `main._busy` is unchanged.
- **Title** (`scripts/ui/title.gd`): ~2.2 s opening: darkness, a match strikes (`Audio.play("match_strike")`),
  carries its flame to the wick, the room light blooms past full and settles, the logo flickers on, embers rise,
  the menu slides in. Any tap/key skips it and never presses the button under it.
- **Room clear**: dust bursts out of every door, a soft expanding ring of light from the candle, a small shake.
- **Shake / hit-stop**: `world.shake()` now goes to Juice (smooth noise, small hits x0.55, big ones x1.15,
  scaled by the Screen shake setting, which may be a bool or a 0..1 strength). Tiny hit-stop on heavy/marked
  kills and on bomb blasts.

## Hooks other streams should know
- `Juice.of(world)` returns (or creates) the world's Juice node. Events: `enemy_killed(e)`, `boss_finale(e)`,
  `boss_card(kind, title)`, `room_cleared()`, `relic_taken(id)`, `player_died()`, `descended()`,
  `attach_stains(room)`, `splat(pos, material, big)`, `scorch(pos)`, `sparks(pos, dir, n, blue)`.
- `Juice.holding(world)` is true while the boss card is up (enemy.gd and shot.gd check it).
- New fx helpers at the bottom of `world.gd`: `fx_scorch`, `fx_sparks`, `fx_muzzle`, `fx_wax_drop`, `fx_wisp`,
  `fx_glint`, `fx_stain(pos, material, big)`.
- **Bestiary**: add an optional `"stain"` key to `Enemy.DEFS`: a material name (`goo ash blood red wax
  pumpkin ice soot ichor`) or any `Color` (it is turned into a 3-step ramp snapped to the 0x72 palette).
  Unknown kinds get a default from their name (slug/zombie -> goo, skel/bone/ghost -> ash, imp/demon -> blood,
  wax/candle -> wax, ice/frost -> ice, else red). The card uses `DEFS[kind]["sprite"]` / `"tint"` like enemy.gd.
- **Audio**: plays `boss_sting` (boss card) and `match_strike` (title). Missing files are silent (audio.gd).
- **Rooms**: stains attach to `room.floor_layer` (first child, so pits/spikes/decals draw over them) and read
  `room.char_at()` / `room.cell_of()` to keep stains out of pits. `Room.doors` (dir -> Sprite2D) is used for
  the door dust. If the room stream renames these, update `Juice.attach_stains` / `room_cleared`.
- **Relics**: `Player.hold_aloft(texture)` can be called for any special pickup.
- **Platform**: the boss card and title skip on any `InputEventKey`, mouse button, screen touch or joypad
  button press; the card calls `hud.release_sticks()` when it ends.
- The bot: `--autotest ... --nocard` skips the boss card if a test ever needs that.

## World edits (one-liners)
`_build_room` (attach stains), `_start_boss` (the banner line became `Juice.of(self).boss_card(kind, name)`),
`descend`, `_clear_room`, `collect_item`, `on_keepsake_taken`, `on_enemy_killed`, `_boss_down`,
`on_player_died` (the immediate smoke line became `Juice.of(self).player_died()`), `_explode` (the 6-line
scorch sprite block became `fx_scorch(pos)`), and `shake()` / `fx_drop()` in the effects section.

## Tests / tour
- `--tour` now also shoots: `title_intro`, `burn_cover`, `burn_reveal`, `gibs`, `room_clear`, `stains`,
  `stains_return` (persistence), `relic_aloft`, `melt_1`, `melt_2`, `boss_card`, `boss_punch`,
  `boss_finale`, `boss_splat`.
- `--autotest --herosheet --shots=DIR` writes `hero_sheet_1x.png`, `hero_states.png` (row A = the concept sheet's
  frames in order, row B = every other juice state, x6) and `hero_candles.png` (6 candles x 100/60/25 %);
  `--herosheet --costumes` the costume line-up, `--herosheet --ingame` the real cellar crop like the concept's
  `ingame.png`.
- Art: `python3 tools/art_fx2.py [--review DIR]` writes `assets/art/fx/splat_0..9.png`, `gib_0..5.png`,
  `glint_f0..1.png` (all original, 0x72 palette, no anti-aliasing). No third-party assets were added.

## Performance
Particles are capped (180 hot + 140 lit + 22 motes), gibs at 48, all drawn as rects/textures in a handful of
`_draw` calls. Stains are one texture per room; the image is re-uploaded at most once per frame and only on
frames that stamp something. Ember shot lights keep their existing cap of 6.
