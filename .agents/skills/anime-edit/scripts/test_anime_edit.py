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
import fx  # noqa: E402

BPM, SONG_DUR, DROP_BEAT, FIRST_BEAT = 128.0, 30.0, 24, 0.5
PERIOD = 60.0 / BPM
DROP_T = FIRST_BEAT + DROP_BEAT * PERIOD  # 11.75 s, a downbeat


def make_song(path: Path, sr: int = 22050, first_beat: float = FIRST_BEAT) -> None:
    """Kick on every beat (accented every 4th), hats off-beat, bass and louder drums after the drop."""
    t = np.arange(int(SONG_DUR * sr)) / sr
    y = np.zeros_like(t)
    rng = np.random.default_rng(1)
    n = int(0.25 * sr)
    tt = np.arange(n) / sr
    kick = np.sin(2 * np.pi * np.cumsum(50 + 110 * np.exp(-tt * 30)) / sr) * np.exp(-tt * 12)
    for i, bt in enumerate(np.arange(first_beat, SONG_DUR - 0.3, PERIOD)):
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

    def test_first_beat_right_after_start_is_not_a_tiny_cut(self):
        p = Media.dir / "early.wav"
        make_song(p, first_beat=0.1)
        s = ae.analyze_song(p, length=8, song_start=0.0)
        self.assertEqual(s["beats"][0], 0.0)
        self.assertGreater(s["beats"][1] - s["beats"][0], 0.5 * PERIOD)

    def test_whole_song_plays_to_the_end(self):
        s = ae.analyze_song(Media.dir / "song.wav", length=SONG_DUR, song_start=0.0)
        self.assertAlmostEqual(s["start"] + s["duration"], s["total"], delta=0.02)

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

    def test_v2_plan_keys(self):
        p = ae.load_plan(self.write({
            "lyrics": [{"text": "MAHORAGA GOT ME A TABLET!", "start": 0.0, "end": 2.0, "times": [0, 0.9, 1.1, 1.3, 1.5]},
                       {"text": "NO TIMES GIVEN", "start": 2.0, "end": 3.0}],
            "captions": {"2": "HOLLOW PURPLE"}, "transitions": {"3": "spin"}, "accent": "#A970ff"}), self.shots)
        self.assertEqual(p["lyrics"][0]["words"][4], (1.5, "TABLET!"))
        self.assertEqual(len(p["lyrics"][1]["words"]), 3)
        self.assertEqual(p["captions"], {2: "HOLLOW PURPLE"})
        self.assertEqual(p["transitions"], {3: "spin"})
        self.assertEqual(p["accent"], (169, 112, 255))

    def test_rejects_bad_v2_input(self):
        bad = [
            {"lyrics": "words"}, {"lyrics": [{"text": "A B", "start": 2, "end": 1}]},
            {"lyrics": [{"text": "A B", "start": 0, "end": 1, "times": [0.1]}]},
            {"lyrics": [{"text": "A", "start": 0, "end": 1, "times": [5]}]}, {"lyrics": [{"start": 0, "end": 1}]},
            {"captions": {"99": "X"}}, {"captions": {"2": 7}}, {"transitions": {"0": "spin"}},
            {"transitions": {"2": "explode"}}, {"accent": "purple"}, {"accent": "#12345g"},
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


class FxTests(unittest.TestCase):
    def test_speed_ramps(self):
        n, fps = 60, 60
        const = fx.remap_times(("const", 1.0), n, fps)
        self.assertEqual(len(const), n + 1)
        self.assertAlmostEqual(const[-1], 1.0, places=6)
        vel = fx.remap_times(("velocity", 0.4, 2.4), n, fps)
        self.assertTrue(np.all(np.diff(vel) > 0), "time must always move forward")
        self.assertAlmostEqual(vel[-1], 0.4 + 2.0 / 2, places=2)  # average speed of lo + (hi-lo) sin^2
        first, mid = vel[1] - vel[0], vel[31] - vel[30]
        self.assertGreater(mid, 3 * first, "slow on the beat, fast in between")
        self.assertAlmostEqual(fx.remap_times(("const", 1.0), n, fps, 0.5)[-1], 0.5, places=6)
        dec = fx.remap_times(("decel", 1.4, 0.3), n, fps)
        self.assertGreater(dec[1] - dec[0], 3 * (dec[-1] - dec[-2]), "slows down into the drop")

    def test_cover_zoom_keeps_the_frame_filled(self):
        base_wh, out_wh = (1210, 2150), (1080, 1920)
        for rot, tx, ty in ((0, 0, 0), (4.5, 30, -20), (-3, -60, 10)):
            z = fx.cover_zoom(rot, tx, ty, base_wh, out_wh)
            m = fx.cam_matrix({"z": z, "rot": rot, "tx": tx, "ty": ty}, base_wh, out_wh)
            for u, v in ((0, 0), (1080, 0), (0, 1920), (1080, 1920)):
                x, y = m @ np.array([u, v, 1.0])
                self.assertTrue(-1 <= x <= base_wh[0] + 1 and -1 <= y <= base_wh[1] + 1, (rot, tx, ty, x, y))

    def test_shoot_motion_blur_and_identity(self):
        base = np.random.default_rng(0).integers(0, 255, (224, 128, 3), dtype=np.uint8)
        still = fx.shoot(base, lambda t: {"z": 1.0, "rot": 0.0, "tx": 0.0, "ty": 0.0}, 0.1, 60, (112, 200))
        self.assertTrue(np.array_equal(still, base[12:212, 8:120]))
        moving = fx.shoot(base, lambda t: {"z": 1.2, "rot": 0.0, "tx": 3000 * t, "ty": 0.0}, 0.1, 60, (112, 200))
        self.assertEqual(moving.shape, (200, 112, 3))
        self.assertLess(moving.std(), base.std() * 0.8, "fast pans are motion-blurred")

    def test_glitch_and_looks(self):
        img = np.random.default_rng(1).integers(0, 255, (320, 180, 3), dtype=np.uint8)
        self.assertIs(fx.glitch(img, 0.0, 5), img)
        a, b = fx.glitch(img, 0.9, 5), fx.glitch(img, 0.9, 5)
        self.assertTrue(np.array_equal(a, b), "same seed, same glitch")
        self.assertFalse(np.array_equal(a, img))
        self.assertEqual(fx.flash_dark(img, 1.0, 0.0).min(), 255)
        self.assertEqual(fx.flash_dark(img, 0.0, 1.0).max(), 0)
        self.assertEqual(fx.bloom(img, 0.5).shape, img.shape)
        g = fx.Grain(180, 320)
        self.assertEqual(g.apply(img).shape, img.shape)

    def test_kinetic_text(self):
        kt = fx.KineticText((540, 960))
        lyr = [{"start": 1.0, "end": 2.0, "words": [(1.0, "GOT"), (1.5, "ME")]}]
        blank = np.zeros((960, 540, 3), np.uint8)
        self.assertEqual(kt.draw_lyrics(blank.copy(), lyr, 0.5).max(), 0, "nothing before the line")
        one = kt.draw_lyrics(blank.copy(), lyr, 1.3)
        two = kt.draw_lyrics(blank.copy(), lyr, 1.8)
        self.assertGreater(one.max(), 0)
        self.assertGreater((two > 0).sum(), (one > 0).sum(), "second word popped in")
        self.assertEqual(kt.draw_lyrics(blank.copy(), lyr, 2.5).max(), 0, "line gone after its end")
        cap = kt.draw_caption(blank.copy(), "HOLLOW PURPLE", 0.2, 1.0)
        self.assertGreater(cap.max(), 0)


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
                                    "focus": {str(ids[1]): 0.1}, "title": "TEST EDIT",
                                    "lyrics": [{"text": "ONE TWO THREE", "start": 0.2, "end": 2.0}],
                                    "captions": {str(ids[0]): "DROP"}, "transitions": {"2": "spin"},
                                    "accent": "#a970ff"}))
        edit = ae.render(work, plan, work / "edit.mp4", "hype", "purple", None, None, None, quiet=True)
        self.assertEqual(edit["fps"], 30, "24 fps test clips -> 30 fps output")
        self.assertEqual(edit["cuts"][1]["entry"], "spin")
        self.assertEqual(next(c for c in edit["cuts"] if c["kind"] == "drop")["entry"], "glitch")
        for c in edit["cuts"]:
            self.assertIn(c["move"], ("push", "push_fast", "punch", "pull", "tilt", "drift"))
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

    def test_switch_song_without_rescanning(self):
        work = Media.dir / "work_song"
        ae.analyze([str(Media.dir / "clips")], str(Media.dir / "song.wav"), work, 6.0, None, "vertical", 240, quiet=True)
        before = json.loads((work / "analysis.json").read_text())
        ae.change_song(work, str(Media.dir / "song.wav"), 10.0, 1.0)
        after = json.loads((work / "analysis.json").read_text())
        self.assertEqual(before["shots"], after["shots"])
        self.assertAlmostEqual(after["song"]["start"], 1.0, delta=PERIOD)
        self.assertGreater(after["song"]["duration"], before["song"]["duration"])

    def test_lyrics_timing_with_mocked_whisper(self):
        import types
        work = Media.dir / "work_song"
        if not (work / "analysis.json").exists():
            ae.analyze([str(Media.dir / "clips")], str(Media.dir / "song.wav"), work, 6.0, None, "vertical", 240, quiet=True)
        W = types.SimpleNamespace
        seg = W(start=0.5, end=1.6, words=[W(start=0.5, word=" got"), W(start=0.9, word=" me"), W(start=1.2, word=" a")])

        class FakeModel:
            def __init__(self, *a, **k):
                pass

            def transcribe(self, audio, **k):
                assert audio.dtype == np.float32 and len(audio) > 16000
                return iter([seg]), None

        fake = types.ModuleType("faster_whisper")
        fake.WhisperModel = FakeModel
        old = sys.modules.get("faster_whisper")
        sys.modules["faster_whisper"] = fake
        try:
            lines = ae.time_lyrics(work, "tiny", "en")
        finally:
            if old is None:
                del sys.modules["faster_whisper"]
            else:
                sys.modules["faster_whisper"] = old
        self.assertEqual(lines[0]["text"], "GOT ME A")
        self.assertEqual(lines[0]["times"], [0.5, 0.9, 1.2])
        self.assertEqual(len(ae.check_lyrics(json.loads((work / "lyrics.json").read_text()))), 1)

    def test_cli_errors_are_friendly(self):
        r = subprocess.run([sys.executable, str(Path(ae.__file__)), "analyze", "--clips", "/nope",
                            "--song", str(Media.dir / "song.wav"), "--work", str(Media.dir / "w_err")],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 2)
        self.assertIn("error:", r.stderr)
        self.assertNotIn("Traceback", r.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
