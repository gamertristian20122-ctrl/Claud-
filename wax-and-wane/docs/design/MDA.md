# Wax & Wane: what it should feel like, and what the data says

A working note for the design pass (v1.9.1 -> next). MDA = mechanics (the rules) -> dynamics (what
play does with them) -> aesthetics (what the player feels). Every claim below is backed by a number
from the bot (`--playtest --speed=4`, 12 runs on seeds 8101-8104, 8201-8204, 8301-8304, summed by
`tools/design_playtest_summary.py`) or by a measuring script; the bot is not a human, so read its
numbers as pressure gauges, not as how a person plays.

## The three feelings we want

| Aesthetic | Dynamics that should make it | Mechanics that serve it | Mechanics that fight it |
|---|---|---|---|
| **Dread of the clock** - the night is running out | wax burns every second, every hit is minutes lost, the bar and the clock tick together | Wax = health = clock; 8-minute candle; low-wax vignette and red clock; Guttering | Wax income outgrows the burn once a run is strong: the 8 wins ended at a **median 12:21 AM, 99 of 120 minutes still in the candle** (floors 3-4 gain 1.5-3x the wax they lose). The dread is gone after floor 2. |
| **Warmth of the light** - a small flame against a big dark house | the candle's light is safety, the dark is where things are; your shots light the floor | light radius shrinks with wax; ember lights; unshaded bullets and telegraphs | Threats you can't read on the lit floor. Before this pass the most common enemy bullet (purple orb, 6 shooters) measured **1.6:1** against the cellar floor, the red telegraph **1.4:1**. |
| **Greed of trading wax for power** - "is this relic worth twenty minutes?" | Smoke Altar, Cracked Mirror and Wax Font sell power for the clock | permanent "charred" minutes; half the price cut at once | The price was a line of text ("15 max min for good, up to 7 now"); the bar, where the clock lives, did not show it. |

## What the bot felt (before)

- **Bimodal runs.** 8 of 12 won (67%), and comfortably (median finish 12:21 AM). All 4 losses were on
  floors 1-2 (`[2, 2, 2, 1]`). A run either dies early or never feels the clock again.
- **The opening is the hardest minute of the game.** Hits per minute by floor: **f1 4.5**, f2 4.6,
  f3 3.2, f4 2.0, f5 1.1. Floor 1 cost a median **10 hits** (6-18) in its ~2.5 minutes; one run
  died there. The first rooms could be 4-6 lodgers on pit/spike/choke layouts, rats at 92 px/s
  against Tallow's 74.
- **What hits.** Most blows are shots (64 shot hits in the 4 runs that logged origins) from a mean
  **50 px** away: only **1 of 64** came from beyond the candle's light, 7 from beyond half of it. So the
  problem is reading bullets on the floor, not bullets from the dark: no off-screen / edge damage
  flash was added. Hazards are the other big source: spikes (up to 13 in a run), hearths (up to 12)
  and the bot's own bombs (5) - the bot ignores hazards, a human mostly won't.
- **Feel probes** (`--designcheck --latency`, physics frames at 60 Hz): first shot and hit feedback
  were already instant (1 frame / same frame), but a quick fire tap during the 0.42 s recharge was
  **eaten**, a 5 px flick of the touch aim stick **never fired** (it needed 6.6 px), and turning
  back from a full run took **7 frames (117 ms)** to show, past the 100 ms a dodge needs.

## The three biggest problems (first five minutes and the core loop)

1. **The first five minutes punish instead of teach** (flow channel: challenge above skill before
   the player has any). Fix: the floor-1 opening (below) plus the input fixes.
2. **Deaths that don't read as fair**: low-contrast bullets and telegraphs on the lit floor, and
   inputs that get lost (eaten taps, dead flick, slow turn). Fix: contrast + input feel.
3. **The core trade is read, not felt**: the clock's price shows as text, never on the clock.
   Fix: the price on the wax bar. (The late-game clock losing its teeth is problem 3's bigger
   sibling, but it is a balance knob - wax income - and belongs to the balance pass.)

Plus one for relatedness (socializers): a run had no way to leave the game. Fix: Share.

## What changed, and the judges

| # | Change | Judge | Before | After |
|---|---|---|---|---|
| 2 | Fire buffer (0.2 s), turn-back accel 2600, 4 px aim flick | `--designcheck --latency` (frames) | tap in recharge: eaten; 5 px flick: never; reverse: 7; first shot 1; hit flash/sound 0 | tap: fires when ready (10); flick: 1; reverse: 3; first shot 1; hit 0 |
| 3 | Hot cores on orbs / wax bolt, gold cog, hot partner dot on red & pink telegraphs | `tools/design_contrast.py` (WCAG ratio vs each floor's lit floor) | 7 of 11 below 3:1, worst 1.37 | 0 of 11 below 3:1, worst 3.27 |
| 4 | The price on the wax bar (marching red = cut now, soot = charred for good) | `tools/design_ghost_check.py` (pixels counted in a tour shot vs the game's numbers) | no preview | altar @90: 8/8 px + 16/16 px; altar @118: 14/14 px (+16 under the cut); font: 4/4 px |
| 5 | Share button (results) | `--designcheck --share` + clipboard read-back | none | 4 cases 75-99 chars (<= 104 as X counts), seed/date present, identical twice; clipboard holds it |
| 6 | Floor-1 opening: easy layouts within 2 rooms, first two fought = 2-3 slow lodgers, treasure within 3 | `--designcheck --floors` (20 layouts) | easy 12/72, 2-3 slots 23/72, treasure <=3: 20/20 | easy 72/72, 2-3 slots 72/72, slow pool (17-26 px/s), treasure <=3: 20/20 |

### Re-measured playtests (same 12 seeds)

Same 12 seeds, same bot, `--speed=4`. The seeds give the same houses, but a run's fights (and from
this pass on, floor 1's room picks) differ, so treat a change of one or two runs as noise.

| Measure | Before | After |
|---|---|---|
| Wins | 8 / 12 (67%) | 7 / 12 (58%) |
| Median finish clock of the wins | 12:21 AM (21 of 120 min used) | 12:44 AM (44 min used) |
| Floor-1 hits, median / mean | 10 / 11.0 | **8 / 7.9** |
| Floor-1 wax lost, median | 58 min | **42 min** |
| Hits per minute f1 / f2 / f3 / f4 / f5 | **4.5** / 4.6 / 3.2 / 2.0 / 1.1 | **3.4** / 4.0 / 2.4 / 1.3 / 1.0 |
| Deaths on floor 1 | 1 | 0 |
| Losses on floors | 2, 2, 2, 1 | 2, 2, 3, 2, 3 |
| Shot hits from beyond the candle's light | 1 of 64 (4 runs logged) | 1 of 175 (12 runs) |

What it means: floor 1 now ramps (3.4 hits/min, below floor 2's 4.0) instead of being the worst
minute of the night, and the room log confirms the order the bot met: the first two rooms held only
wax blobs, slugs, tiny slugs and tiny zombies in all 12 runs, the third and fourth the usual crowd
(goblins, rats, skelets, muddies), then the guardian. The win rate moved by one run (noise at this
size; the balance pass owns it). Winners now finish later (12:44 AM): fewer floor-1 lodgers means
less wax won back on floor 1 (median 60 -> 44 min gained), so the clock keeps a little more of its
bite; it is still far from the 1:30-1:50 AM a tense finish would want. Shots still almost never come
from outside the light (1 of 175), which is why no off-screen damage flash was added.

## Left for the balance pass
- Wax income vs burn after floor 2 (median win 12:21 AM): the clock should still bite on floors 3-4.
- Hazards the bot walks into (spikes, hearths, its own bombs) inflate its hit counts; a human-like
  bot would make the hit numbers more honest.
- The floor banner's dark band covers the right end of the wax bar for ~2.4 s at each floor start
  (seen in the ghost-check shots); harmless at full wax, but it hides the charred end.
