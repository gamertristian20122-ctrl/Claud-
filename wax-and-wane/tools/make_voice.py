#!/usr/bin/env python3
"""Wax & Wane: the trailer narrator.

Makes the narration (docs/marketing/voice/script.json) with Kokoro TTS (open weights, Apache-2.0) and judges
every line with an outside ear: a speech recogniser (faster-whisper, Whisper small.en) has to hear the script
back almost word for word (word error rate <= 10% per line). Each line is also checked for loudness (-16 LUFS),
clipping (peaks under -1 dB) and a natural pace (2.0 to 3.2 words a second).

Run it with the voice venv (tools/voice_setup.sh makes it once; tools/make_trailer.sh voice/audition call it):

  make_voice.py audition [--voices bm_george,bm_fable,am_michael,af_heart] [--speed 0.92]
        every line in each voice -> build/voice_audition/<voice>/ + scorecard.md + one reel per voice
  make_voice.py make --voice bm_george [--speed 0.92]
        the chosen voice -> docs/marketing/voice/ai_narrator/ (a line that fails is made again, a little
        slower or faster, until it passes); writes judge.json and judge.md next to the files
  make_voice.py check <dir> [--fix]
        judges any folder of recordings with the script's file names, e.g. the owner's own voice in
        docs/marketing/voice/owner/ (any audio type: 01_this_is_tallow.wav, .m4a, .mp3 ...);
        --fix trims the silence at both ends and sets every line to -16 LUFS (writes .wav files)
  make_voice.py mixcheck <video> [<video> ...]
        hears the narration back from finished videos (music and effects included): every line must still
        come through (WER <= 10%); line times come from the <video>.json that tools/trailer_edit.py writes
"""
import argparse
import json
import math
import os
import re
import subprocess
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VOICE_DIR = os.path.join(ROOT, "docs/marketing/voice")
SCRIPT = os.path.join(VOICE_DIR, "script.json")
AI_DIR = os.path.join(VOICE_DIR, "ai_narrator")
AUDITION = os.path.join(ROOT, "build/voice_audition")
EXTS = (".wav", ".flac", ".m4a", ".mp3", ".ogg", ".opus", ".aac", ".mp4")

TARGET_LUFS = -16.0
MAX_PEAK_DB = -1.0
MAX_WER = 0.10
PACE = (2.0, 3.2)
ASR_MODEL = "small.en"
KOKORO_REPO = "hexgrad/Kokoro-82M"


def lines():
    with open(SCRIPT) as f:
        return json.load(f)["lines"]


# ---------------------------------------------------------------- audio helpers

def load(path):
    """Any audio file -> (mono float32, rate). WAV/FLAC through soundfile, the rest through ffmpeg (48 kHz)."""
    import soundfile as sf
    if path.lower().endswith((".wav", ".flac")):
        a, sr = sf.read(path, dtype="float32", always_2d=True)
        return a.mean(1), sr
    out = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", "48000", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(out, np.float32).copy(), 48000


def save(path, a, sr):
    import soundfile as sf
    sf.write(path, np.clip(a, -1.0, 1.0), sr, subtype="PCM_16")


def resample(a, sr, to):
    from scipy.signal import resample_poly
    if sr == to:
        return a
    g = math.gcd(sr, to)
    return resample_poly(a, to // g, sr // g).astype(np.float32)


def frames_db(a, sr, ms=10):
    n = max(1, int(sr * ms / 1000))
    k = len(a) // n
    if k == 0:
        return np.array([-120.0])
    m = a[:k * n].reshape(k, n)
    return 20 * np.log10(np.sqrt((m ** 2).mean(1)) + 1e-9)


def voiced_span(a, sr, floor_db=-45.0):
    """First and last sample of speech (10 ms frames louder than floor_db, relative to the loudest frame)."""
    e = frames_db(a, sr)
    on = np.where(e > max(e.max() + floor_db, -70.0))[0]
    if len(on) == 0:
        return 0, len(a)
    n = int(sr * 0.01)
    return int(on[0] * n), int(min(len(a), (on[-1] + 1) * n))


def trim(a, sr, head=0.06, tail=0.18):
    s0, s1 = voiced_span(a, sr)
    s0 = max(0, s0 - int(head * sr))
    s1 = min(len(a), s1 + int(tail * sr))
    out = a[s0:s1].copy()
    k = min(len(out) // 4, int(0.012 * sr))
    if k > 0:   # no clicks at the cut
        out[:k] *= np.linspace(0, 1, k, dtype=np.float32)
        out[-k:] *= np.linspace(1, 0, k, dtype=np.float32)
    return out


def lufs(a, sr):
    import pyloudnorm as pyln
    pad = np.concatenate([a, np.zeros(int(0.5 * sr), np.float32)])   # the meter needs 400 ms blocks
    return float(pyln.Meter(sr).integrated_loudness(pad.astype(np.float64)))


def peaks(a, sr):
    """(sample peak, true peak) in dBFS; true peak from 4x oversampling (ITU-R BS.1770)."""
    sp = 20 * math.log10(float(np.abs(a).max()) + 1e-9)
    tp = 20 * math.log10(float(np.abs(resample(a, sr, sr * 4)).max()) + 1e-9)
    return sp, tp


def limit(a, sr, ceiling_db=-2.0, look_ms=4.0, release_ms=80.0):
    """A look-ahead peak limiter: only the few sharp peaks are turned down (smoothly), so a line can reach
    -16 LUFS without clipping. Speech from a TTS model has spiky peaks; plain gain would leave it at -17."""
    from scipy.ndimage import minimum_filter1d, uniform_filter1d
    c = 10 ** (ceiling_db / 20.0)
    need = np.minimum(1.0, c / (np.abs(a) + 1e-9))
    L = max(1, int(sr * look_ms / 1000))
    g = minimum_filter1d(need, size=2 * L + 1)
    g = np.minimum(g, uniform_filter1d(g, size=L))   # soften the attack but never above what is needed
    rel = math.exp(-1.0 / (sr * release_ms / 1000.0))
    out = np.empty_like(g)
    cur = 1.0
    for i in range(len(g)):   # release: the gain comes back up slowly
        cur = g[i] if g[i] < cur else g[i] + (cur - g[i]) * rel
        out[i] = cur
    return (a * out).astype(np.float32)


def normalize(a, sr, target=TARGET_LUFS):
    """Gain to the target loudness; the peak limiter keeps the true peak under -1 dB (a few passes)."""
    a = a.astype(np.float32)
    for _ in range(8):
        a = a * 10 ** ((target - lufs(a, sr)) / 20.0)
        if peaks(a, sr)[1] <= MAX_PEAK_DB - 0.2:
            break
        a = limit(a, sr)
    _, tp = peaks(a, sr)
    if tp > MAX_PEAK_DB - 0.1:   # never clip: back off (the line then sits a hair under the target)
        a = a * 10 ** ((MAX_PEAK_DB - 0.15 - tp) / 20.0)
    return a.astype(np.float32)


# ---------------------------------------------------------------- the outside ear

_asr = None


def asr():
    global _asr
    if _asr is None:
        from faster_whisper import WhisperModel
        _asr = WhisperModel(ASR_MODEL, device="cpu", compute_type="int8", cpu_threads=2)
    return _asr


## Words that sound exactly like a word of the script (a recogniser has to guess the spelling): the game's
## title comes back as "Wax and Wayne" as often as "wane". Only true homophones belong here.
HOMOPHONES = {"wayne": "wane", "wain": "wane"}


def norm_words(text):
    from num2words import num2words
    t = text.lower().replace("&", " and ").replace("-", " ").replace("’", "'")
    t = re.sub(r"\d+", lambda m: " " + num2words(int(m.group(0))) + " ", t)
    t = re.sub(r"[^a-z' ]+", " ", t)
    return [HOMOPHONES.get(w.strip("'"), w.strip("'")) for w in t.split() if w.strip("'")]


def wer(ref, hyp):
    r, h = norm_words(ref), norm_words(hyp)
    d = list(range(len(h) + 1))
    for i in range(1, len(r) + 1):
        prev, d[0] = d[0], i
        for j in range(1, len(h) + 1):
            cur = min(d[j] + 1, d[j - 1] + 1, prev + (r[i - 1] != h[j - 1]))
            prev, d[j] = d[j], cur
    return d[len(h)] / max(1, len(r))


def hear(a, sr):
    """What the recogniser hears, and how sure it is (mean log-probability per token; nearer 0 is clearer)."""
    segs, _ = asr().transcribe(resample(a, sr, 16000), language="en", beam_size=5, temperature=0.0,
                               condition_on_previous_text=False, vad_filter=False)
    segs = list(segs)
    text = " ".join(s.text.strip() for s in segs).strip()
    lp = float(np.mean([s.avg_logprob for s in segs])) if segs else -9.0
    return text, lp


def pitch_hz(a, sr):
    """Median voice pitch (a simple autocorrelation tracker over voiced 40 ms frames, 60-400 Hz)."""
    x = resample(a, sr, 16000)
    n, hop = 640, 320
    f0 = []
    for i in range(0, len(x) - n, hop):
        fr = x[i:i + n] * np.hanning(n)
        if np.sqrt((fr ** 2).mean()) < 0.01:
            continue
        ac = np.correlate(fr, fr, "full")[n - 1:]
        lo, hi = 16000 // 400, 16000 // 60
        k = lo + int(np.argmax(ac[lo:hi]))
        if ac[k] > 0.35 * ac[0]:
            f0.append(16000.0 / k)
    return float(np.median(f0)) if f0 else 0.0


def tone(a, sr):
    """Warmth: the spectral centroid and the share of energy above 7 kHz. Natural, warm speech keeps well
    under 3% up there; a TTS voice with a metallic buzz or hiss shows 5-10%."""
    from scipy.signal import welch
    f, p = welch(a, sr, nperseg=1024)
    return {"centroid_hz": round(float((f * p).sum() / p.sum()), 0),
            "hf_pct": round(float(p[f > 7000].sum() / p.sum() * 100), 2)}


def judge(line, a, sr):
    text, lp = hear(a, sr)
    s0, s1 = voiced_span(a, sr)
    speech = max(0.1, (s1 - s0) / sr)
    words = len(norm_words(line["text"]))
    sp, tp = peaks(a, sr)
    r = {"file": line["file"], "text": line["text"], "heard": text, "wer": round(wer(line["text"], text), 3),
         "lufs": round(lufs(a, sr), 2), "peak_db": round(sp, 2), "true_peak_db": round(tp, 2),
         "seconds": round(len(a) / sr, 3), "speech_seconds": round(speech, 3),
         "words_per_sec": round(words / speech, 2), "clarity_logprob": round(lp, 3), "pitch_hz": round(pitch_hz(a, sr), 1)}
    r.update(tone(a, sr))
    fails = []
    if r["wer"] > MAX_WER:
        fails.append("words")
    if abs(r["lufs"] - TARGET_LUFS) > 1.0:
        fails.append("loudness")
    if r["true_peak_db"] > MAX_PEAK_DB + 0.05:
        fails.append("clipping")
    if not PACE[0] <= r["words_per_sec"] <= PACE[1]:
        fails.append("pace")
    r["pass"] = not fails
    r["fails"] = fails
    return r


# ---------------------------------------------------------------- Kokoro

_pipes = {}


def kokoro_say(text, voice, speed, ellipsis_pause=0.45):
    """Kokoro-82M at 24 kHz. Voice ids start with the accent: a = American, b = British. Kokoro reads "..."
    almost without a pause, so a line is spoken in parts there and the parts are joined by a real pause."""
    from kokoro import KPipeline
    lang = voice[0]
    if lang not in _pipes:
        _pipes[lang] = KPipeline(lang_code=lang, repo_id=KOKORO_REPO)
    out = []
    for k, part in enumerate([t.strip() for t in text.split("...") if t.strip()]):
        if k > 0:
            out.append(np.zeros(int(24000 * ellipsis_pause / speed), np.float32))
        said = [np.asarray(audio, np.float32) for _, _, audio in _pipes[lang](part + ("..." if "..." in text and k == 0 else ""), voice=voice, speed=speed)]
        a = np.concatenate(said)
        if k > 0 or "..." in text:
            a = trim(a, 24000, head=0.02, tail=0.06)
        out.append(a)
    return np.concatenate(out), 24000


def make_line(line, voice, speed):
    """One line; script.json may give a line its own pace ("speed": 0.9 = a tenth slower than the voice)."""
    a, sr = kokoro_say(line["text"], voice, speed * float(line.get("speed", 1.0)))
    a = normalize(trim(a, sr), sr)
    return a, sr


def make_passing(line, voice, speed, takes=5):
    """Makes a line, and if the judge fails it, makes it again (Kokoro is deterministic, so a retake needs a
    change): too slow or too fast -> the speed that lands near 2.6 words a second; misheard words -> a
    slightly different speed (a new rhythm), then the name spelled out for the speech model.
    Returns the best take and its verdict."""
    best = None
    sp, text = speed, line["text"]
    for take in range(1, takes + 1):
        a, sr = make_line(dict(line, text=text), voice, round(sp, 3))
        r = judge(line, a, sr)
        r["speed"] = round(sp, 3)
        r["take"] = take
        r["spoken_as"] = text
        print("  %-24s speed %.2f  WER %3.0f%%  %5.1f LUFS  peak %5.1f  %.2f w/s  heard: %s%s" % (
            line["file"], r["speed"], r["wer"] * 100, r["lufs"], r["true_peak_db"], r["words_per_sec"], r["heard"],
            "" if r["pass"] else "   FAIL " + ",".join(r["fails"])), flush=True)
        key = (r["pass"], -r["wer"], -abs(r["words_per_sec"] - 2.6))
        if best is None or key > best[0]:
            best = (key, a, sr, r)
        if r["pass"]:
            break
        if "pace" in r["fails"]:   # just inside the band: a pause that belongs to the line stays in it
            want = PACE[0] + 0.15 if r["words_per_sec"] < PACE[0] else PACE[1] - 0.2
            sp = min(1.2, max(0.75, sp * want / max(0.5, r["words_per_sec"])))
        elif "words" in r["fails"]:
            if take == 1:
                sp = round(sp + 0.05, 3)
            else:
                text = spell_out(line["text"], voice)
                sp = round(sp - 0.03 * (take - 2), 3)
    return best[1], best[2], best[3]


## How the made-up and rare words should sound (misaki phonemes), used for a retake when the speech model
## misheard one: Tallow with a flat "a" as in "tally" (British voices otherwise say a softer "tah").
PRONOUNCE = {"Tallow": {"a": "tˈælO", "b": "tˈælQ"}}


def spell_out(text, voice):
    for word, ph in PRONOUNCE.items():
        text = re.sub(r"\b%s\b" % word, "[%s](/%s/)" % (word, ph[voice[0]]), text)
    return text


# ---------------------------------------------------------------- reports

def table(results, title):
    out = ["### " + title, "",
           "| Line | Heard by Whisper %s | WER | LUFS | True peak | Words/s | Pass |" % ASR_MODEL,
           "|---|---|---:|---:|---:|---:|---|"]
    for r in results:
        out.append("| %s | %s | %.0f%% | %.1f | %.1f dB | %.2f | %s |" % (
            r["text"], r["heard"], r["wer"] * 100, r["lufs"], r["true_peak_db"], r["words_per_sec"],
            "yes" if r["pass"] else "NO (" + ", ".join(r["fails"]) + ")"))
    return "\n".join(out) + "\n"


def summary(results):
    return {"lines": len(results), "passed": sum(r["pass"] for r in results),
            "mean_wer": round(float(np.mean([r["wer"] for r in results])), 3),
            "max_wer": round(float(np.max([r["wer"] for r in results])), 3),
            "mean_clarity_logprob": round(float(np.mean([r["clarity_logprob"] for r in results])), 3),
            "mean_words_per_sec": round(float(np.mean([r["words_per_sec"] for r in results])), 2),
            "median_pitch_hz": round(float(np.median([r["pitch_hz"] for r in results if r["pitch_hz"] > 0] or [0])), 1),
            "centroid_hz": round(float(np.mean([r["centroid_hz"] for r in results])), 0),
            "hf_pct": round(float(np.mean([r["hf_pct"] for r in results])), 2),
            "seconds": round(float(np.sum([r["seconds"] for r in results])), 2)}


def reel(path, clips, sr, gap=0.6):
    z = np.zeros(int(gap * sr), np.float32)
    parts = []
    for c in clips:
        parts += [c, z]
    save(path, np.concatenate(parts), sr)


# ---------------------------------------------------------------- commands

def cmd_audition(args):
    voices = args.voices.split(",")
    os.makedirs(AUDITION, exist_ok=True)
    board = {}
    for v in voices:
        print("[voice] audition", v, flush=True)
        d = os.path.join(AUDITION, v)
        os.makedirs(d, exist_ok=True)
        res, clips = [], []
        for ln in lines():
            a, sr, r = make_passing(ln, v, args.speed)
            save(os.path.join(d, ln["file"]), a, sr)
            res.append(r)
            clips.append(a)
        reel(os.path.join(AUDITION, "reel_%s.wav" % v), clips, 24000)
        board[v] = {"summary": summary(res), "lines": res}
    with open(os.path.join(AUDITION, "scorecard.json"), "w") as f:
        json.dump(board, f, indent=2)
    md = ["# Narrator audition (Kokoro-82M, speed %.2f), judged by Whisper %s" % (args.speed, ASR_MODEL), "",
          "| Voice | Lines passed | Mean WER | Worst WER | Clarity (mean log-prob) | Words/s | Pitch | Brightness (centroid) | Energy > 7 kHz |",
          "|---|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for v in voices:
        s = board[v]["summary"]
        md.append("| %s | %d/%d | %.1f%% | %.0f%% | %.3f | %.2f | %.0f Hz | %.0f Hz | %.1f%% |" % (
            v, s["passed"], s["lines"], s["mean_wer"] * 100, s["max_wer"] * 100, s["mean_clarity_logprob"],
            s["mean_words_per_sec"], s["median_pitch_hz"], s["centroid_hz"], s["hf_pct"]))
    md.append("")
    for v in voices:
        md.append(table(board[v]["lines"], v))
    with open(os.path.join(AUDITION, "scorecard.md"), "w") as f:
        f.write("\n".join(md))
    print("\n".join(md[:3 + len(voices)]))


def cmd_make(args):
    out = args.out
    os.makedirs(out, exist_ok=True)
    print("[voice] making", args.voice, "->", out, flush=True)
    res = []
    for ln in lines():
        a, sr, r = make_passing(ln, args.voice, args.speed)
        save(os.path.join(out, ln["file"]), a, sr)
        res.append(r)
    rep = {"model": "Kokoro-82M (%s), Apache-2.0" % KOKORO_REPO, "voice": args.voice, "speed": args.speed,
           "judge": "faster-whisper %s, WER <= %d%% per line" % (ASR_MODEL, MAX_WER * 100),
           "summary": summary(res), "lines": res}
    write_judge(out, rep)
    bad = [r["file"] for r in res if not r["pass"]]
    if bad:
        sys.exit("[voice] still failing: " + ", ".join(bad))


def write_judge(out, rep):
    with open(os.path.join(out, "judge.json"), "w") as f:
        json.dump(rep, f, indent=2)
    with open(os.path.join(out, "judge.md"), "w") as f:
        f.write("# Narration check: %s\n\n%s\n" % (rep.get("voice", out), table(rep["lines"], "Every line")))
    print(table(rep["lines"], "judge: " + str(rep.get("voice", out))))


def find(d, wav_name):
    stem = os.path.splitext(wav_name)[0]
    for e in EXTS:
        p = os.path.join(d, stem + e)
        if os.path.exists(p):
            return p
    return None


def cmd_check(args):
    d = args.dir
    res = []
    for ln in lines():
        p = find(d, ln["file"])
        if p is None:
            print("[voice] missing:", ln["file"], "(any of", ", ".join(EXTS) + ")")
            continue
        a, sr = load(p)
        if args.fix:
            a = normalize(trim(a, sr), sr)
            out = os.path.join(d, ln["file"])
            save(out, a, sr)
            if p != out:
                print("[voice] %s -> %s" % (os.path.basename(p), ln["file"]))
        res.append(judge(ln, a, sr))
    if not res:
        sys.exit("[voice] no lines found in " + d)
    write_judge(d, {"voice": os.path.basename(os.path.normpath(d)), "summary": summary(res), "lines": res})
    bad = [r["file"] for r in res if not r["pass"]]
    print("[voice] %d/%d lines pass%s" % (len(res) - len(bad), len(res), "" if not bad else ": check " + ", ".join(bad)))


def cmd_mixcheck(args):
    """The narration heard back from a finished video, music and effects and all: each line's words must
    still come through (WER <= 10%). Line times come from <video>.json, written by tools/trailer_edit.py."""
    allok = True
    out = []
    for v in args.videos:
        side = os.path.splitext(v)[0] + ".json"
        if not os.path.exists(v) or not os.path.exists(side):
            print("[voice] mixcheck: no %s (or its .json)" % v)
            allok = False
            continue
        with open(side) as f:
            meta = json.load(f)
        a, sr = load(v)
        a = resample(a, sr, 16000)
        rows = []
        for ln in meta["lines"]:   # each placement on its own: its stretch of the finished mix, music and all
            clip = a[max(0, int((ln["t0"] - 0.35) * 16000)):int((ln["t1"] + 0.35) * 16000)]
            heard, _ = hear(clip, 16000)
            k = ln.get("line", -1)
            if rows and rows[-1]["line"] == k and k >= 0:   # a script line the edit split in two: judged whole
                r = rows[-1]
                r["heard"] = (r["heard"] + " " + heard).strip()
                r["text"] = ln.get("script", r["text"] + " " + ln["text"])
                r["at"] += " + %.1f s" % ln["t0"]
            else:
                rows.append({"line": k, "at": "%.1f s" % ln["t0"], "text": ln["text"], "heard": heard})
        for r in rows:
            r["wer"] = round(wer(r["text"], r["heard"]), 3)
            r["pass"] = r["wer"] <= MAX_WER
        ok = all(r["pass"] for r in rows)
        allok = allok and ok
        out.append({"video": os.path.basename(v), "lines": rows, "pass": ok})
        print("\n### %s: the narration heard back from the finished mix (Whisper %s)\n" % (os.path.basename(v), ASR_MODEL))
        print("| At | Line | Heard in the mix | WER | Pass |\n|---:|---|---|---:|---|")
        for r in rows:
            print("| %s | %s | %s | %.0f%% | %s |" % (r["at"], r["text"], r["heard"], r["wer"] * 100, "yes" if r["pass"] else "NO"))
    if args.videos:
        d = os.path.join(os.path.dirname(os.path.abspath(args.videos[0])), "check")
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "narration_in_mix.json"), "w") as f:
            json.dump(out, f, indent=2)
    if not allok:
        sys.exit("[voice] mixcheck: some narration is lost in the mix")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("audition")
    a.add_argument("--voices", default="bm_george,bm_fable,am_michael,af_heart")
    a.add_argument("--speed", type=float, default=0.92)
    m = sub.add_parser("make")
    m.add_argument("--voice", default="bm_george")
    m.add_argument("--speed", type=float, default=0.92)
    m.add_argument("--out", default=AI_DIR)
    c = sub.add_parser("check")
    c.add_argument("dir")
    c.add_argument("--fix", action="store_true")
    mc = sub.add_parser("mixcheck")
    mc.add_argument("videos", nargs="+")
    args = ap.parse_args()
    {"audition": cmd_audition, "make": cmd_make, "check": cmd_check, "mixcheck": cmd_mixcheck}[args.cmd](args)


if __name__ == "__main__":
    main()
