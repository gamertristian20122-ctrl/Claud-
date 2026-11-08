#!/usr/bin/env python3
"""Tests for anime_edit.py. Uses generated footage and a generated song (no real media).

    python3 test_anime_edit.py            # all tests (about a minute)
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
import wave
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import anime_edit as ae  # noqa: E402

BPM, SONG_DUR, DROP_BEAT, FIRST_BEAT = 128.0, 30.0, 24, 0.5
PERIOD = 60.0 / BPM
DROP_T = FIRST_BEAT + DROP_BEAT * PERIOD  # 11.75 s, a downbeat


def make_song(path: Path, sr: int = 22050) -> None:
    """Kick on every beat (accented every 4th), hats off-beat, bass and louder drums after the drop."""
    t = np.arange(int(SONG_DUR * sr)) / sr
    y = np.zeros_like(t)
    rng = np.random.default_rng(1)
    n = int(0.25 * sr)
    tt = np.arange(n) / sr
    kick = np.sin(2 * np.pi * np.cumsum(50 + 110 * np.exp(-tt * 30)) / sr) * np.exp(-tt * 12)
    for i, bt in enumerate(np.arange(FIRST_BEAT, SONG_DUR - 0.3, PERIOD)):
        loud = bt >= DROP_T - 1e-6
        amp = (0.9 if loud else 0.22) * (1.0 if i % 4 == 0 else 0.6)
        s = int(bt * sr)
        m = min(n, len(y) - s)
        y[s:s + m] += amp * kick[:m]
        s2 = int((bt + PERIOD / 2) * sr)
        m2 = max(0, min(int(0.05 * sr), len(y) - s2))
        y[s2:s2 + m2] += (0.25 if loud else 0.08) * rng.standard_normal(m2) * np.exp(-np.arange(m2) / sr * 60)
    y += (t >= DROP_T) * 0.2 * np.sin(2 * np.pi * 55 * t)
    pcm = (np.clip(y / np.abs(y).max() * 0.9, -1, 1) * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


SOURCES = [
    "testsrc2=size={s}:rate=24",
    "mandelbrot=size={s}:rate=24",
    "life=size={s}:rate=24:mold=10:ratio=0.4:death_color=#203060:life_color=#f0e0a0",
    "testsrc2=size={s}:rate=24,hue=h=t*120,negate",
    "cellauto=size={s}:rate=24:rule=110,eq=gamma=1.5",
]


def make_clip(path: Path, size: str, lengths: list[float]) -> None:
    """A fake 'episode': several moving test patterns joined with hard cuts."""
    ins, parts = [], []
    for i, ln in enumerate(lengths):
        ins += ["-f", "lavfi", "-i", SOURCES[i % len(SOURCES)].format(s=size)]
        parts.append(f"[{i}:v]trim=duration={ln},setpts=PTS-STARTPTS,format=yuv420p[v{i}]")
    fc = ";".join(parts) + ";" + "".join(f"[v{i}]" for i in range(len(lengths))) + f"concat=n={len(lengths)}:v=1:a=0[out]"
    subprocess.run(["ffmpeg", "-y", "-v", "error", *ins, "-filter_complex", fc, "-map", "[out]",
                    "-c:v", "libx264", "-preset", "ultrafast", "-crf", "23", str(path)], check=True)


class Media:
    dir: Path


def setUpModule():
    Media.tmp = tempfile.TemporaryDirectory()
    d = Media.dir = Path(Media.tmp.name)
    make_song(d / "song.wav")
    (d / "clips").mkdir()
    make_clip(d / "clips" / "ep1.mp4", "640x360", [2.0, 2.5, 2.5, 3.0])
    make_clip(d / "clips" / "ep2.mp4", "1280x720", [3.0, 2.0, 3.5, 2.5, 3.0])
    make_clip(d / "clips" / "phone.mp4", "360x640", [2.5, 3.0])


def tearDownModule():
    Media.tmp.cleanup()


class SongTests(unittest.TestCase):
    def test_tempo_beats_and_drop(self):
        s = ae.analyze_song(Media.dir / "song.wav", length=10, song_start=None)
        self.assertAlmostEqual(s["bpm"], BPM, delta=2.0)
        self.assertIsNotNone(s["drop"], "the drop should be found")
        self.assertAlmostEqual(s["start"] + s["drop"], DROP_T, delta=PERIOD * 1.1)
        # beats fall on the real grid
        abs_beats = np.array(s["beats"]) + s["start"]
        err = np.abs(((abs_beats - FIRST_BEAT) / PERIOD) - np.round((abs_beats - FIRST_BEAT) / PERIOD)) * PERIOD
        self.assertLess(float(np.median(err)), 0.03)
        # the edit starts on a downbeat of the real song
        self.assertEqual(round((s["start"] - FIRST_BEAT) / PERIOD) % 4, 0)
        self.assertTrue(8 <= s["duration"] <= 12)
        self.assertEqual(s["beats"][0], 0.0)

    def test_song_start_is_respected(self):
        s = ae.analyze_song(Media.dir / "song.wav", length=6, song_start=20.0)
        self.assertAlmostEqual(s["start"], 20.0, delta=PERIOD)

    def test_bad_song_start(self):
        with self.assertRaises(ae.EditError):
            ae.analyze_song(Media.dir / "song.wav", length=6, song_start=99.0)


class ShotTests(unittest.TestCase):
    def test_cuts_found_where_they_are(self):
        shots = ae.shot_stats(ae.decode_small(Media.dir / "clips" / "ep1.mp4"))
        starts = [s["start"] for s in shots]
        for want in (0.0, 2.0, 4.5, 7.0):
            self.assertLess(min(abs(x - want) for x in starts), 0.2, f"no cut near {want}s: {starts}")
        self.assertLessEqual(len(shots), 6, f"too many false cuts: {starts}")
        for s in shots:
            self.assertTrue(s["start"] <= s["peak"] <= s["end"])
            self.assertEqual(len(s["col"]), ae.AN_W)

    def test_focus_window(self):
        col = [0.0] * 96
        for i in range(70, 80):
            col[i] = 1.0
        f = ae.focus_x(col, 0.32)
        self.assertGreater(f, 0.6)
        self.assertEqual(ae.focus_x(col, 1.0), 0.5)


class PlanTests(unittest.TestCase):
    shots = [{"id": i} for i in range(1, 6)]

    def write(self, obj) -> Path:
        p = Media.dir / "plan_test.json"
        p.write_text(json.dumps(obj))
        return p

    def test_valid_plan(self):
        p = ae.load_plan(self.write({"pool": [1, 2, 3], "hero": 2, "focus": {"3": 0.2}, "title": "GOJO\x07"}), self.shots)
        self.assertEqual(p["pool"], [1, 2, 3])
        self.assertEqual(p["focus"], {3: 0.2})
        self.assertEqual(p["title"], "GOJO")

    def test_rejects_bad_input(self):
        bad = [
            {"pool": [1, 99]}, {"pool": "1,2"}, {"hero": True}, {"hero": 42}, {"focus": {"2": 1.5}},
            {"focus": {"x": 0.5}}, {"title": 5}, {"title_at": "middle"}, {"rm -rf": 1}, [1, 2],
        ]
        for obj in bad:
            with self.assertRaises(ae.EditError, msg=str(obj)):
                ae.load_plan(self.write(obj), self.shots)

    def test_unreadable_plan(self):
        p = Media.dir / "broken.json"
        p.write_text("{not json")
        with self.assertRaises(ae.EditError):
            ae.load_plan(p, self.shots)


class TimelineTests(unittest.TestCase):
    def test_slots_cover_the_song_exactly(self):
        s = ae.analyze_song(Media.dir / "song.wav", length=12, song_start=None)
        for style in ("hype", "smooth"):
            for fps in (24, 30, 60):
                slots = ae.build_slots(s, style, fps)
                self.assertEqual(slots[0]["f0"], 0)
                self.assertEqual(slots[-1]["f1"], round(s["duration"] * fps))
                for a, b in zip(slots, slots[1:]):
                    self.assertEqual(a["f1"], b["f0"])
                self.assertTrue(all(x["f1"] - x["f0"] >= 2 for x in slots))
                kinds = [x["kind"] for x in slots]
                self.assertIn("drop", kinds)
                self.assertEqual(kinds[-1], "outro")
                self.assertEqual(kinds.count("drop"), 1)

    def test_few_shots_never_reuse_the_drop_shot_early(self):
        s = {"beats": [i * 0.4 for i in range(40)], "downbeats": [i % 4 == 0 for i in range(40)],
             "duration": 16.0, "bpm": 150.0, "drop": 4.8}
        slots = ae.build_slots(s, "hype", 30)
        shots = [{"id": i, "clip": 0, "start": i * 3.0, "end": i * 3.0 + 2.5, "peak": i * 3.0 + 1.2,
                  "motion": 0.01 * i} for i in range(1, 9)]  # 8 shots, many more cuts
        items = ae.assign_shots(slots, shots, {})
        self.assertEqual(len(items), len(slots))
        drop = next(it for it in items if it["kind"] == "drop")["shot"]
        before = [it["shot"] for it in items if it["kind"] in ("intro", "ramp")]
        self.assertNotIn(drop, before, "the drop shot was shown before the drop")
        for a, b in zip(items, items[1:]):
            self.assertNotEqual(a["shot"], b["shot"], "same shot twice in a row")
        for it in items:
            sh = next(x for x in shots if x["id"] == it["shot"])
            src_len = (it["f1"] - it["f0"]) / 30 * it["speed"]
            self.assertGreaterEqual(it["src_start"], sh["start"] + ae.MARGIN - 1e-6)
            self.assertLessEqual(it["src_start"] + src_len, sh["end"] - ae.MARGIN + 1e-6)

    def test_no_drop_still_works(self):
        s = {"beats": [i * 0.5 for i in range(24)], "downbeats": [i % 4 == 0 for i in range(24)],
             "duration": 12.0, "bpm": 120.0, "drop": None}
        slots = ae.build_slots(s, "hype", 30)
        self.assertEqual(slots[-1]["f1"], 360)
        self.assertIn("drop", [x["kind"] for x in slots])


def video_info(path: Path) -> dict:
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries",
                          "stream=codec_type,width,height:format=duration", "-of", "json", str(path)],
                         check=True, capture_output=True).stdout
    return json.loads(out)


class EndToEndTests(unittest.TestCase):
    def test_auto_vertical_with_plan_and_title(self):
        work = Media.dir / "work_v"
        data = ae.analyze([str(Media.dir / "clips")], str(Media.dir / "song.wav"), work, 8.0, None,
                          "vertical", 240, quiet=True)
        self.assertTrue((work / "analysis.json").is_file())
        self.assertTrue(all((work / s).is_file() for s in data["sheets"]))
        self.assertGreaterEqual(len(data["shots"]), 8)
        ids = [s["id"] for s in data["shots"]]
        plan = work / "plan.json"
        plan.write_text(json.dumps({"pool": ids[:-1], "hero": ids[0], "exclude": [ids[-1]],
                                    "focus": {str(ids[1]): 0.1}, "title": "TEST EDIT"}))
        edit = ae.render(work, plan, work / "edit.mp4", "hype", "cool", 30, None, None, quiet=True)
        info = video_info(work / "edit.mp4")
        v = next(s for s in info["streams"] if s["codec_type"] == "video")
        self.assertEqual((v["width"], v["height"]), (1080, 1920))
        self.assertTrue(any(s["codec_type"] == "audio" for s in info["streams"]))
        self.assertAlmostEqual(float(info["format"]["duration"]), data["song"]["duration"], delta=0.1)
        self.assertLess(edit["size_mb"], ae.MAX_MB)
        self.assertNotIn(ids[-1], [c["shot"] for c in edit["cuts"]], "excluded shot was used")
        self.assertEqual(edit["title"], "TEST EDIT")
        self.assertTrue((work / "review.jpg").is_file())
        drop_cut = next(c for c in edit["cuts"] if c["kind"] == "drop")
        self.assertEqual(drop_cut["shot"], ids[0])

    def test_cli_auto_wide(self):
        work = Media.dir / "work_w"
        r = subprocess.run([sys.executable, str(Path(ae.__file__)), "auto", "--clips", str(Media.dir / "clips"),
                            "--song", str(Media.dir / "song.wav"), "--work", str(work), "--length", "6",
                            "--format", "wide", "--style", "smooth", "--fps", "24"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        v = next(s for s in video_info(work / "edit.mp4")["streams"] if s["codec_type"] == "video")
        self.assertEqual((v["width"], v["height"]), (1920, 1080))

    def test_big_files_are_shrunk_under_the_limit(self):
        work = Media.dir / "work_small"
        ae.analyze([str(Media.dir / "clips")], str(Media.dir / "song.wav"), work, 4.0, None, "square", 240, quiet=True)
        old = ae.MAX_MB
        ae.MAX_MB = 1.0
        try:
            edit = ae.render(work, None, work / "small.mp4", "smooth", "none", 24, None, None, crf=10, quiet=True)
        finally:
            ae.MAX_MB = old
        self.assertLess(edit["size_mb"], 1.0)
        self.assertFalse((work / "small.tmp.mp4").exists())
        v = next(s for s in video_info(work / "small.mp4")["streams"] if s["codec_type"] == "video")
        self.assertEqual((v["width"], v["height"]), (1080, 1080))

    def test_cli_errors_are_friendly(self):
        r = subprocess.run([sys.executable, str(Path(ae.__file__)), "analyze", "--clips", "/nope",
                            "--song", str(Media.dir / "song.wav"), "--work", str(Media.dir / "w_err")],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 2)
        self.assertIn("error:", r.stderr)
        self.assertNotIn("Traceback", r.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
