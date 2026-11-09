# Fix stream: balance, endgame & run rules (2.0 review fixes)

Branch `fix/balance`. Findings from the v1.9.3 review (critic, QA, mobile UX): C1, C2, QA-03, the guardian
half of C5, QA-06, QA-08, QA-10, QA-14, QA-15, QA-16 + the Gentle burn half of UX-09, QA-17.
Every fix was checked from outside: a probe that boots the real game (`tools/balance_probe.gd`, run before
and after), bot batches (`tools/balance_judge.py` reads their logs), screenshots.

```
godot --headless --path . --script res://tools/balance_probe.gd -- --check=guardians,continue,daily,gate,gentle,summoner
godot --headless --path . --script res://tools/balance_probe.gd -- --check=keeper --keeper
python3 tools/balance_judge.py bot.log          # Belfry wins, finish clocks, tower share, per-floor wax flow
```

BALANCE_PLACEHOLDER

## Run rules (probe numbers: before -> after)
| ID | What was wrong | Fix | Check (`tools/balance_probe.gd`) |
|---|---|---|---|
| QA-06 | A typed-in seed met a different Belfry guardian once the player had won | `Enemy.pick_boss(..., fixed)`: a seeded run or Tonight's Candle (`Unlocks.fixed`) takes the seed's pick, whatever the win count | 8 seeds x wins 0 / 3 (and as dailies): 5 of 8 changed guardian -> 0 of 8 |
| C5 (guardian half) | Every new player's first final boss was the stock 0x72 Big Demon | `FLOORS[4]["bosses"]` = `["pendulum", "big_demon"]`: until the first win a normal run meets The Great Pendulum (own art); the Hour Fiend joins the rotation after that. The intro no longer names the Hour Fiend | new player's random runs: Belfry guardian big_demon x6 -> pendulum x6; after a win both appear |
| QA-08 | Save & quit + Continue turned an ordinary run into "a seeded run" (results label, fixed relic pool) | the snapshot keeps `seeded` (and the daily date); Continue passes them back with `continued`; `world.setup` takes the saved flag; `Records.from_dict` restores true *or* false | random run continued twice: seeded=true -> false; a typed-in seed stays seeded with the same guardian |
| QA-15 | A Tonight's Candle that crossed midnight was scored, logged and shared under the next day | `world.daily_date` is set when the daily is lit (and survives Continue); `Records.end_run` writes it into the history and the results params (`date`, used by Share) and does the first-try / best / nights bookkeeping under it (`Records.score_night`, sets `params.scored`) | a daily lit 11-07, continued and ended 11-08: history, records, nights list and Share all say 11-07; today's first try stays open; an older night ended late leaves a newer record alone |
| QA-14 | The ladder needed `clock <= 60.001` while the results said "DONE BY 1:00 AM" for 60.0-60.99 | `Tower.ladder_open`: `Game.shown_minute(clock) <= 60` (the same flooring as `Game.clock_text`). Early to Bed uses the helper too (it already matched: floor(m) < 60 is m < 60) | Belfry down at 60.5 / 60.99: refused -> ladder; 61.0 still refused |
| C2 (gate) | The fresh-save bot reached the true ending on its third run (32 minutes of play) | the ladder also needs an earlier win (`records.wins >= 1`): a first win always ends with the normal victory. Results hint: "next night, be done by one" | first win at 12:40: ladder -> no ladder |
| QA-16 + UX-09 | Gentle burn changed nothing until the next run and was unexplained | `world.gentle_mult()` is read every frame (no longer baked into `drain_mult`); Settings shows "Melts 25% slower, right away / Not in Tonight's Candle" next to it | melt 0.2500/s, Gentle on mid-run x1.00 -> x0.75, off again x1.00; daily stays x1.00 |
| QA-10 | Two Hooded Mourners in a locked Seance room could summon forever | `Enemy.SUMMON_BUDGET` = 6 Shamblers per Mourner for life; a spent Mourner stops teleporting and backs away a little slower | two Mourners, Shamblers killed as they come, 120 game s: 116 Shamblers -> 12 |
| QA-03 | Burst damage could still the Keeper straight past its phase gate (phase 3 lasted 0-4 s) | the gate moved into `Enemy._damage`: every hit is clamped to `mem.hp_floor` (`Keeper.hp_floor`), so no burst between two AI ticks skips a phase, and a clamped hit never heals. Phase 3 now has a minimum too (`MIN_PHASE[3]` = 10 s): its floor runs in a straight line from the threshold to zero | 8 hits x 40 in one frame, ten times a second: stilled in phase 1 at once -> phases 6.0 / 8.2 / 10.0 s |

Settings page after the change (480x216): SETTINGS_SHOT_PLACEHOLDER

## For other streams (one-line follow-ups outside my files)
- `journal.gd` ~669: the locked-guardian hint now points the wrong way. It says "Some say the Hour Fiend has a
  heart. Win once to hear it." on the Pendulum; it should go on `big_demon` (e.g. "Some say the Pendulum has a
  master. Win once to meet it.").
- `achievements.gd`: "Before Two: Snuff the Hour Fiend before two." - a first win is now against the Pendulum
  (suggest "Win a night before two.").
- `results.gd` `_daily_score`: its bookkeeping is skipped now (`params.scored`); it can call
  `Records.daily_score(params)` instead of its own copy of the formula, and read `params["date"]`.
- Store copy (`docs/marketing/*`) says "snuff the Hour Fiend before two": a new player's first finale is The
  Great Pendulum now (the Hour Fiend still appears after a win). The store boss-card shot shows the Hour Fiend.
