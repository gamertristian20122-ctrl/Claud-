# Stream: bosses (Wax & Wane 2.1) - four more guardians

The owner asked for more bosses. Every floor now has **three** guardians (12 on the floors, 13 with the
Keeper), picked by the run seed like before. Branch `v21/bosses`.

## The four new guardians (`Enemy.DEFS`, AI in `scripts/game/guardians_v21.gd`)
All original and house-themed, drawn in `tools/art_monsters_bosses.py` like the other house guardians
(0x72 palette, 1 px #222222 outline, flat fills + one shade, feet on the bottom row, `glow_px` for the
parts that shine in the dark). Three phases each (66% / 33%), each change with a roar, a shockwave and a
banner line (`phase_lines`); every attack is telegraphed (a flash plus an attack frame, and a red lane,
ring or arrow on the floor first); only existing enemy shot kinds.

| Floor | Guardian | Look (size) | Phase 1 | Phase 2 | Phase 3 |
|---|---|---|---|---|---|
| Cellar | **THE COAL FURNACE** "It has warmed the house for a hundred winters" | a squat pot-bellied iron stove on claw feet, glaring eye-slits, a grate of iron teeth over live coals, a stovepipe (40x40) | **fire jets** down one red lane at Tallow (1.0 s warning, then a jet of fire to the wall); **coal**: 2 lumps coughed out of the stovepipe onto red rings round Tallow (never right on him), they smoulder 3.2 s and close off the floor (standing on one burns; a hot ring and a small flame mark them); **vent-stall**: it runs out of draw, the door hangs open, steam, "venting!": 2.4 s standing still taking **+50% damage** | "Full steam!": two lanes (one at Tallow, one beside, 0.9 s), 3 lumps, more coal in the rotation | "It is overheating!": three lanes in a fan (0.8 s), 4 lumps, every vent ends with a ring of 12 cinders (red ring 0.6 s first) |
| Crypt | **THE OSSUARY** "Every bone the crypt ever tidied away" | a heap of bones with a ribcage, skulls peering out and a great skull on top with grave-light eyes, long arm bones (44x40) | **skull arcs**: an arm swings up a skull and throws 3, one at Tallow and two near, each lands on its red ring and bursts into 5 bone shards; **bone fan** (5 `bolt_bone`) | "It falls to pieces...": **splits**: it rattles, drops into a spill of bones (untouchable) and 4 skulls roll out down red lanes fanned round Tallow; then a red ring marks where it will stand again, the skulls roll back to it along marked lines and it pulls itself together with a ring of 8 shards | "Every bone rattles!": splits more often (6 skulls), 4 skull arcs, 7-bone fans, 12 shards on reforming |
| Chapel | **THE ORGANIST** "It plays for the empty pews" | the chapel organ that learned to play itself: a mahogany case on lion feet, seven brass pipes, stop-knob eyes, a keyboard mouth and pale empty hands on the keys (48x50) | keeps to the top of the chapel; **scales**: the pipes play in order, left to right then right to left; their lanes fan out round where Tallow stood when the run began (the middle pipe aims at him), each pipe lights and its lane blinks for 0.6 s, then three pairs of notes (`bullet_water`, side by side) fly down it: the run sweeps across him one lane at a time, with a clear stretch between lanes; **sound ring** (a wall of 30 `bolt_ring`) with a **safe gap** marked first (a dotted ring with the gap left out and two pale lines either side of it): in phase 1 the gap is where Tallow stands; **pedal notes** (every other attack): the two outer pipes light and the organ flashes (0.55 s), then both fire 3 notes at Tallow from either side, each a spread of three (a crossfire to step out of) | "It plays in chords...": **chords**: three or four pipes at once, their lanes marked together (0.75 s), then another chord, and a hymn book flaps off its music stand (a Restless Psalter, at most two); four notes a lane; pedal runs of 4; two rings in a row, the gap off to one side and then the other (move into it) | "Every stop pulled out!": a **toccata** (13 notes up and down, faster), three chords, pedal runs of 5, rings in pairs |
| Belfry | **THE WEATHERCOCK** "It turns with every wind", victory "THE WEATHERCOCK FALLS SILENT" | the copper rooster off the belfry roof, green with verdigris, on its arrow and spindle over a compass cross, one hot eye (44x52) | **gust**: the vane spins and settles pointing the way the wind will blow; pale streaks drift that way across the whole room and three big double arrows blink over it (1.2 s), then the gale pushes Tallow for 2.2 s (50 px/s, slower than his 74; always toward the room's middle, never into a corner) while it flings aimed 3-dart volleys (each flashes first); **dart fan**: wings flung wide (0.45 s), a fan of 7 darts at Tallow; **spinning darts**: it spins up (0.7 s) and sprays three turning streams of `bolt_bone`; **hop**: a red ring where it will land, it hops there and lands with a ring of 12 shots | "The wind changes!": gusts in 8 directions (56 px/s), fans of 9 and a quick three after, four dart streams | "A storm breaks over the belfry!": the storm: a gust (62 px/s) with a slow two-armed dart spiral in it, fans of 11, five dart streams, 16 shots on landing |

Shot colours per guardian (all existing kinds; the projectiles stream redraws them bigger and self-lit):
Furnace: fire jets and coal are its own hazards (drawn unlit, dark-rimmed), cinders `bullet_purple`;
Ossuary: `bolt_bone` (bone white) and its rolling skulls (11x11 sprites, unlit); Organist: `bullet_water`
(notes) and `bolt_ring` (sound rings); Weathercock: `bolt_bone` (darts) and `bullet_purple` (landing).

### Fair on a phone
- Every hazard is seen before it hurts: lanes blink 0.6-1.0 s, rings 0.75-1.4 s, the gale's arrows 1.0-1.2 s.
- Hazards hurt like the guardians' bodies (8, coal and skulls 6, x the floor's `enemy_dmg_mult`) and are
  blamed on the guardian (`Records.blame`), so the death note names it.
- The vent-stall is a real opening (+50% damage, "venting!") and a split always ends with a marked reform
  point: the fights have rhythm, not just bullets.
- The gale is weaker than Tallow's walk (74 px/s) and moves him with `Player._move`, so walls, doors and
  cobwebs still count; it blows toward the middle of the room.

### Phase gate
`guardians_v21.gd` keeps `mem.hp_floor` (the gate in `Enemy._damage` from fix/balance QA-03) just under the next
phase's threshold, and a phase lasts at least 3 s (`MIN_PHASE`), so no burst skips a phase or its banner; held
hits ring like iron. Phase 3 is ungated. Queued notes and volleys of an old phase are dropped (`mem.seq`).

## Picks and the first-win rule
`world.FLOORS[n]["bosses"]` gains the new guardian as its third entry. `Enemy.pick_boss` is unchanged: picks
stay seeded by the run seed (`hash(seed:boss:floor) % 3`, so Tonight's Candle and typed-in seeds are the same
house for everyone), and a new player's first Belfry is still The Great Pendulum (`opts[0]`); the Hour Fiend
and the Weathercock join after a first win. (Seeds pick among three now, so a given seed can meet a different
guardian than it did in 2.0.)

## Text that changed
- `achievements.gd`: Night Watch "Snuff all twelve floor guardians." The check (`Records`, unchanged) counts
  every non-secret guardian, i.e. the 12 floor guardians, never the Keeper.
- Journal: entries and floors come from `Enemy.DEFS` / `FLOORS` (13 guardians, 2 pages). A locked
  Weathercock says "Some nights the wind turns on the belfry. Win once to feel it." (`journal.gd`, 2 lines).
- `tools/make_facts.py` counts "three per floor" from the code; `docs/marketing/facts.md` regenerated
  (13 guardians: 12 + the Keeper; 3 use 0x72 sprites, 10 were made for this game).
- Store texts (`steam_store.md`, `google_play.md`, `itch_page.md`, `press_kit.md`) say 13 guardians / three
  per floor; README's Guardians row, credits and commands. `tools/trailer_edit.py`'s card says
  "13 GUARDIANS" (the videos rendered for 2.0 still say 9 until `./tools/make_trailer.sh all` is re-run).
  Release notes that describe 2.0.0 itself were left alone.

## Tests
```
# one guardian's fight, any guardian, with its floor's fixed kit (GuardiansV21.TRIAL_KIT / TRIAL_WAX):
godot --headless --path . -- --autotest --playtest --speed=4 --runs=4 --boss=<kind>
#   [boss] furnace floor 1: SNUFFED in 25.2 s, hits 4, wax left 68, phases at 10/18 s
#   [boss] ... FELL after 61.0 s, guardian at 22% (phase 3), hits 9, phases at ...
# its versus card, two shots per phase taken mid-pattern, and its Journal page:
xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720 \
    -- --autotest --tour --boss=<kind> --shots=/abs/dir
```
Kit per floor: Cellar Bellows; Crypt + Beeswax, Lamp Oil; Chapel + Sharp Wick, Thimble; Belfry + Split Wick,
Wax Coat; plus +0.15 damage per guardian already beaten and 100 / 88 / 78 / 100 wax (with 72 wax at the Belfry
the bot died to the Great Pendulum and the Hour Fiend every time, which says nothing about their pace). Omens are
switched off.

## Balance judge (bot, `--speed=4`, `--boss=<kind> --runs=4`, the floor's kit above)
Each new guardian was fought 4 times and compared with its two floor-mates under the same kit (target: within
about +-30% on time to kill, hits taken and bot deaths). "Pace" is how long a whole guardian takes at the rate the
bot actually took its health (a death counts the share it took), so it compares fights the bot sometimes loses.

| Floor | Guardian | Fights | Bot deaths | Time to kill (s, mean of wins) | Pace (s per whole guardian) | Hits per fight | Hits per minute | Each fight |
|---|---|---|---|---|---|---|---|---|
| Cellar | Old Rot | 4 | 0 | 31.5 | 31.5 | 2.2 | 4.3 | 25s/0h, 33s/5h, 28s/1h, 40s/3h |
| Cellar | Wax Mother | 4 | 0 | 35.6 | 35.6 | 2.5 | 4.2 | 36s/3h, 36s/3h, 35s/3h, 35s/1h |
| Cellar | **Coal Furnace** | 4 | 0 | 29.6 | 29.5 | 2.8 | 5.6 | 30s/4h, 30s/2h, 29s/3h, 29s/2h |
| Cellar | *new vs floor-mates* | | +0.0 deaths | -12% | -12% | +16% | | mates: 33.5 s (pace 33.5), 2.4 hits |
| Crypt | Gaoler | 4 | 3 | 35.9 | 44.7 | 12.0 | 20.3 | died 41s@27%/11h, died 34s@14%/13h, died 31s@41%/13h, 36s/11h |
| Crypt | Sexton | 4 | 0 | 43.4 | 43.4 | 4.0 | 5.5 | 47s/5h, 45s/4h, 46s/5h, 36s/2h |
| Crypt | **Ossuary** | 4 | 0 | 40.8 | 40.8 | 7.2 | 10.7 | 46s/7h, 39s/9h, 36s/6h, 42s/7h |
| Crypt | *new vs floor-mates* | | -1.5 deaths | +3% | -7% | -9% | | mates: 39.7 s (pace 44.0), 8.0 hits |
| Chapel | Hollow Warden | 4 | 0 | 58.0 | 58.0 | 6.5 | 6.7 | 56s/5h, 60s/7h, 58s/7h, 59s/7h |
| Chapel | Melted Choir | 4 | 0 | 36.5 | 36.5 | 6.8 | 11.1 | 36s/9h, 36s/7h, 36s/7h, 36s/4h |
| Chapel | **Organist** | 4 | 0 | 44.2 | 44.2 | 5.2 | 7.1 | 46s/7h, 44s/5h, 42s/5h, 45s/4h |
| Chapel | *new vs floor-mates* | | +0.0 deaths | -6% | -6% | -21% | | mates: 47.3 s (pace 47.3), 6.6 hits |
| Belfry | Great Pendulum | 4 | 4 | - | 108.3 | 9.8 | 7.3 | died 57s@36%/11h, died 66s@26%/10h, died 125s@14%/7h, died 74s@27%/11h |
| Belfry | Hour Fiend | 4 | 2 | 56.5 | 58.4 | 9.0 | 9.5 | 57s/9h, 56s/6h, died 55s@5%/11h, died 60s@5%/10h |
| Belfry | **Weathercock** | 4 | 2 | 90.4 | 98.5 | 10.0 | 6.4 | died 101s@1%/11h, 105s/6h, 76s/12h, died 94s@17%/11h |
| Belfry | *new vs floor-mates* | | -1.0 deaths | n/a (the Pendulum never fell) | +18% | +7% | | mates: pace 83.4 s, 9.4 hits |

How it got there (new guardian vs the mean of its floor-mates; time to kill / hits):
| Guardian | First build | Pass 1 | Pass 2 | Final |
|---|---|---|---|---|
| Coal Furnace | hp 86: -26% / +79% (coal under the bot's feet) | hp 100, 2/3/4 coals, 1.0 s first warning: -15% / +142% | hp 106, coal lands round Tallow: **-12% / +16%** | = pass 2 |
| Ossuary | hp 106: -6% / -9% | skulls hurt only while rolling: **+3% / -9%** (pace -7%) | = pass 1 | = pass 1 |
| Organist | hp 152, fixed lanes: -25% / -58% | hp 180, lanes fan round Tallow, quicker: -5% / -70% | pedal crossfire: -3% / -66%; then ring walls (30), rings in pairs, pedal spreads: -8% / -70% | hymn books from phase 2, pedal crossfires twice as often, lane notes in pairs: **-6% / -21%** |
| Weathercock | hp 234, 72 wax: pace -24% / -68%, 0 vs 4 deaths | hp 224, fans + gale volleys, 100 wax: -35% / -36%, 0 vs 3 | hp 260, more darts, stronger gales: -26% / -15%, 0 vs 3 | hp 280: **pace +18% / hits +7%, 2 vs 3 deaths in 4** |

### Normal runs (fresh profile, fresh seeds, `--playtest --speed=4 --runs=8`, all four new guardians in the pools)
NORMAL_PLACEHOLDER

## Hooks (outside my files)
- `enemy.gd`: four `DEFS` entries (before the Keeper) and the AI dispatch line (`g21_*` -> `GuardiansV21.ai()`).
- `world.gd`: the third entry in each `FLOORS[n]["bosses"]` (+ the comment above the Belfry).
- `autotest.gd`: `--boss=<kind>` in `_next_run` (trial) and in the tour dispatch (tour), 2 header lines.
- `achievements.gd` (Night Watch text), `journal.gd` (the locked Weathercock's hint), `gallery.gd` (a comment).

## For the other v2.1 streams
- **Slots / difficulty**: the guardians' health is `DEFS[kind]["hp"]` like the others, read in
  `Enemy.setup`; scale it there and the gate (`mem.hp_floor`) follows `max_hp`. Hazard damage goes through
  `GuardiansV21._hit` (x `enemy_dmg_mult()`), so a difficulty multiplier on that function covers jets, coal,
  skulls and landings.
- **Shots**: no new shot art. The hazards draw themselves (`FireJet`, `CoalLob`, `CoalBed`, `RollSkull`,
  `SkullLob`, `Gust`, `PipeLights` in `guardians_v21.gd`); if the shots stream changes Telegraph, the lanes and
  rings here use only `line()`, `ring()` and `path()`.

## Known issues
- The play-test bot ignores ground warnings (red lanes, coal rings, skull lanes, landing rings: it only sidesteps
  bullets that head its way) and never looks for the Organist's ring gap. So it takes hazard hits a person would
  not; the numbers above were still tuned against the bot (it is the judge), which makes the Coal Furnace and the
  Ossuary's skulls a little kinder to people than to the bot.
- The trailer and shorts rendered for 2.0 still show "9 GUARDIANS" (the card text is updated; re-run
  `./tools/make_trailer.sh all`). Store screenshots and key art show none of the new guardians yet.
- Seeds now pick among three guardians, so a seed typed in 2.0 can meet a different guardian in 2.1 (Tonight's
  Candle stays the same for everyone on the same version). In random runs the Weathercock, like the Hour Fiend,
  only turns up after a first win.
- The Organist's notes leave from its pipe mouths and fly over its own case for a few pixels (shots draw above
  creatures); it reads as notes pouring out of the pipes.
- The hazards draw themselves (unlit, dark-rimmed); if the shots stream restyles enemy shots, the fire jets, coal,
  rolling skulls and gale streaks keep their own look and may want a matching pass.
