#!/usr/bin/env python3
"""Sum up --playtest logs for the design pass (docs/design/MDA.md):

    python3 tools/design_playtest_summary.py run_a.log run_b.log ...

Per run: result, floor, finish clock, floor-1 seconds / hits / wax lost, and the hit sources. Overall:
win rate, median finish clock of the wins, floor-1 hits (median, mean), floor-1 hits per minute
against later floors, where losses happened, and how far shots came from (the [diag] shot line).
"""
import re
import statistics
import sys

RUN = re.compile(r"\[playtest\] run \d+: (WIN|LOSS) floor=(\d+) clock=(\d+):(\d+) (AM|PM) kills=(\d+) rooms=(\d+) time=(\d+)s")
FLOOR = re.compile(r"f(\d+) (\d+)s hits (\d+) lost (\d+) gained (\d+)")
SHOTS = re.compile(r"shot hits (\d+): from beyond half the light (\d+), beyond the light (\d+), mean distance (\d+) px")


def minutes(h, m):
    h = int(h) % 12
    return h * 60 + int(m)


def main():
    runs = []
    for path in sys.argv[1:]:
        cur = None
        for line in open(path, errors="replace"):
            m = RUN.search(line)
            if m:
                cur = {"won": m.group(1) == "WIN", "floor": int(m.group(2)), "clock": minutes(m.group(3), m.group(4)),
                       "rooms": int(m.group(7)), "time": int(m.group(8)), "floors": {}, "shots": None, "src": ""}
                runs.append(cur)
                continue
            if cur is None:
                continue
            if "[diag]" in line and "hits" in line and " f1 " in line or (line.startswith("[diag]") and FLOOR.search(line) and not cur["floors"]):
                for f in FLOOR.finditer(line):
                    cur["floors"][int(f.group(1))] = [int(f.group(i)) for i in range(2, 6)]
            elif "hit by" in line:
                cur["src"] = line.split("hit by", 1)[1].strip()
            else:
                s = SHOTS.search(line)
                if s:
                    cur["shots"] = [int(s.group(i)) for i in range(1, 5)]
    if not runs:
        print("no runs")
        return
    for i, r in enumerate(runs, 1):
        f1 = r["floors"].get(1, [0, 0, 0, 0])
        print("run %2d %-4s floor %d clock %s  f1: %3ds %2d hits, -%d wax  | %s" % (
            i, "WIN" if r["won"] else "LOSS", r["floor"], "%d:%02d" % (r["clock"] // 60 or 12, r["clock"] % 60),
            f1[0], f1[1], f1[2], r["src"][:110]))
    wins = [r for r in runs if r["won"]]
    f1h = [r["floors"].get(1, [0, 0])[1] for r in runs]
    f1t = [r["floors"].get(1, [0, 0])[0] for r in runs]
    rate = {}
    for r in runs:
        for f, d in r["floors"].items():
            t, h = rate.get(f, [0, 0])
            rate[f] = [t + d[0], h + d[1]]
    print("runs %d, wins %d (%.0f%%)" % (len(runs), len(wins), 100.0 * len(wins) / len(runs)))
    if wins:
        med = statistics.median([w["clock"] for w in wins])
        print("median finish clock of the wins: %d:%02d AM (%d min of wax used of 120)" % (int(med) // 60 or 12, int(med) % 60, med))
    print("floor-1 hits: median %.1f, mean %.1f (%s); floor-1 time median %ds" % (
        statistics.median(f1h), statistics.mean(f1h), f1h, statistics.median(f1t)))
    print("hits per minute by floor: " + ", ".join("f%d %.1f" % (f, 60.0 * h / max(1, t)) for f, (t, h) in sorted(rate.items())))
    losses = [r["floor"] for r in runs if not r["won"]]
    print("losses on floors: %s" % losses)
    sh = [r["shots"] for r in runs if r["shots"]]
    if sh:
        tot = sum(s[0] for s in sh)
        print("shot hits %d: from beyond half the light %d, beyond the light %d" % (tot, sum(s[1] for s in sh), sum(s[2] for s in sh)))


if __name__ == "__main__":
    main()
