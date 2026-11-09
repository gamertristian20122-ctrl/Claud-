# Stream: boss intros (Wax & Wane 2.4) - every guardian makes an entrance

The owner asked: "add intro animations to the bosses". Every one of the 16 guardians now makes a short entrance
(1.4-2.0 s) where its fight starts, built only from its existing frames (idle / run / atk and its specials: mound,
rise, sing, grab) and the existing juice (shake, dust, sparks, smoke, stains, small lights). Names, art, titles and
lines are untouched: this stream only adds entrances. Branch `v24/boss-intros`.

## The entrances (`scripts/game/boss_intro.gd`, class `BossIntro`)
| Guardian | Length | Entrance |
|---|---|---|
| Old Rot | 1.5 s | a black shape at the back of the room lurches forward in two heavy steps (thud, dust, a little shake), colour comes back as it reaches the light, then a low groan |
| The Wax Mother | 1.6 s | a puddle of her crimson wax spreads and bubbles; she oozes up out of it (squashed flat, then tall, then a wobble), flicking wax drops; what is left of the puddle stays as a stain |
| The Coal Furnace | 1.6 s | a cold, dark stove rumbles and puffs smoke from its pipe while the coals slowly wake; then the door bursts open (its door-open frames) in a gout of sparks and embers, a flash of firelight and a shake |
| The Gaoler | 1.4 s | it tramps out of the dark (two steps), rears up and stamps: dust kicked out along the floor all round, a heavy thud and its keys rattling |
| The Sexton | 1.6 s | the floor heaves: his mound with the spade in it trembles and throws dirt, then he bursts up out of it (spade raised, a hop, debris) and lands |
| The Ossuary | 1.8 s | its spill of bones (mound frames); scattered bones hop in and two skulls roll in from the sides, it rattles together, rises (its three rise frames) and its eyes light teal |
| The Hollow Warden | 1.8 s | in the dark only its lantern catches (a match strike, a flicker) and its eyes open; then the rest of it is there |
| The Melted Choir | 1.7 s | three voices rise out of their wax one after another on a rising third (a hand bell each), then all sing as one (sing frames, a chord, a soft shockwave) |
| The Organist | 1.9 s | a dark organ; its pipes light one by one, left to right, on a rising scale (the same pipe lights its fight uses), then it plays a chord (sing frames, bells and a toll, a shockwave) |
| The Great Pendulum | 1.9 s | it drops out of the dark above on a short rod that runs out to full length, swings through with a deep toll, tick... tock, and settles at rest where its fight starts |
| The Hour Fiend | 1.4 s | a ring of hellfire flares up, a column of fire bursts (scorch mark, shake) and it stands in the flames glowing hot, cools to its colours and roars |
| The Weathercock | 1.6 s | blown in on a gust from across the room (its pale wind streaks), spinning on its spindle (grab frames, slowing down); it lands, spreads its wings and crows |
| The Stockpot | 1.7 s | it simmers, steams and rattles harder and harder (bubbles over the rim), then boils over (atk frames): hot broth thrown out, splats on the floor |
| The Head Librarian | 1.6 s | two lenses glint in the dark between the shelves (dust falls from them), then she steps out into the light, pages rustling |
| The Dressmaker's Form | 1.6 s | it rolls in on its castors from across the room (clicks, a dust trail), tips forward as it stops, wobbles and stands; its pins glint |
| The Keeper of Hours | 2.0 s | a clock face of pale light draws itself (a hand sweeps the rim, the hours appear, the hands spin), it steps out of the glow as a pale shape, colour comes in, and the hour strikes (bell, shockwave, shake) |

## The hook
`world._start_boss` (two lines): the gap after the versus card is 0.5 s (was 0.9 s), then the guardian is spawned
and `BossIntro.play(world, boss)` starts its entrance (it replaces the plain spawn-in fade and the spawn shake).
So the time from the card's end to the guardian's first move is 1.9-2.5 s (was about 1.85 s).
`enemy.gd` (4 lines): `intro` (true while the entrance plays: `_physics_process` returns before the AI and the
touch, `take_hit` ignores every hit) and `spawn_tw` (the spawn-in fade, killed by the entrance).
While it plays the guardian stays `active = false` too, so shots fly through it, aim assist and the special moves
leave it alone, and a bomb that sets `active` is undone the next frame (and its hit is ignored).

## Rules it keeps
- Harmless and untouchable; the AI waits (its cooldowns do not run either, so the fight opens as before).
- Tallow can move from the first frame of the entrance.
- **Skipping:** any tap, key, click or pad button, or Tallow's first shot (`aim_input`), ends it at once: the
  guardian snaps to its spot and pose with a white flash and fights. A press in the first 0.12 s is taken as the
  versus card's skip still arriving and ignored. Pause stops it (the menu's presses do not skip it).
- Shakes go through `world.shake` (the Screen shake setting); the sprite rumbles are 1 px sprite moves.
- Visual-only randomness (`randf`); nothing seeded is read, so runs stay deterministic from the seed.
- Everything is drawn in the room (under / over the guardian), below the HUD's layer: nothing covers the wax bar.
  New drawing is whole pixels in the 0x72 palette (puddle, bones, flames, wind, bubbles, the clock face).
- When it ends the guardian is exactly as its fight expects it (position, sprite, colour, rim, light pool, the
  Pendulum at rest, the Organist's pipes dark); the tour checks this for all 16.
- Continued runs: Save & Continue snapshots at the start of each floor, so a continued run always meets its
  guardian fresh and the entrance plays as normal; there is no half-fought guardian to come back to.

## Tests
- `godot --headless --path . -- --checkscripts`: clean.
- `godot --headless --path . -- --checkrooms`: 0 problems.
- `stdbuf -o0 godot --headless --path . -- --autotest --playtest --speed=4 --runs=1 --god`: see the result line
  below (the bot aims at the guardian, which counts as a shot, so it mostly skips the entrances).
- `xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720 -- --autotest --tour --intros --shots=DIR`
  (new; `--intros=<kind>` for one guardian): each guardian's entrance shot twice at its signature moments
  (`TOUR_AT`), then a line `[intros] <kind>: <len> s, ends ready: true`; then one entrance skipped with a key press
  (`[intros] skip: ... true`) and one with the versus card and the camera punch-in. Last line
  `[intros] done, 0 problem(s)`. The shots were reviewed as x3 crops round each guardian.

## Files
- New: `scripts/game/boss_intro.gd` (the entrances, the hook, the tour).
- `scripts/game/world.gd` (`_start_boss`: 0.9 -> 0.5 s, the hook), `scripts/game/enemy.gd` (`intro`, `spawn_tw`,
  two gates), `scripts/autotest.gd` (`--tour --intros` dispatch + one header line), `README.md` (layout + command).

## Known issues
- The play-test bot skips most entrances (its aiming counts as a shot); the tour plays them whole.
- The camera punch-in after the versus card (Juice) still runs as soon as the guardian appears (0.8 s), so for
  most guardians the zoom is back out before the climax (the door bursting, the stomp, the strike). It reads well
  as it is; it could be retimed to the climax later.
- The letterbox bars after the card still cover the top HUD strip for their usual ~0.8 s (as in 2.3; the 0.4 s
  shorter gap means they now go 0.4 s sooner).
- Squash and stretch (the Wax Mother rising, the Choir's voices, the Gaoler's stamp, the Keeper stepping out) scale
  the pixel sprites for a moment, like the lodgers' existing spawn-in; no new frames were drawn.
- Old Rot, the Gaoler and the Head Librarian walk in from up to 16 px behind their spot (never from inside a prop),
  the Dressmaker's Form rolls in from 58 px to the side and the Weathercock flies in from 72 px away: nothing
  collides on the way, so in a cramped layout one can pass over a prop for a moment.
- No new sounds: the Weathercock's crow is the guardian roar pitched up, the Organist's scale and chord are the
  hand bell its pipe warnings already use.
- Special rooms' champions (mini-bosses) have no entrance: they are not guardians and start as before.
