# v2.9: the clock (a tall candle burns fast)

The game's hook is "wax = health = clock". 2.8.0 left a note that the clock had stopped mattering: the test
bot won 16 of 18 nights at Midnight (the target is about half) and a winning night ended with an hour of wax
to spare. This pass measured why, changed one rule, and judged it on the same houses.

## The instrument: a wax ledger

`world.ledger` counts where the candle's minutes go. Every headless debug run now prints one line at the end
of a night (`world._end_run`):

```
[wax] end=80 melt=216 (tall 76) hit=191 heal=419 | knee 0.50 hot [0.5, 1.5, 2, 2, 2] x1.0 | floors 1:0s=120 2:134s=155 3:295s=49 4:403s=71
```

- `end`: the wax when the night ended. `melt`: what the clock took, and in brackets how much of that was for
  standing tall. `hit`: what blows took. `heal`: what kills, clears, drips, rooms and items gave back.
- `floors`: `floor:seconds=wax` on reaching each floor.

## What the ledger showed (2.8 burn: `--tallhot=0`, seeds 21-26, Midnight, fresh profiles)

| | per winning night |
|---|---|
| the melt took | 131 to 182 wax |
| hits took | 97 to 140 wax |
| won back | 268 to 360 wax |
| wax on reaching floors 2 / 3 / 4, and at the end | about 101 / 102 / 101, and 98 of 120 |

Kills, clears and drips pay back about twice what the melt takes. The candle stood near full all night, so the
clock read 12:00 to 12:39 AM at the win (12:21 on average), every win beat the Clock Tower's 1:00 AM line, and
5 nights in 6 were won. The melt was never the thing that ran out: a faucet much bigger than the sink.

## The rule

Wax above half the night's candle melts faster, in a straight line from x1 at the half mark to
x(1 + `TALL_HOT[floor]`) at a full candle (`world.tall_k`, in the melt line of `_physics_process`).

- `TALL_KNEE` 0.5: half the night's minutes (60 of 120; 105 of 210 on a 7-floor night). It is the wider notch
  that was already on the wax bar, and the Clock Tower's line. One mark, two meanings that pull against each
  other: stay above it for the Tower, and above it you burn fast.
- `TALL_HOT` `[0.5, 1.5, 2.0, 2.0, 2.0]` per floor, like `FLOOR_DRAIN`: x1.5 at a full candle in the Cellar,
  x2.5 in the Crypt, x3 above. The full candle a night starts with is health, not a hoard, so the first floor
  stays nearly as gentle as it was.
- `TALL_OVER` 1.25: a candle that holds more than the night (a bigger candle, +max wax) goes on a little.
- `LEVELS[n]["tall"]`: Gentle 0.5, the others 1 (missing key = 1).
- Why this and not a faster melt for everyone, or smaller drops: it only taxes a rich run (a thin candle
  burns exactly as it did), the player sees it as the clock running, and it gives spare wax a use: wax you
  cannot keep is wax to spend at an altar, a mirror, a font or on a move.
- On screen (`hud._draw_bar`): the wax past the mark glows, ember dashes run down it toward the mark, and the
  flame at the end of the bar stands twice as high (every row drawn twice, whole pixels). One hint, the first
  time a room is cleared on floor 2 or later with a tall candle: "Tall candle, tall flame: the glowing wax
  melts faster" (`Game.tip("tall_flame")`).

## The judge: the bot on the same 16 houses (seeds 21-36, Midnight, fresh profiles)

| setting | wins | clock at the win (mean) | wins by 1:00 AM |
|---|---|---|---|
| 2.8 burn (6 houses, seeds 21-26) | 5 of 6 | 12:21 AM | 5 of 5 |
| x2 at a full candle on every floor, mark at half | 11 of 16 | 12:54 AM | 7 of 11 |
| **per floor, mark at half (shipped)** | **10 of 16** | **12:56 AM** | 7 of 10 |
| per floor, mark at 0.4 | 13 of 16 | 12:57 AM | 8 of 13 |
| per floor, mark at half, the Belfry's melt x1.45 -> x1.75 | 10 of 16 | 12:56 AM | 8 of 10 |

- All four versions of the rule land in the same place, and the same seeds swing between 10 and 13 wins, so
  16 runs cannot tell them apart. They agree against the old burn: about 7 wins in 10 instead of 9, and the
  winning clock half an hour later. The shipped one is the most readable (one mark) and the gentlest on
  floor 1. The faster Belfry was taken back out: it changed nothing the bot could show.
- Gentle: 7 of 7 (12:15 to 1:30 AM). Witching Hour 1 of 4, Two O'Clock 3 of 4 with the same rule as
  Midnight. A stronger rule on the hard levels (x1.5 and x2) lost 0 of 3 each, all in the Crypt, and was
  dropped.
- A 7-floor night: 2 of 2 with the first version; see the handoff in `CLAUDE.md` for the final build's runs.
- Save & Continue on every floor: the same house each time. `--god` nights reach the end.

## What it did not reach

The aim was wins after 1:15 AM and about 6 wins in 10. The win rate is there (10 of 16 shipped, 44 of 64
across the four versions). The clock is not: 12:56 AM. Two things the ledger makes plain:

- The rule pulls a rich candle down toward the mark and no further. To end later than 1:00 AM the candle has
  to be pushed below it, and that takes less income or more damage, which also hits thin runs.
- No run that reached the Belfry lost: all 20 losses in the 64 nights came in the Crypt or the Chapel. The last
  floor pays the bot more wax than it costs, even with its melt at x1.75. If the end of the night should be
  the hardest part, that is the next thing to look at (what the Belfry's rooms and its guardian pay, and what
  the guardian's hits cost), not the melt.

## Run it again

```
godot --headless --path . -- --autotest --playtest --speed=4 --runs=1 --seed=21            # the shipped rule
godot --headless --path . -- --autotest --playtest --speed=4 --runs=1 --seed=21 --tallhot=0   # the 2.8 candle
... --tallhot=1  (x2 on every floor)   --tallknee=0.4   --difficulty=1..4   --floors=7
```
Give each run its own `XDG_DATA_HOME`, read the `[playtest] run` and `[wax]` lines. The flags only work in a
debug build (the editor binary), never in an exported game.

Also in 2.9: the creature glow shader no longer hands `TEXTURE` to a function (a macro does the same reads),
which removes an engine error that every run logged once per shader build.
