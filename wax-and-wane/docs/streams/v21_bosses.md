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

BALANCE_PLACEHOLDER

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
