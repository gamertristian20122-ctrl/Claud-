# Stream: v21/shots (easier-to-see enemy shots)

Branch `v21/shots`. The owner, who plays on a phone (about 480x216 game pixels on a small screen): "make it a
little bit easier to see the projectiles from enemies". Visual only: no hitbox, speed, damage, spawn or seeded
RNG changes (checked below: the same shots hit Tallow on the same physics frame at the same distance).

## What changed (before -> after)

### 1. Every enemy shot redrawn one step bigger and bolder (`tools/art_fx2.py`, `assets/art/fx/`)
- 2.0: 7x7 dark-rimmed tokens; the three orbs and the wax bead were mostly dark body with a 6 px white core,
  so on a dark floor only the core showed (a 3 px dot on the phone).
- 2.1: two drawn sets, both keeping the 2.0 friend-or-foe language (1 px `#21141b` outline all round, a
  white-hot core of at least a quarter of the inside, Tallow's embers stay bright flames with no dark rim):
  - **Normal: 9x9** `fx/<kind>_f0/_f1`, **Large: 11x11** `fx/<kind>_lg_f0/_f1` (`BIG_SHAPES[9|11]`).
  - a **1 px rim of the shot's own colour** just inside the outline. On the orbs and the wax bead it is lit on the
    top-left and falls into shade on the bottom-right (a glossy bead), which is also what keeps them far from
    the embers for colour-blind players; bone, page, cog and ring get an ivory / parchment rim.
  - a **bigger white core** (orbs 10-12 px of white instead of 6), so the bead reads at a glance.
  - **frame 1 is a gentle pulse**: the core one or two pixels bigger (orbs, wax), the ring's white and ivory
    swap, the bone tumbles, the page turns, the cog turns a notch. Two hard frames, no alpha.
  - colours (all 0x72 palette; picked with `design_bullets.py --judge`):

| shot | rim (lit / shade) | body | core |
|---|---|---|---|
| bullet_purple | `#f78697` / `#9b1a0a` | `#5f2d56` plum, `#9b1a0a` | `#fdf7ed` |
| bullet_green | `#51c43f` / `#3d734f` | `#3e5442`, `#2a2a3a` | `#fdf7ed` |
| bullet_water | `#72d6ce` / `#1f1833` (black water, a lit rim) | `#302c2b` | `#fdf7ed` |
| bolt_wax | `#f78697` / `#9b1a0a`, with a drip | `#62232f`, `#9b1a0a` | `#fdf7ed` |
| bolt_bone / page / ring / cog | ivory `#d3bfa9` / parchment `#e2b694` / tan `#aa8d7a` | white | white |

- The 2.0 7x7 drawings stay in `ENEMY_SHOTS` (and `ORB_SHAPE` / `ORB_TONES`): a shot that only has one of
  those (for example a new shot from another stream) is grown to 9 / 11 px by `grow()` (its old outline and the
  new ring take its brightest colour, a new `#21141b` outline goes round), until it is drawn in `BIG_SHAPES`.

### 2. Drawn at full brightness everywhere, gentle pulse, trail (`scripts/game/shot.gd`)
- Self-lit: the sprite already had the unshaded material in 2.0 (checked on screen: the white core is exactly
  `#fdf7ed` on every floor at 100 % and 20 % wax, in the dark corner too: the CanvasModulate, the lights and the
  waning never touch it). Now the shot node itself is unshaded as well, so its trail is self-lit.
- All enemy shots pulse in step at 5 fps (one clock: a burst or a spiral breathes as one; 2.0 flickered at 12 fps).
- Shots at **>= 80 px/s** (aimed fans, dashes, the Sexton's bones; not the slow 52-72 px/s rings of a burst)
  draw a steady **3 px trail** right at their back edge: two pixels of the rim colour, one darker
  (`ENEMY_TRAIL`, ivory for bone / cog / page / ring and any new shot). Tallow's spark trail is different on
  purpose: three single pixels 3 px apart, orange to brown, flickering.
- The trail is redrawn only when its direction or "fast enough" changes (the Keeper's stopped time sets
  `vel` to zero: the trail goes and comes back), not every frame.

### 3. Setting "Enemy shots: Normal / Large" (`settings_panel.gd`, `game.gd`)
- `Game.settings["shot_size"]`: `"large"` on phones (`OS.has_feature("mobile")`), `"normal"` on desktop. A
  save without the key (every 2.0 player) gets the default.
- Settings > **Controls** page, one cycle button. On a phone it sits next to Aim assist in the empty cell; on
  desktop it is a third row. (On the Game page the extra row pushed Achievements / Back off a 216 px tall
  screen on desktop: the fit check caught it.)
- Applies live: every enemy shot listens to `Game.settings_changed` and swaps its drawing, a shot already in the
  air included (`--shotjudge --set=hit` prints `normal 9 px -> large 11 px -> normal 9 px`). A shot with no
  Large drawing keeps its Normal one.

### 4. Telegraphs read on bright floors and in the dark (`scripts/game/enemies/telegraph.gd`, drawing only)
- 2.0: 1 px dots (every other red / pink dot in its hot partner colour); on the bright lit floor of the crypt
  the red dots nearly vanished.
- 2.1: every dot is **2 px tall inside a 1 px `#21141b` outline** (outlines drawn first so they never cover a
  neighbour's dot). Lines, rings and the Pendulum's dotted sweep all use it; the blink, colours, hot partners,
  timings and shapes are unchanged. The Pendulum's rod already had a dark outline.

## Judges (before = the 2.0.0 tree, `82b56b8`; after = this branch)

### Colour-blind distance and floor contrast (`python3 tools/design_bullets.py --judge DIR`, both sets)

| | 2.0 (7 px) | 2.1 Normal (9 px) | 2.1 Large (11 px) |
|---|---|---|---|
| worst dE76 to the ember / blue ember (normal, protan, deutan; target >= 30) | 30.2 (wax vs blue ember, protan) | 31.6 (water vs blue ember, protan) | 32.3 (water vs blue ember, protan) |
| worst floor contrast (design_contrast rule; target >= 3) | 6.04 | 6.04 | 6.04 |
| dark rim share of the edge (embers: 0 %) | 50-100 % | 67-100 % | 57-100 % |

Per shot, dE76 of the mean colour to the ember | the Blue Flame's ember, normal / protan / deutan (/ tritan):

| shot | 2.0 | 2.1 Normal | 2.1 Large |
|---|---|---|---|
| bullet_purple | 63/66/62 (32) \| 46/31/34 (64) | 40/43/36 (13) \| 62/39/49 (77) | 42/46/39 (15) \| 61/39/49 (76) |
| bullet_green | 63/51/58 (57) \| 34/34/35 (29) | 58/40/47 (57) \| 39/39/40 (23) | 59/42/50 (57) \| 38/38/38 (24) |
| bullet_water | 73/68/73 (56) \| 33/31/31 (39) | 65/57/58 (59) \| 33/32/35 (28) | 64/57/58 (57) \| 34/32/36 (30) |
| bolt_wax | 63/66/61 (31) \| 47/30/33 (64) | 39/43/36 (8) \| 59/36/48 (73) | 41/45/39 (13) \| 59/37/48 (74) |
| bolt_bone | 56/54/52 (43) \| 41/36/43 (46) | 52/49/48 (38) \| 41/34/42 (45) | 55/52/51 (41) \| 41/35/43 (46) |
| bolt_cog | 45/44/42 (29) \| 43/35/43 (49) | 47/45/44 (31) \| 41/34/42 (48) | 46/45/43 (31) \| 42/34/43 (48) |
| bolt_page | 51/49/48 (36) \| 38/32/40 (45) | 45/44/42 (29) \| 41/34/42 (47) | 44/43/41 (28) \| 45/37/46 (51) |
| bolt_ring | 59/57/55 (47) \| 36/32/38 (39) | 51/49/47 (37) \| 41/34/42 (45) | 52/49/48 (38) \| 41/34/42 (45) |

The sweep behind the colours (scratch scripts, every 0x72 colour as rim / shade / body): a full bright ring of
any blue, cyan or grey-blue lands within dE 7-29 of the Blue Flame's ember under protanopia, so the water shot
keeps its 2.0 "black water" body and gets a lit rim on its top-left half only; the green rim works only as
`#51c43f` / `#4ba747` over a near-black body (the lime greens turn into the ember's yellow under protanopia). The CVD sheet (`bullets_cvd.png`) shows the two cues that do
not depend on colour at all: enemy shots are round, dark-rimmed and darker on average; embers are flames.
Tritanopia (not in the target, as in 2.0): the pink and red beads now sit at dE 8-15 from the ember (2.0: 31-32).

### On the screen (`--tour --shotjudge`, measured by `python3 tools/shot_judge.py AFTER BEFORE`)
Every enemy shot held still on floors 1-4 and the Clock Tower, at 100 % and 20 % wax (waning on: `wane_level`
0.5), across the lit floor above Tallow and in a top-right corner held in his hard shadow by an occluder bar,
1600x720 (480x216 game px). 16 shots per layout, 160 per set, the worse of the two pulse frames counts.
- contrast: the shot's brightest (or darkest) 10 % against the median of the floor in a 3 px band round it.
- seen: the shot's pixels that stand out >= 3:1 from that floor, and the side of their bounding box.

| | 2.0 (7 px) | 2.1 Normal (9 px) | 2.1 Large (11 px) |
|---|---|---|---|
| drawn size on screen (game px) | 7 | 9 | 11 |
| shot contrast vs local floor, worst of 160 (target >= 4.5) | 6.29 | 6.29 | 5.99 |
| shots below 4.5:1 | 0 of 160 | 0 of 160 | 0 of 160 |
| pixels >= 3:1 per shot, mean per layout (lit row) | 11-14 | 22-27 | 37-42 |
| visible side (bounding box of the >= 3:1 pixels), lit row | 4.2-4.5 px | 6.1-6.5 px | 8.0-8.5 px |
| telegraph dots that read >= 3:1 (per layout) | 72-85 % | 82-100 % | 81-100 % |
| telegraph dot contrast, median (per layout) | 5.6-7.9 | 7.8-12.0 | 7.8-12.0 |

Per kind (all floors, both wax levels, both places): mean pixels >= 3:1 and visible side.

| kind | 2.0 | 2.1 Normal | 2.1 Large |
|---|---|---|---|
| bullet_purple | 6 px, 3.0 | 17 px, 5.0 | 25 px, 6.9 |
| bullet_green | 9 px, 3.9 | 18 px, 5.2 | 26 px, 7.1 |
| bullet_water | 6 px, 3.2 | 17 px, 5.0 | 25 px, 7.0 |
| bolt_wax | 7 px, 3.5 | 17 px, 5.0 | 24 px, 6.9 |
| bolt_bone | 13 px, 5.0 | 19 px, 7.0 | 39 px, 9.0 |
| bolt_cog | 28 px, 7.0 | 39 px, 9.0 | 63 px, 11.0 |
| bolt_page | 21 px, 5.0 | 41 px, 7.0 | 70 px, 9.0 |
| bolt_ring | 12 px, 5.0 | 28 px, 7.0 | 52 px, 9.0 |

Read: in 2.0 the purple, water and wax shots showed a 3 px dot on a phone (their dark body is invisible on a
dark floor); in 2.1 a 5 px (Normal) / 7 px (Large) bead, plus the coloured rim, which shows as colour even
where it is below 3:1. The contrast of the ink was already high in 2.0 (the white core) and stays above 4.5:1
everywhere, in the dark corner and at 20 % wax included. The telegraph's worst single dots (1.0-2.4:1, floors 1, 2 and 5) are
red dots crossing a mid-grey lit floor, where neither the red nor the dark outline reaches 3:1 on its own; their
hot-yellow neighbours carry the line there.
`--set=look` shots (fast shots with trails, both sizes, every floor) and the guardians' fights
(`--tour --bosses`) were looked at as well.

### Gameplay unchanged
- `--tour --shotjudge --set=hit` (shots fired at a still Tallow from 60 px at 52 / 80 / 108 px/s):
  2.0, Normal and Large all touch him after **62 / 40 / 30 physics frames at 6.27 / 6.67 / 6.00 px**.
- The bot is not frame-deterministic (two runs of this build with the same seed already differ 8 s in), so a
  same-seed comparison with 2.0 cannot be exact; the hit test above is the exact check, and the diff touches no
  gameplay number (`radius`, `vel`, `dmg`, `life`, spawns and the hit test in `shot.gd` are unchanged).
- `--playtest --speed=4 --runs=2 --god`: both reach the end (2 wins, floors 4 and 5); `--playtest --speed=4
  --runs=2`: no script errors (2 losses, floors 2 and 4: normal for 2 runs).

## Hooks (one-liners in other files)
- `scripts/autotest.gd`: `elif args.has("shotjudge"): await ShotJudge.run(self)`.
- `scripts/autoload/game.gd`: the `shot_size` default. `scripts/ui/settings_panel.gd`: the Controls-page row.

## For other streams
- **New enemy shot**: draw it in `art_fx2.ENEMY_SHOTS` as before (7 px), then either add it to `BIG_TONES` with a
  9 / 11 px drawing in `BIG_SHAPES`, or leave it to `grow()`. Run `python3 tools/design_bullets.py --judge DIR`
  (add the kind to its `ENEMY` list) and keep dE >= 30. Give it a trail colour in `Shot.ENEMY_TRAIL` (else ivory).
- After merging a branch that drew 7 px shots with the 2.0 tool, re-run `python3 tools/design_bullets.py` once:
  it rebuilds every enemy shot in both sets.
- New warnings: use `tele().line / ring / path` and they get the outline for free.

## Commands
```
python3 tools/design_bullets.py --review DIR --judge DIR      # rebuild both sets, CVD table, floor rule, sheets
xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720 \
    -- --autotest --tour --shotjudge --shots=DIR [--set=look|hit]
python3 tools/shot_judge.py DIR [BEFORE_DIR] [--sheet OUT.png]   # the tables above + a before/after sheet
```

## Known issues / not done
- The purple orb is now mostly blood-red with a pink rim and a little plum (2.0: dark plum and wine): plum
  bodies pull it within dE 20-31 of the Blue Flame's ember under protanopia. Its name stays `bullet_purple`.
  The purple orb and the wax bead share the pink rim; the bead has its drip.
- Tritanopia (very rare, not in the 2.0 target either): pink / red beads vs the ember drop to dE 8-15.
- The Keeper's stopped-time marks start 6 px from a bolt's centre (`keeper.gd`, not touched): with Large
  11 px cogs the first mark touches the cog's outline.
- Real-phone check not done (no device here): the 5 fps pulse and the trail were judged on 1600x720 screenshots.
- `--tour --bosses` at 1600x720 lists two `[fit] OVER` lines on the Cellar guardians (the floor label and the
  first-run controls tip); they come from the HUD, not from this stream (see the hand-off for the 2.0 check).
- `ENEMY_TRAIL` in `shot.gd` repeats the rim colours from `art_fx2.BIG_TONES`: change both together.
