#!/usr/bin/env python3
"""Import the licensed (CC0) music for Wax & Wane and measure music candidates (re-runnable, deterministic).

    python3 tools/import_audio.py music [slot ...]   # fetch + build the music slots in MUSIC below
    python3 tools/import_audio.py fetch              # only download the sources (music + Ninja SFX) to the cache
    python3 tools/import_audio.py analyse FILE...    # print the descriptors used to choose tracks (globs ok)
    python3 tools/import_audio.py report             # descriptors + loudness / seam check of the built tracks
    python3 tools/import_audio.py mixcheck CAPTURE LOG   # read a movie capture of `--autotest --audiotest`

Sources are downloaded once with curl from the series-ai/jam-ready-assets library (media.githubusercontent.com,
git LFS is not needed) into $AUDIO_CACHE (default ~/.cache/wax_and_wane_audio). Each track is:
  1. decoded to 44.1 kHz stereo float,
  2. high-passed at 25 Hz circularly (some sources carry DC / sub-sonic rumble), so the loop seam stays continuous,
  3. made seamless: these packs ship exact-length loops (a whole number of beats), so the last 4 ms are
     equal-power cross-faded into the first 4 ms (removes the click at the seam, shifts timing by < 5 ms),
  4. measured with ffmpeg loudnorm (EBU R128) and gained to -16 LUFS integrated; a circular look-ahead limiter
     keeps the 4x-oversampled true peak under -1 dBTP,
  5. encoded Ogg Vorbis q4 (44.1 kHz stereo) and verified again (LUFS, true peak, seam jump),
  6. given an .import file with loop=true (jingles loop=false).
Needs ffmpeg (libvorbis), curl, numpy, scipy.
"""
import glob
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.parse

import numpy as np
from scipy import ndimage, signal
from scipy.io import wavfile

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSIC_OUT = os.path.join(ROOT, "assets/audio/music")
LIC_OUT = os.path.join(ROOT, "assets/licenses")
CACHE = os.environ.get("AUDIO_CACHE", os.path.expanduser("~/.cache/wax_and_wane_audio"))
MEDIA = "https://media.githubusercontent.com/media/series-ai/jam-ready-assets/main/"
RAW = "https://raw.githubusercontent.com/series-ai/jam-ready-assets/main/"
NINJA = "ninja-adventure/2D/top-down-rpg/"
NINJA_MUSIC = NINJA + "Audio/Musics/"
NINJA_SOUNDS = NINJA + "Audio/Sounds/"

TARGET_LUFS = -16.0
TP_CEILING = -1.0
SEAM_MS = 4.0

# slot -> source + why it was chosen. Measured with `analyse` (onsets/s = note/hit density, perc = HPSS
# percussive share, minor = KK-profile minor-vs-major correlation, diss = semitone+tritone co-activation,
# reg = energy-weighted mean MIDI pitch, dyn = 95th-10th percentile short-term level). We cannot listen, so each
# choice is argued from those numbers (all 45 Ninja Adventure tracks and the Kenney loops were measured; the Kenney
# loops are 8-30 s and mostly major, so none made the cut).
# Tension ramps floor by floor by onset density: 1.96 -> 2.50 -> 2.72 -> 3.72 /s; boss 3.31, final boss 4.89.
MUSIC = {
    "title": {"src": NINJA_MUSIC + "22 - Dream.ogg", "why":
              "Darkest of the slow pieces: low register (mean pitch MIDI 61), sparse (2.0 onsets/s) and eerie (diss "
              "0.35, no settled key), opens quietly and swells (11 dB dynamic range); 96 s, so the title never loops "
              "audibly. (Manor, Intro and Mystical were busier or brighter / more major.)"},
    "floor_1": {"src": NINJA_MUSIC + "40 - Crypt.ogg", "why":
                "Cellar: the sparsest dark track (1.96 onsets/s), the most clearly minor (C minor, +0.23), the lowest "
                "register of all 45 (mean pitch MIDI 57), slow breathing swells (15 dB). Calm but heavy - the bottom "
                "of the tension ramp."},
    "floor_2": {"src": NINJA_MUSIC + "21 - Dungeon.ogg", "why":
                "Crypt: a step up (2.50 onsets/s) and the most unsettled harmony of the usable tracks (diss 0.36, no "
                "clear key centre), still low (MIDI 58) and slow."},
    "floor_3": {"src": NINJA_MUSIC + "12 - Temple.ogg", "why":
                "Chapel: sacred-sounding minor (C# minor), the highest register of the dark tracks, like a choir or "
                "organ (MIDI 75), consonant (diss 0.05), denser again (2.72 onsets/s)."},
    "floor_4": {"src": NINJA_MUSIC + "24 - Final Area.ogg", "why":
                "Belfry: the most driven floor track (3.72 onsets/s, percussive share 0.25), C minor (+0.17) and "
                "dissonant (0.30); the last climb before the Hour Fiend."},
    "shop": {"src": NINJA_MUSIC + "39 - Boat.ogg", "why":
             "Tallow Merchant: D minor but the most consonant minor track (diss 0.06), a gentle steady lilt (1.99 "
             "onsets/s), 96 s so browsing never loops; a safe room that still lives in the house."},
    "boss": {"src": NINJA_MUSIC + "17 - Fight.ogg", "why":
             "Floor guardians (floors 1-3): D minor, low (MIDI 61), dense (3.31 onsets/s) and dissonant (0.21) - a hard "
             "switch up from the Cellar, Crypt and Chapel tracks."},
    "final_boss": {"src": NINJA_MUSIC + "28 - Tension.ogg", "why":
                   "Hour Fiend: the densest usable track in the pack (4.89 onsets/s) and one of the two most percussive "
                   "(0.30) - the peak of the tension ramp."},
    # endgame stream: the Clock Tower (secret floor 5) and the true ending
    "floor_5": {"src": NINJA_MUSIC + "19 - Ascension.ogg", "why":
                "Clock Tower (secret floor 5): a step sideways after the Belfry - low (MIDI 60), sparse (2.29 onsets/s), "
                "unsettled (diss 0.21, B minor-ish) and moonlit-eerie; the Keeper of Hours still gets final_boss."},
    "ending": {"src": NINJA_MUSIC + "15 - Credit Theme.ogg", "why":
               "True ending cards and credits roll: the pack's own credits piece, high (MIDI 77) and consonant "
               "(diss 0.04), C# minor but gentle; 68 s covers the four cards and the roll."},
}
# victory_jingle / death_jingle stay the original synthesized ones (tools/make_audio.py): they are 3-4 s long to fit
# the victory banner and the snuff-out sequence, minor/major as needed and built from the game's own bell and music
# box; the pack's jingles are 1-2 s chiptune stings that would cut off under the banners.
SYNTH_KEPT = ["victory_jingle", "death_jingle"]

# Ninja Adventure SFX used by tools/make_audio.py (fetched to the cache by `fetch`)
NINJA_SFX = [
    "Elemental/Fire.wav", "Elemental/Fire2.wav", "Elemental/Fire3.wav", "Elemental/Fireball.wav",
    "Elemental/Fireball2.wav", "Elemental/Bubble.wav", "Elemental/Bubble2.wav", "Elemental/Water1.wav",
    "Elemental/Water2.wav", "Elemental/Water3.wav", "Elemental/Water5.wav", "Elemental/WaterDrop.wav",
    "Elemental/Explosion.wav", "Elemental/Explosion2.wav", "Elemental/Explosion4.wav",
    "Hit & Impact/Hit1.wav", "Hit & Impact/Hit2.wav", "Hit & Impact/Hit3.wav", "Hit & Impact/Hit5.wav",
    "Hit & Impact/Impact.wav", "Hit & Impact/Impact2.wav", "Hit & Impact/Impact3.wav", "Hit & Impact/Impact5.wav",
    "Magic & Skill/Magic1.wav", "Magic & Skill/Magic2.wav", "Magic & Skill/Magic3.wav", "Magic & Skill/Spirit.wav",
    "Magic & Skill/Strange.wav", "Magic & Skill/Fx.wav", "Creature/Wings.wav", "Creature/Wings2.wav",
    "Menu/Move1.wav", "Menu/Move2.wav", "Menu/Accept.wav", "Bonus/PowerUp1.wav", "Bonus/Bonus.wav",
    "Whoosh & Slash/Whoosh.wav", "Whoosh & Slash/Whoosh2.wav", "Whoosh & Slash/Launch.wav",
]


# =============================================================================================== fetch
def cache_path(rel):
    return os.path.join(CACHE, rel)


def fetch(rel, text=False):
    """Download one catalogue path into the cache (once). Returns the local path."""
    dst = cache_path(rel)
    if os.path.exists(dst) and os.path.getsize(dst) > 0:
        return dst
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    url = (RAW if text else MEDIA) + urllib.parse.quote(rel)
    tmp = dst + ".part"
    subprocess.run(["curl", "-sS", "-L", "--fail", "--retry", "3", "-o", tmp, url], check=True)
    if os.path.getsize(tmp) < 64:
        raise RuntimeError(f"download too small: {url}")
    os.replace(tmp, dst)
    return dst


def fetch_all():
    fetch(NINJA + "LICENSE.txt", text=True)
    fetch(NINJA + "README.md", text=True)
    for slot in MUSIC.values():
        fetch(slot["src"])
    for s in NINJA_SFX:
        fetch(NINJA_SOUNDS + s)
    print(f"cache: {CACHE}")


# =============================================================================================== DSP
def decode(path, ch=2, sr=SR):
    r = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-ac", str(ch), "-ar", str(sr), "-f", "f32le", "-"],
                       capture_output=True, check=True)
    x = np.frombuffer(r.stdout, np.float32).astype(np.float64)
    return x.reshape(-1, ch) if ch > 1 else x


def db(g):
    return 10 ** (g / 20)


def hp_circular(y, f=25.0):
    sos = signal.butter(2, f, "highpass", fs=SR, output="sos")
    pre = min(len(y), SR * 3)
    return signal.sosfilt(sos, np.concatenate([y[-pre:], y]), axis=0)[pre:]


def seam_crossfade(y, ms=SEAM_MS):
    """Equal-power cross-fade of the last `ms` into the first `ms`; the result is `ms` shorter and loops cleanly."""
    n = int(SR * ms / 1000)
    head, tail = y[:n].copy(), y[-n:].copy()
    k = np.linspace(0, 1, n)[:, None]
    out = y[:-n].copy()
    out[:n] = tail * np.cos(k * np.pi / 2) + head * np.sin(k * np.pi / 2)
    return out


def true_peak_db(y):
    up = signal.resample_poly(y, 4, 1, axis=0)
    return 20 * np.log10(np.max(np.abs(up)) + 1e-12)


def limiter(y, ceiling_db, hold_ms=6.0, loop=True):
    """Look-ahead peak limiter (min-filter then box smoothing: never overshoots); wraps around for loops."""
    thr = db(ceiling_db)
    a = np.max(np.abs(y), axis=1)
    r = np.minimum(1.0, thr / np.maximum(a, 1e-9))
    w = 2 * int(SR * hold_ms / 1000) + 1
    mode = "wrap" if loop else "nearest"
    g = ndimage.minimum_filter1d(r, w, mode=mode)
    g = ndimage.uniform_filter1d(g, w, mode=mode)
    return y * g[:, None]


def loudnorm_measure(path):
    """ffmpeg loudnorm first pass: integrated loudness (LUFS), true peak (dBTP), loudness range (LU)."""
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af",
                        f"loudnorm=I={TARGET_LUFS}:TP={TP_CEILING}:LRA=11:print_format=json", "-f", "null", "-"],
                       capture_output=True, text=True)
    m = re.search(r"\{[^{}]*\"input_i\"[^{}]*\}", r.stderr, re.S)
    d = json.loads(m.group(0))
    return float(d["input_i"]), float(d["input_tp"]), float(d["input_lra"])


def seam_report(y):
    """Sample jump across the loop point vs. the 99th percentile of ordinary sample steps (both channels)."""
    m = y.mean(axis=1)
    jump = abs(m[0] - m[-1])
    p99 = np.percentile(np.abs(np.diff(m)), 99)
    return jump, p99


def write_import(name, loop, folder=MUSIC_OUT, res_dir="res://assets/audio/music/"):
    """Create or patch <folder>/<name>.ogg.import so the stream loops (or not) on import."""
    p = os.path.join(folder, name + ".ogg.import")
    if os.path.exists(p):
        txt = open(p).read()
        txt = re.sub(r"(?m)^loop=.*$", f"loop={'true' if loop else 'false'}", txt)
        txt = re.sub(r"(?m)^loop_offset=.*$", "loop_offset=0", txt)
    else:
        txt = ("[remap]\n\nimporter=\"oggvorbisstr\"\ntype=\"AudioStreamOggVorbis\"\n\n[deps]\n\n"
               f"source_file=\"{res_dir}{name}.ogg\"\n\n[params]\n\n"
               f"loop={'true' if loop else 'false'}\nloop_offset=0\nbpm=0\nbeat_count=0\nbar_beats=4\n")
    with open(p, "w") as f:
        f.write(txt)


def build_music(slot, tmp):
    cfg = MUSIC[slot]
    src = fetch(cfg["src"])
    x = decode(src, 2)
    y = hp_circular(x, 25.0)
    y = seam_crossfade(y)
    wav = os.path.join(tmp, slot + ".wav")
    wavfile.write(wav, SR, y.astype(np.float32))
    li, ltp, lra = loudnorm_measure(wav)
    gain = TARGET_LUFS - li + cfg.get("trim_db", 0.0)
    z = y * db(gain)
    out = os.path.join(MUSIC_OUT, slot + ".ogg")
    ceiling = TP_CEILING - 0.6
    for _ in range(4):
        if true_peak_db(z) > ceiling:
            z = limiter(z, ceiling - 0.3)
        wavfile.write(wav, SR, z.astype(np.float32))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4",
                        "-ar", str(SR), "-ac", "2", out], check=True)
        oi, otp, _ = loudnorm_measure(out)
        if otp <= TP_CEILING + 0.05:
            break
        ceiling -= (otp - TP_CEILING) + 0.2
    jump, p99 = seam_report(decode(out, 2))
    write_import(slot, True)
    kb = os.path.getsize(out) // 1024
    print(f"  {slot:11s} {len(y) / SR:6.1f}s  in {li:6.1f} LUFS/{ltp:5.1f} dBTP  ->  {oi:6.1f} LUFS/{otp:5.1f} dBTP"
          f"  seam jump {jump:.4f} (p99 step {p99:.4f})  {kb:5d} KB   <- {os.path.basename(cfg['src'])}")
    return kb


# =============================================================================================== credits
def write_ninja_licence():
    os.makedirs(LIC_OUT, exist_ok=True)
    lic = open(fetch(NINJA + "LICENSE.txt", text=True)).read()
    readme = open(fetch(NINJA + "README.md", text=True)).read()
    with open(os.path.join(LIC_OUT, "Ninja_Adventure_CC0.txt"), "w") as f:
        f.write("Ninja Adventure Asset Pack - music and sound effects used in Wax & Wane\n"
                "Assets created by Pixel-boy (https://pixel-boy.itch.io/) and AAA\n"
                "Pack page: https://pixel-boy.itch.io/ninja-adventure-asset-pack\n"
                "Obtained via the series-ai/jam-ready-assets library (ninja-adventure/2D/top-down-rpg/).\n\n"
                "---- README.md (as shipped) ----\n" + readme.strip() + "\n\n---- LICENSE.txt (as shipped) ----\n" + lic)


def write_credits():
    write_ninja_licence()
    lines = [
        "Wax & Wane - music credits",
        "==========================",
        "",
        "Built by tools/import_audio.py (re-runnable). Licensed tracks are CC0 1.0 (public domain); credit is",
        "appreciated, not required. Licence: assets/licenses/Ninja_Adventure_CC0.txt",
        "",
        "Processing: 25 Hz high-pass, 4 ms loop-seam cross-fade, EBU R128 loudness -16 LUFS, true peak <= -1 dBTP,",
        "Ogg Vorbis q4, 44.1 kHz stereo, loop=true.",
        "",
    ]
    for slot, cfg in MUSIC.items():
        lines.append(f"  {slot + '.ogg':20s} \"{os.path.splitext(os.path.basename(cfg['src']))[0]}\" - Ninja Adventure "
                     "Asset Pack by Pixel-boy & AAA (CC0)")
    for s in SYNTH_KEPT:
        lines.append(f"  {s + '.ogg':20s} original composition, synthesized for this game (tools/make_audio.py)")
    lines += ["", "Why each track (measured; see tools/import_audio.py MUSIC):"]
    for slot, cfg in MUSIC.items():
        lines.append(f"  {slot}: {cfg['why']}")
    with open(os.path.join(LIC_OUT, "CREDITS_music.txt"), "w") as f:
        f.write("\n".join(lines) + "\n")


# =============================================================================================== analysis
KK_MAJ = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
KK_MIN = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])
PCN = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]


def describe(path):
    sr = 22050
    x = decode(path, 1, sr)
    x = signal.sosfilt(signal.butter(2, 25.0, "highpass", fs=sr, output="sos"), x)   # DC / rumble would bias it
    dur = len(x) / sr
    f, t, Z = signal.stft(x, sr, nperseg=1024, noverlap=768, boundary=None)
    M = np.abs(Z)
    P = M ** 2
    flux = np.maximum(0, np.diff(np.log1p(100 * M), axis=1)).sum(axis=0)
    flux = np.maximum(flux - signal.medfilt(flux, 15), 0)
    on, _ = signal.find_peaks(flux, height=flux.mean() + flux.std(), distance=int(0.06 * sr / 256))
    cen = float(np.median((f[:, None] * P).sum(0) / (P.sum(0) + 1e-12)))
    low = float(P[(f > 30) & (f < 200)].sum() / P[f > 30].sum())
    H = ndimage.median_filter(M, size=(1, 17))
    Pp = ndimage.median_filter(M, size=(17, 1))
    perc = float((Pp ** 2).sum() / ((Pp ** 2).sum() + (H ** 2).sum()))
    f2, _, Z2 = signal.stft(x, sr, nperseg=8192, noverlap=8192 - 2048, boundary=None)
    L = np.log1p(50 * np.abs(Z2) / (np.abs(Z2).max() + 1e-12))
    band = (f2 > 100) & (f2 < 2500)
    midi = 69 + 12 * np.log2(f2[band] / 440.0)
    wgt = np.exp(-0.5 * ((midi - np.round(midi)) / 0.2) ** 2)
    pc = np.mod(np.round(midi), 12).astype(int)
    C = np.stack([(L[band][pc == k] * wgt[pc == k][:, None]).sum(0) for k in range(12)])
    ch = C.sum(1) / C.sum()
    sc = [(np.corrcoef(ch, np.roll(prof, k))[0, 1], k, mode) for k in range(12)
          for mode, prof in (("maj", KK_MAJ), ("min", KK_MIN))]
    best = max(sc)
    minor = max(s[0] for s in sc if s[2] == "min") - max(s[0] for s in sc if s[2] == "maj")
    act = (C / (C.max(0, keepdims=True) + 1e-9) > 0.6).astype(float)
    diss = float(np.mean([(act[k] * act[(k + 1) % 12]).mean() + (act[k] * act[(k + 6) % 12]).mean() for k in range(12)]))
    bandr = (f2 > 60) & (f2 < 4000)
    Pm = (np.abs(Z2[bandr]) ** 2).sum(1)
    reg = float(((69 + 12 * np.log2(f2[bandr] / 440)) * Pm).sum() / Pm.sum())
    win = int(0.4 * sr)
    n = len(x) // win
    st = 20 * np.log10(np.sqrt(np.mean(x[:n * win].reshape(n, win) ** 2, 1)) + 1e-9)
    st = st[st > st.max() - 40]
    dyn = float(np.percentile(st, 95) - np.percentile(st, 10))
    return {"file": os.path.basename(path), "dur": dur, "onsets": len(on) / dur, "centroid": cen, "low": low,
            "perc": perc, "key": f"{PCN[best[1]]} {best[2]}", "minor": minor, "diss": diss, "reg": reg, "dyn": dyn}


def print_desc(d):
    print(f"  {d['file'][:26]:26s} {d['dur']:6.1f}s  onsets {d['onsets']:4.2f}/s  perc {d['perc']:.3f}  "
          f"cen {d['centroid']:5.0f} Hz  low {d['low']:.2f}  key {d['key']:7s} minor {d['minor']:+.2f}  "
          f"diss {d['diss']:.3f}  reg {d['reg']:4.1f}  dyn {d['dyn']:4.1f} dB")


def report():
    print("built music (assets/audio/music):")
    tot = 0
    for p in sorted(glob.glob(os.path.join(MUSIC_OUT, "*.ogg"))):
        i, tp, lra = loudnorm_measure(p)
        y = decode(p, 2)
        jump, p99 = seam_report(y)
        kb = os.path.getsize(p) / 1024
        tot += kb
        print(f"  {os.path.basename(p):20s} {len(y) / SR:6.1f}s {i:6.1f} LUFS {tp:5.1f} dBTP LRA {lra:4.1f}  "
              f"seam {jump:.4f}/{p99:.4f}  {kb:6.0f} KB")
    print(f"  total {tot / 1024:.2f} MB")
    print("descriptors:")
    for p in sorted(glob.glob(os.path.join(MUSIC_OUT, "*.ogg"))):
        print_desc(describe(p))


# =============================================================================================== mix check
def mixcheck(capture, log):
    """Measure the game's real output (Godot --write-movie capture of `-- --autotest --audiotest`) against the
    [audio] marks in its log: clipping, intensity / pause low-pass, ducking, the low-wax layer, music levels
    and the per-floor reverb tails."""
    sr = 48000
    r = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", capture, "-vn", "-ac", "2", "-ar", str(sr), "-f", "f32le", "-"],
                       capture_output=True, check=True)
    x = np.frombuffer(r.stdout, np.float32).astype(np.float64).reshape(-1, 2)
    marks = {}
    order = []
    for line in open(log):
        m = re.match(r"\[audio\] mark ([0-9.]+) (\S+)", line)
        if m:
            marks[m.group(2)] = float(m.group(1))
            order.append(m.group(2))
    mono = x.mean(1)
    fails = []

    def seg(a, b):
        return mono[int(a * sr):int(b * sr)]

    def rms_db(y):
        return 20 * np.log10(np.sqrt(np.mean(y ** 2)) + 1e-12)

    def band_db(y, lo, hi):
        f, P = signal.welch(y, sr, nperseg=4096)
        return 10 * np.log10(P[(f >= lo) & (f < hi)].sum() + 1e-20)

    def span(name, pad=0.4, length=None):
        a = marks[name] + pad
        b = a + length if length else marks[order[order.index(name) + 1]] - 0.05
        return a, b

    pk = 20 * np.log10(np.max(np.abs(x)) + 1e-12)
    clipped = int(np.sum(np.abs(x) >= 0.999))
    print(f"  output peak {pk:.2f} dBFS, samples at full scale: {clipped}")
    if pk > -0.3 or clipped:
        fails.append("clipping")
    print("  music state      rms dB   >3 kHz rel. 150-1000 Hz (dB)")
    hf = {}
    for name in ("combat", "cleared", "paused", "unpaused"):
        a, b = span(name, 0.8)
        y = seg(a, b)
        hf[name] = band_db(y, 3000, 12000) - band_db(y, 150, 1000)
        print(f"  {name:14s} {rms_db(y):7.1f}   {hf[name]:7.1f}")
    if not (hf["paused"] < hf["cleared"] - 6 and hf["cleared"] < hf["combat"] - 1.5 and hf["unpaused"] > hf["paused"] + 10):
        fails.append("intensity low-pass ordering")
    a = marks["duck"]
    before, during = rms_db(seg(a - 1.0, a - 0.05)), rms_db(seg(a + 0.15, a + 0.95))
    print(f"  duck -8 dB: {before:.1f} -> {during:.1f} dB ({during - before:+.1f})")
    if during - before > -4.0:
        fails.append("duck")
    lw, le = span("lowwax", 0.5), span("lowwax_end", 1.6)
    t_on, t_off = band_db(seg(*lw), 1800, 4500), band_db(seg(*le), 1800, 4500)
    s_on, s_off = band_db(seg(*lw), 30, 90), band_db(seg(*le), 30, 90)
    print(f"  low-wax layer: ticks band {t_on - t_off:+.1f} dB, heartbeat band {s_on - s_off:+.1f} dB vs after")
    if t_on - t_off < 3.0:
        fails.append("low-wax ticks not audible")
    for name in ("shop", "floor_resume", "boss"):
        a, b = span(name, 1.2)
        print(f"  {name:14s} rms {rms_db(seg(a, b)):6.1f} dB")
    a, b = span("burst", 0.0)
    y = x[int(a * sr):int(b * sr)]
    print(f"  SFX burst: peak {20 * np.log10(np.max(np.abs(y)) + 1e-12):.2f} dBFS, rms {rms_db(y.mean(1)):.1f} dB")
    print("  space   decay to -30 dB after a door slam")
    rts = []
    for f in (1, 2, 3, 4):
        a = marks[f"space_{f}"]
        y = seg(a, a + 1.55)
        env = 20 * np.log10(np.sqrt(ndimage.uniform_filter1d(y ** 2, int(0.02 * sr))) + 1e-9)
        i0 = int(np.argmax(env))
        below = np.where(env[i0:] < env[i0] - 30)[0]
        rt = below[0] / sr if len(below) else 1.55
        rts.append(rt)
        print(f"  {f}       {rt * 1000:6.0f} ms")
    if not (rts[0] < rts[1] and rts[0] < rts[2] and rts[2] >= rts[1]):
        fails.append("reverb spaces ordering")
    print("  mixcheck: " + ("OK" if not fails else "FAILED: " + ", ".join(fails)))
    return not fails


# =============================================================================================== main
def main():
    args = sys.argv[1:]
    what = args[0] if args else "music"
    if what == "fetch":
        fetch_all()
    elif what == "analyse":
        files = []
        for g in args[1:]:
            files += sorted(glob.glob(g)) or [g]
        for p in files:
            print_desc(describe(p))
    elif what == "report":
        report()
    elif what == "mixcheck":
        sys.exit(0 if mixcheck(args[1], args[2]) else 1)
    elif what == "music":
        os.makedirs(MUSIC_OUT, exist_ok=True)
        slots = args[1:] or list(MUSIC)
        with tempfile.TemporaryDirectory(prefix="wax_music_") as tmp:
            tot = sum(build_music(s, tmp) for s in slots)
        print(f"  built {len(slots)} tracks, {tot / 1024:.2f} MB")
        write_credits()
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
