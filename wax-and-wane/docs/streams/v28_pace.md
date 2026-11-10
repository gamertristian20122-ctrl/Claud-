# Stream: v28/pace (Wax & Wane 2.8) - less walking, a livelier first floor, a faster first launch

The owner asked what would make the game a lot better. Instead of guessing, this stream recorded a real run,
watched it frame by frame and measured six full bot runs on 2.7.0. Three things stood out; this stream fixes the
first two and the first-launch flow (the third, the size of the picture on the screen, is stream `v28/screen`).

## What the measurements said (2.7.0, seeds 7-12, `--playtest --speed=4`, fresh profile, level 2)

| Measure | 2.7.0 |
|---|---|
| Wins | 6 of 6 (the game's target is about half) |
| Time fighting | 51.1% |
| Walking between rooms (to the next door + back through cleared rooms) | 28.3% |
| Walking to pickups | 10.5% |
| A run | 750 s on average |
| Floor 1 | 4 fights of 1-3 lodgers (2.25 a room), about 10 creatures in the first two minutes |
| A newcomer's way in | Light the wick -> pick a slot -> pick a difficulty -> pick a night's length -> the opening -> the lesson |

(The first two runs alone read 44% walking; six runs give 39%.)

## What changed

1. **The hurry** (`Player.HURRY` 1.6): in a room that is clear and quiet (`world.hurry_ok()`: doors open, cleared,
   nothing awake) Tallow walks 1.6 times as fast. It builds over 0.45 s and is gone 0.12 s after a room wakes; his
   turns stay as sharp (the acceleration scales with it). His fighting pace and every dodge are unchanged.
2. **The hop** (`world.warp_to`, `FullMap`): on the full map a room already cleared can be tapped, clicked, or
   picked with the arrows / stick and confirmed, and Tallow goes straight there: he blows himself out and that
   room's candles relight him (0.36 s). Only from a quiet room, only to a room walked and cleared, onto the free
   floor cell nearest the middle, and the seeded RNG is not touched, so a house is the same whether or not you
   hop. Rooms he can go to wear a gold foot on the map; a line under the legend says how (or why not). A one-time
   hint teaches it the first time he walks back into a cleared room.
3. **Litters** (`world.RUNTS`, `LITTER`, `FOLLOWERS`, `Enemy.runt`): in the Cellar a small lodger (Coal-Bin
   Shambler, Larder Thief, Damp Slug) arrives as three runts, and a bigger one (Cistern Slug, zombie, Puddle Lump,
   Bone Lodger) brings two along. A runt takes one ember, its touch is a 2-minute nip (a lodger's is 5), it drops
   half as often, and it feeds Kindling: a streak from room one. The same rule for every slot and seed.
4. **A first launch goes straight in** (`Game.first_night()`, `Title._first_night`): when no slot has ever been
   lit, Light the wick starts Slot 1 at Midnight, four floors. The slot, difficulty and night-length choosers are
   all there from the second night on. (A publisher's reviewer plays a build once; a newcomer was asked three
   questions before seeing a room.)
5. **The bot** hops as a person would (1.2 s for the two taps, `--nohop` turns it off) and, in a fight that drags
   past 12 s, walks round a wall of rocks instead of standing under it (one god run stalled 18 minutes that way).

## The judges

- **`--autotest --pacecheck`** (`scripts/pace_check.gd`, new): 25 probes, exit 1 on a FAIL. The hurry's speed
  (118 px/s = x1.60), none in a fight, gone when a room wakes; the hop's rules (not to an unvisited room, the room
  he stands in, the guardian's room unbeaten, or while a lodger is up), arrival in 9 frames, onto free floor, the
  RNG state equal before and after; the map (a tap, a tap just beside a room, a tap on nothing, the arrows, a
  click); the litters (21 lodgers in 4 Cellar rooms where 2.7.0 had 9, runts on free floor, one ember each, floor 2
  untouched). **25 of 25 PASS.**
- **`--tour --pace`**: the hurry, the map on touch and keys, a hop, a busy room's map, two litter rooms.
- **`FeelProbe`**: every `--playtest` run now also prints map time, hops and one judge line (time not fighting on
  foot).
- **The night dump**: against the 2.7 baseline exactly 10 lines differ, every one a floor-1 `lodgers:` line
  (layouts, guardians, loot and floors 2-4 are byte for byte the same). The baseline file is regenerated.
- **`--feelcheck`**: the 90-degree swing at the hurry was 7 frames (FAIL) until the acceleration scaled with it;
  now 5 (PASS).
- **`--primercheck`** (keys / pad and `--device=touch`): fails 0; "first launches lit straight from Light the
  wick (no choosers): 8"; the first kill comes 24 s after Light the wick.
- Also green: `--checkscripts`, `--checkrooms`, `--movescheck`, `--qacheck`, `--talkcheck`, `--diarycheck`,
  a god run (WIN, no script errors), `--savecycle` (every floor SAME).

## Before and after (the same six seeds, hurry + hops + litters without the followers)

| Measure | 2.7.0 | 2.8 |
|---|---|---|
| Wins | 6 of 6 | 4 of 6 |
| Time fighting | 51.1% | 66.4% |
| Walking between rooms (incl. map time) | 28.3% | 13.0% |
| Walking to pickups | 10.5% | 9.5% |
| A run | 750 s | 531 s |
| Rooms walked back through, per run | 54 | 23 |

Six runs is a small batch: 6/6 against 4/6 is not a proven difference. The melt was left alone: 4 of 6 is closer
to the game's own target (about half) than 6 of 6 was.

## Not done here

- The size of the picture (the room covers about 40% of a 1080p phone screen, about a third of a 720p one, and
  720p / 1440p phones and the Steam Deck get a border): stream `v28/screen`, started and paused.
- "Flag a bug" (a pause-menu button that copies a report code): designed, not built.
- A reviewer's "skip ahead" menu (checkpoints into later floors): considered for the publisher build and left out;
  it needs save-state care that is not worth the risk before a pitch.
