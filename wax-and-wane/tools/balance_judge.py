#!/usr/bin/env python3
"""Balance judge for Wax & Wane bot logs (--playtest). Usage: python3 tools/balance_judge.py LOG [LOG...]
(docs/streams/fix_balance.md). The "net" column assumes the base melt (0.25 wax/s), so it ignores relics
and FLOOR_DRAIN: use it to compare floors and builds, not as an exact wax total.

Per run: result line, per-floor diag, the Belfry finish (the ladder print, or a floor-4 win's clock).
Prints: Belfry wins (a floor-4 win, or any run that reached floor 5), true endings, the winners'
finish clocks, how many wins qualified for the tower (Belfry done by 1:00 AM as shown), deaths by
floor, per-floor hits/min and wax flow, Keeper fights."""
import re
import sys
import statistics as st


def mins(h, m, plus=None):
    v = (0 if int(h) == 12 else int(h)) * 60 + int(m)
    if plus:
        v -= int(plus)
    return v


def fmt(v):
    if v < 0:
        return "12:00+%d" % -v
    h, m = divmod(int(v), 60)
    return "%d:%02d" % (12 if h == 0 else h, m)


runs = []
for path in sys.argv[1:]:
    cur_ladder = None
    keeper = []
    for line in open(path, errors="replace"):
        m = re.match(r"\[tower\] ladder of light at (\d+):(\d+) AM(?: \+(\d+) min)?", line)
        if m:
            cur_ladder = mins(*m.groups())
            continue
        m = re.match(r"\[keeper\] (stilled|Tallow fell)", line)
        if m:
            keeper.append(m.group(1))
            continue
        m = re.match(r"\[playtest\] run (\d+): (WIN|LOSS) floor=(\d+) clock=(\d+):(\d+) AM(?: \+(\d+) min)? kills=(\d+) rooms=(\d+) time=(\d+)s relics=\[(.*)\]", line)
        if m:
            g = m.groups()
            r = dict(file=path, n=int(g[0]), win=g[1] == "WIN", floor=int(g[2]), clock=mins(g[3], g[4], g[5]),
                     kills=int(g[6]), rooms=int(g[7]), time=int(g[8]), relics=len([x for x in g[9].split(",") if x.strip()]),
                     ladder=cur_ladder, keeper=keeper, floors=[])
            runs.append(r)
            cur_ladder = None
            keeper = []
            continue
        if line.startswith("[diag]    f1 ") and runs:
            for fm in re.finditer(r"f(\d) (\d+)s hits (\d+) lost (\d+) gained (\d+)", line):
                runs[-1]["floors"].append(tuple(int(x) for x in fm.groups()))

if not runs:
    print("no runs")
    sys.exit(0)
n = len(runs)
belfry = [r for r in runs if (r["win"] and r["floor"] == 4) or r["floor"] == 5]
true_end = [r for r in runs if r["win"] and r["floor"] == 5]
print("runs %d   Belfry wins %d (%.0f%%)   true endings %d   tower deaths %d" % (
    n, len(belfry), 100.0 * len(belfry) / n, len(true_end), sum(1 for r in runs if r["floor"] == 5 and not r["win"])))
fin = []
qual = 0
for r in belfry:
    if r["floor"] == 4:
        t = r["clock"]
    elif r["ladder"] is not None:
        t = r["ladder"]
    else:
        t = None   # an old build's tower run: the Belfry fell by 1:00 AM, time unknown
    fin.append(t)
    if r["floor"] == 5 or (t is not None and t <= 60):
        qual += 1
known = [t for t in fin if t is not None]
print("Belfry finish (clock): %s" % ", ".join(fmt(t) if t is not None else "<=1:00" for t in fin))
if known:
    print("  median of known %s   (%d of %d known)" % (fmt(st.median(known)), len(known), len(fin)))
wins_final = sorted(r["clock"] for r in runs if r["win"])
if wins_final:
    print("final clock of WIN lines (critic's metric): %s  median %s" % (", ".join(fmt(t) for t in wins_final), fmt(st.median(wins_final))))
if belfry:
    print("qualified for the tower (Belfry by 1:00 AM shown): %d of %d wins (%.0f%%)" % (qual, len(belfry), 100.0 * qual / len(belfry)))
deaths = {}
for r in runs:
    if not r["win"] and r["floor"] != 5:
        deaths[r["floor"]] = deaths.get(r["floor"], 0) + 1
print("deaths by floor (not counting the tower): %s" % dict(sorted(deaths.items())))
for f in (2, 3, 4):
    entered = sum(1 for r in runs if r["floor"] >= f)
    died = deaths.get(f, 0)
    if entered:
        print("  floor %d: entered %d, died there %d (%.0f%% got through)" % (f, entered, died, 100.0 * (entered - died) / entered))
agg = {}
for r in runs:
    for f, secs, hits, lost, gained in r["floors"]:
        a = agg.setdefault(f, [0, 0, 0, 0, 0])
        a[0] += secs; a[1] += hits; a[2] += lost; a[3] += gained; a[4] += 1
for f in sorted(agg):
    s, h, lo, g, k = agg[f]
    drain = 0.25 * s
    print("floor %d: visits %2d  mean %3.0f s  hits/min %.2f  per visit: lost %5.1f gained %5.1f drain~%5.1f net %+6.1f" % (
        f, k, s / k, 60.0 * h / max(1, s), lo / k, g / k, drain / k, (g - lo - drain) / k))
kf = [x for r in runs for x in r["keeper"]]
if kf:
    print("Keeper fights: %d stilled, %d lost" % (kf.count("stilled"), kf.count("Tallow fell")))
print("relics at the end (wins): %s" % sorted(r["relics"] for r in runs if r["win"]))
