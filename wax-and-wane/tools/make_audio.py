#!/usr/bin/env python3
"""Build every sound effect and music track for Wax & Wane (re-runnable, deterministic).

    python3 tools/make_audio.py                    # all SFX + all music + credits
    python3 tools/make_audio.py sfx [name ...]     # SFX only (optionally just some)
    python3 tools/make_audio.py music [name ...]   # music only (optionally just some)
    python3 tools/make_audio.py review [out_dir]   # print stats + write spectrogram PNGs of the built files

SFX: layered from CC0 Kenney packs (env KENNEY_PACKS, default /opt/assets/packs) and/or numpy synthesis,
then trimmed, faded, made mono, loudness-balanced and encoded by ffmpeg (Ogg Vorbis q5, 44.1 kHz mono).
Music: composed in code (no samples) and rendered with numpy/scipy synthesis. Loops are seamless (reverb tail
wrapped onto the loop start), Ogg Vorbis q4, 44.1 kHz stereo, RMS about -16 dBFS, peaks below -1 dBFS.
Needs ffmpeg (libvorbis), numpy, scipy (and Pillow for `review`).
"""
import functools
import itertools
import os
import shutil
import subprocess
import sys
import tempfile
from fractions import Fraction

import numpy as np
from scipy import ndimage, signal
from scipy.io import wavfile

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_OUT = os.path.join(ROOT, "assets/audio/sfx")
MUSIC_OUT = os.path.join(ROOT, "assets/audio/music")
LIC_OUT = os.path.join(ROOT, "assets/licenses")
PACKS = os.environ.get("KENNEY_PACKS", "/opt/assets/packs")
TMP = tempfile.mkdtemp(prefix="wax_audio_")

IMPACT = "kenney-impact-sounds/audio/Audio/"
RPG = "kenney-rpg-audio/audio/Audio/"
UI = "kenney-interface-sounds/audio/Audio/"
FOLEY = "kenney-foley-sounds/audio/Audio/"
RETRO1 = "kenney-retro-sounds-1/audio/Audio/"
RETRO2 = "kenney-retro-sounds-2/audio/Audio/"
PACK_INFO = {  # pack dir -> (display name, licence file name in assets/licenses)
    "kenney-impact-sounds": ("Impact Sounds", "Kenney_Impact_Sounds_CC0.txt"),
    "kenney-rpg-audio": ("RPG Audio", "Kenney_RPG_Audio_CC0.txt"),
    "kenney-interface-sounds": ("Interface Sounds", "Kenney_Interface_Sounds_CC0.txt"),
    "kenney-foley-sounds": ("Foley Sounds", "Kenney_Foley_Sounds_CC0.txt"),
    "kenney-retro-sounds-1": ("Retro Sounds 1", "Kenney_Retro_Sounds_1_CC0.txt"),
    "kenney-retro-sounds-2": ("Retro Sounds 2", "Kenney_Retro_Sounds_2_CC0.txt"),
}


# =============================================================================================== DSP basics
def secs(d):
    return int(round(d * SR))


def t_(n):
    return np.arange(n) / SR


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def rng(seed):
    return np.random.default_rng(seed)


def _sos(kind, f, order):
    f = np.clip(np.atleast_1d(np.asarray(f, float)), 10, SR / 2 - 200)
    return signal.butter(order, f if len(f) > 1 else f[0], btype=kind, fs=SR, output="sos")


def lp(x, f, order=2):
    return signal.sosfilt(_sos("lowpass", f, order), x, axis=0)


def hp(x, f, order=2):
    return signal.sosfilt(_sos("highpass", f, order), x, axis=0)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(_sos("bandpass", [lo, hi], order), x, axis=0)


def peak(x):
    return float(np.max(np.abs(x))) if len(x) else 0.0


def norm(x, p=1.0):
    m = peak(x)
    return x if m == 0 else x * (p / m)


def db(g):
    return 10 ** (g / 20)


def sat(x, drive=2.0):
    """Soft saturation of a peak-normalised signal (adds harmonics so bass survives phone speakers)."""
    return np.tanh(drive * norm(x)) / np.tanh(drive)


def phase(freq):
    return 2 * np.pi * np.cumsum(freq) / SR


def env_ad(n, a=0.005, tau=0.1):
    t = t_(n)
    att = np.where(t < a, 0.5 - 0.5 * np.cos(np.pi * np.clip(t / max(a, 1e-6), 0, 1)), 1.0)
    return att * np.exp(-np.maximum(t - a, 0) / tau)


def env_ar(n, a, r, shape=1.0):
    """Raised-cosine attack over a s, then a smooth fall to 0 at the end (r = fraction of n that falls)."""
    t = np.arange(n) / max(n - 1, 1)
    e = np.ones(n)
    an = max(1, secs(a))
    e[:an] = 0.5 - 0.5 * np.cos(np.pi * np.arange(an) / an)
    rn = max(1, int(n * r))
    e[-rn:] *= (0.5 + 0.5 * np.cos(np.pi * np.arange(rn) / rn)) ** shape
    return e


def fit(x, n):
    return x[:n] if len(x) >= n else np.pad(x, (0, n - len(x)))


def mix(*layers):
    """layers: (signal, offset_s, gain_db). Returns the sum, long enough for everything."""
    n = max(secs(o) + len(x) for x, o, g in layers)
    out = np.zeros(n)
    for x, o, g in layers:
        s = secs(o)
        out[s:s + len(x)] += x * db(g)
    return out


def resample_rate(x, rate):
    """Play `rate` times faster (pitch and speed together, like a tape)."""
    if abs(rate - 1) < 1e-6:
        return x
    fr = Fraction(rate).limit_denominator(200)
    return signal.resample_poly(x, fr.denominator, fr.numerator)


def saw(freq, ph0=0.0):
    """Band-limited (polyBLEP) sawtooth for a per-sample frequency array."""
    freq = np.asarray(freq, float)
    dt = freq / SR
    ph = (ph0 + np.cumsum(dt)) % 1.0
    x = 2 * ph - 1
    m = ph < dt
    tt = ph[m] / dt[m]
    x[m] -= tt + tt - tt * tt - 1
    m = ph > 1 - dt
    tt = (ph[m] - 1) / dt[m]
    x[m] -= tt * tt + tt + tt + 1
    return x


def spec_mask(x, maskfn, nper=1024):
    """Time-varying filter: STFT, multiply by maskfn(f[:,None], t[None,:]), inverse STFT."""
    f, tt, Z = signal.stft(x, SR, nperseg=nper, noverlap=nper * 3 // 4)
    Z = Z * maskfn(f[:, None], tt[None, :])
    _, y = signal.istft(Z, SR, nperseg=nper, noverlap=nper * 3 // 4)
    return fit(y, len(x))


def band_noise(dur, seed, fc, bw_oct=1.0):
    """White noise through a (time-varying) log-gaussian band; fc is Hz or a function of time."""
    x = rng(seed).standard_normal(secs(dur))

    def mask(f, t):
        c = fc(t) if callable(fc) else fc
        return np.exp(-0.5 * (np.log2(np.maximum(f, 1.0) / c) / (bw_oct / 2)) ** 2)
    return norm(spec_mask(x, mask))


def formant_filter(x, formants, floor=0.03):
    """formants: list of (freq_fn_or_hz, bandwidth_hz, gain)."""
    def mask(f, t):
        m = np.full(np.broadcast(f, t).shape, floor)
        for fc, bw, g in formants:
            c = fc(t) if callable(fc) else fc
            m = m + g * np.exp(-0.5 * ((f - c) / bw) ** 2)
        return m
    return spec_mask(x, mask)


def crackle(dur, seed, rate=60.0, tau=0.0025, hpf=2500):
    """Sparse fire crackles: random decaying noise ticks."""
    n = secs(dur)
    r = rng(seed)
    imp = np.zeros(n)
    k = max(1, int(rate * dur))
    pos = r.integers(0, n, k)
    imp[pos] = r.uniform(0.2, 1.0, k) ** 2 * r.choice([-1, 1], k)
    y = signal.lfilter([1.0], [1.0, -np.exp(-1 / (tau * SR))], imp) * r.standard_normal(n)
    return norm(hp(y, hpf))


def room(x, mix_=0.2, dur=0.8, tau=0.15, bright=5000, seed=3):
    """Small mono room reverb (keeps the dry signal, adds a tail)."""
    n = secs(dur)
    ir = rng(seed).standard_normal(n) * np.exp(-t_(n) / tau)
    ir = lp(ir, bright)
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = signal.fftconvolve(x, ir)
    return np.pad(x, (0, len(wet) - len(x))) * (1 - mix_) + wet * mix_


# =============================================================================================== instruments
@functools.lru_cache(maxsize=None)
def _music_box(m):
    f = midi_hz(m)
    tau = float(np.clip(1.6 * (523.25 / f) ** 0.6, 0.35, 3.0))
    n = secs(min(tau * 5, 7))
    t = t_(n)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / tau)
    x += 0.35 * np.sin(2 * np.pi * f * 1.0012 * t + 1.3) * np.exp(-t / (tau * 0.9))  # 2nd tine: slow beating
    x += 0.10 * np.sin(2 * np.pi * 2 * f * t + 0.5) * np.exp(-t / (tau * 0.35))
    if 3 * f < 16000:
        x += 0.05 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-t / 0.12)
    if 5.93 * f < 16000:  # inharmonic upper tine mode = the "ping"
        x += 0.20 * np.sin(2 * np.pi * 5.93 * f * t) * np.exp(-t / 0.045)
    k = secs(0.006)
    x[:k] += hp(rng(int(m * 10) + 1).standard_normal(k), 2500) * np.linspace(1, 0, k) * 0.06
    x *= 1 - np.exp(-t / 0.0012)
    return norm(x)


def music_box(m, vel=1.0):
    return _music_box(round(float(m), 2)) * vel


@functools.lru_cache(maxsize=None)
def _celesta(m):
    f = midi_hz(m)
    tau = float(np.clip(1.1 * (523.25 / f) ** 0.5, 0.3, 2.2))
    n = secs(tau * 5)
    t = t_(n)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / tau)
    x += 0.16 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t / (tau * 0.3))
    if 4 * f < 16000:
        x += 0.06 * np.sin(2 * np.pi * 4 * f * t) * np.exp(-t / 0.08)
    x *= 1 - np.exp(-t / 0.003)
    return norm(x)


def celesta(m, vel=1.0):
    return _celesta(round(float(m), 2)) * vel


def strings(m, dur, vel=1.0, bright=1400, attack=0.35, release=0.7, vib=0.0035, trem=0.0, trem_hz=8.0, seed=0):
    """Ensemble string pad: three detuned band-limited saws, low-passed, with delayed vibrato."""
    f = midi_hz(m)
    n = secs(dur + release)
    t = t_(n)
    r = rng(seed + int(m * 13))
    vibr = 1 + vib * np.sin(2 * np.pi * 5.1 * t + r.uniform(0, 6)) * np.clip((t - 0.2) / 0.4, 0, 1)
    x = sum(saw(np.full(n, f * 2 ** (c / 1200)) * vibr, r.uniform()) for c in (-9, 0, 8)) / 3
    x = lp(lp(x, bright), bright * 1.6)
    e = np.ones(n)
    an = max(1, secs(attack))
    e[:an] = 0.5 - 0.5 * np.cos(np.pi * np.arange(an) / an)
    dn = secs(dur)
    e[dn:] = np.exp(-np.arange(n - dn) / (release * SR / 4))
    if trem:
        x = x * (1 - trem * 0.5 * (1 + np.sin(2 * np.pi * trem_hz * t)))
    return x * e * vel


def organ(m, dur, vel=1.0, attack=0.12, release=0.4):
    f = midi_hz(m)
    n = secs(dur + release)
    t = t_(n)
    x = np.zeros(n)
    for k, a in ((1, 1.0), (2, 0.55), (3, 0.3), (4, 0.18), (6, 0.08), (8, 0.05)):
        if k * f < 12000:
            x += a * np.sin(2 * np.pi * k * f * t + k)
    x *= 1 + 0.06 * np.sin(2 * np.pi * 5.6 * t)
    e = np.ones(n)
    an = secs(attack)
    e[:an] = np.linspace(0, 1, an)
    dn = secs(dur)
    e[dn:] = np.exp(-np.arange(n - dn) / (release * SR / 4))
    return x * e * vel / 2.2


@functools.lru_cache(maxsize=None)
def _pizz(m):
    f = midi_hz(m)
    tau = float(np.clip(0.9 * (110 / f) ** 0.4, 0.25, 1.2))
    n = secs(tau * 4)
    t = t_(n)
    x = np.zeros(n)
    for k in range(1, 15):
        if k * f > 6000:
            break
        x += (1 / k ** 1.3) * np.sin(2 * np.pi * k * f * t + 0.7 * k) * np.exp(-t / (tau / (1 + 0.35 * (k - 1))))
    x *= 1 - np.exp(-t / 0.003)
    return norm(x)


def pizz(m, vel=1.0):
    return _pizz(round(float(m), 2)) * vel


def spiccato(m, dur, vel=1.0, bright=2400):
    f = midi_hz(m)
    n = secs(dur + 0.12)
    t = t_(n)
    x = (saw(np.full(n, f * 1.003)) + saw(np.full(n, f * 0.997), 0.4)) / 2
    x = lp(x, bright)
    e = (1 - np.exp(-t / 0.004)) * (0.35 + 0.65 * np.exp(-t / 0.07))
    dn = secs(dur)
    e[dn:] *= np.exp(-np.arange(n - dn) / (0.025 * SR))
    return x * e * vel


def brass(m, dur, vel=1.0):
    f = midi_hz(m)
    n = secs(dur + 0.2)
    t = t_(n)
    x = sum(saw(np.full(n, f * 2 ** (c / 1200)), i * 0.3) for i, c in enumerate((-7, 0, 6))) / 3
    k = np.clip(t / 0.09, 0, 1)
    x = lp(x, 650) * (1 - k) + lp(x, 2200) * k
    x = np.tanh(x * 1.6)
    e = np.ones(n)
    an = secs(0.05)
    e[:an] = np.linspace(0, 1, an)
    e *= 0.75 + 0.25 * np.exp(-t / 0.2)
    dn = secs(dur)
    e[dn:] *= np.exp(-np.arange(n - dn) / (0.05 * SR))
    return x * e * vel


def thump(f0, tau, seed=0):
    n = secs(0.45)
    t = t_(n)
    fr = f0 * (1 + 0.7 * np.exp(-t / 0.018))
    x = np.sin(phase(fr)) * np.exp(-t / tau)
    x += 0.35 * np.sin(phase(fr * 2.1)) * np.exp(-t / (tau * 0.5))
    x = sat(x, 2.2) * np.exp(-t / (tau * 1.4))
    x += lp(rng(seed).standard_normal(n), 500) * np.exp(-t / 0.012) * 0.15
    return x * (1 - np.exp(-t / 0.002))


def heartbeat(vel=1.0, f0=55.0):
    return mix((thump(f0, 0.085, 1), 0, 0), (thump(f0 * 1.12, 0.07, 2), 0.27, -3)) * vel


def tom(f0=90.0, vel=1.0, tau=0.26, seed=0):
    n = secs(tau * 3)
    t = t_(n)
    fr = f0 * (1 + 0.55 * np.exp(-t / 0.03))
    x = np.sin(phase(fr)) * np.exp(-t / tau)
    x += 0.3 * bp(rng(seed).standard_normal(n), 150, 1500) * np.exp(-t / 0.035)
    x = sat(x, 1.6)
    return x * (1 - np.exp(-t / 0.0015)) * vel


def clock_tick(tock=False, vel=1.0, seed=0):
    n = secs(0.07)
    t = t_(n)
    base = 1900.0 if tock else 2600.0
    x = np.zeros(n)
    for ratio, a, tau in ((1.0, 1.0, 0.006), (1.73, 0.55, 0.004), (0.48, 0.5, 0.012), (3.1, 0.25, 0.002)):
        x += a * np.sin(2 * np.pi * base * ratio * t + ratio) * np.exp(-t / tau)
    x += hp(rng(seed + 7).standard_normal(n), 3000) * np.exp(-t / 0.0015) * 0.7
    x *= 1 - np.exp(-t / 0.0003)
    return norm(x) * vel


def church_bell(f_prime, dur=4.5, vel=1.0, seed=3):
    """Additive church bell: hum, prime, tierce (minor third), quint, nominal + upper partials, each a slightly
    detuned doublet (beating), long exponential decays, plus a short metallic strike."""
    n = secs(dur)
    t = t_(n)
    r = rng(seed)
    scale = (146.83 / f_prime) ** 0.35  # smaller bells ring shorter
    partials = [  # (ratio to prime, amplitude, decay tau s)
        (0.5, 0.60, 6.0), (1.0, 0.45, 3.6), (1.188, 0.55, 3.0), (1.5, 0.20, 2.2), (2.0, 0.80, 2.3),
        (2.52, 0.28, 1.2), (2.67, 0.22, 1.0), (3.0, 0.16, 0.8), (4.03, 0.12, 0.55), (5.04, 0.07, 0.35),
        (5.98, 0.05, 0.25),
    ]
    x = np.zeros(n)
    for ratio, a, tau in partials:
        f = f_prime * ratio
        if f > 15000:
            continue
        beat = r.uniform(0.35, 1.6)
        ph = r.uniform(0, 6.28, 2)
        dec = np.exp(-t / (tau * scale))
        x += a * 0.5 * (np.sin(2 * np.pi * (f - beat / 2) * t + ph[0]) + np.sin(2 * np.pi * (f + beat / 2) * t + ph[1])) * dec
    k = secs(0.25)
    strike = bp(r.standard_normal(k), 900, 6000) * np.exp(-t_(k) / 0.012) * 0.35
    for ratio in (6.7, 8.3, 9.9):
        f = f_prime * ratio
        if f < 15000:
            strike += 0.12 * np.sin(2 * np.pi * f * t_(k)) * np.exp(-t_(k) / 0.03)
    x[:k] += strike
    x *= 1 - np.exp(-t / 0.0015)
    return norm(x) * vel


def breath(dur, seed=0, f1=800.0, f2=1500.0, a=0.07):
    """Breathy blow: noise through two soft formants, swelling in then dying away."""
    n = secs(dur)
    x = rng(seed).standard_normal(n)
    y = formant_filter(x, [(f1, 260, 1.0), (f2, 500, 0.6), (3000, 1200, 0.25)], floor=0.02)
    flutter = 1 + 0.25 * lp(rng(seed + 1).standard_normal(n), 18) / 0.1
    y = y * np.clip(flutter, 0.4, 1.8)
    return norm(lp(y, 6000)) * env_ar(n, a, 0.8, 1.6)


# =============================================================================================== SFX recipes
USED = {}
_CUR = []
_SRC = {}


def src(rel, rate=1.0, rev=False):
    """A pack sound: mono float, leading silence removed, peak 1. rate>1 = faster/higher."""
    _CUR.append(rel)
    key = (rel, rate, rev)
    if key not in _SRC:
        r = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", os.path.join(PACKS, rel), "-ac", "1", "-ar", str(SR),
                            "-f", "f32le", "-"], capture_output=True, check=True)
        x = np.frombuffer(r.stdout, np.float32).astype(np.float64)
        x = hp(x, 20, 1)
        if rev:
            x = x[::-1]
        x = resample_rate(x, rate)
        idx = np.where(np.abs(x) > peak(x) * db(-50))[0]
        x = x[max(0, idx[0] - secs(0.001)):idx[-1] + 1]
        _SRC[key] = norm(x)
    return _SRC[key].copy()


def sizzle(dur, seed, fc=5000, tau=0.12):
    n = secs(dur)
    hiss = band_noise(dur, seed, fc, 1.6)
    crk = crackle(dur, seed + 1, rate=90, hpf=2000)
    return norm(hiss * 0.6 + crk * 0.7) * env_ad(n, 0.004, tau)


def chime(notes, inst=music_box):
    """notes: (time_s, midi, gain_db)."""
    return mix(*[(inst(m), tt, g) for tt, m, g in notes])


def sfx_shoot():
    n = secs(0.17)
    fwip = band_noise(0.17, 11, lambda t: 900 * 2.4 ** np.clip(t / 0.12, 0, 1), 1.2) * env_ad(n, 0.006, 0.045)
    body = np.sin(phase(np.linspace(320, 190, n))) * env_ad(n, 0.003, 0.03)
    return mix((src(FOLEY + "Woosh/woosh4.ogg", 1.2), 0, 0), (fwip, 0, -3), (body, 0, -12),
               (crackle(0.12, 12, rate=50), 0.01, -16))


def sfx_hit_wall():
    n = secs(0.12)
    fizz = band_noise(0.12, 21, 4500, 1.5) * env_ad(n, 0.002, 0.035)
    return mix((src(IMPACT + "impactWood_light_002.ogg"), 0, 0), (sat(src(IMPACT + "impactSoft_medium_000.ogg"), 2.5), 0, -7),
               (fizz, 0.004, -11))


def sfx_hit_enemy():
    n = secs(0.08)
    squelch = band_noise(0.08, 31, lambda t: 1400 * 0.5 ** np.clip(t / 0.06, 0, 1), 1.2) * env_ad(n, 0.002, 0.022)
    return mix((sat(src(IMPACT + "impactPunch_medium_002.ogg"), 2.5), 0, 0), (src(FOLEY + "Water/drip3.ogg"), 0.004, -9),
               (squelch, 0, -8))


def sfx_enemy_die():
    n = secs(0.45)
    poof = band_noise(0.45, 41, lambda t: 1300 * 0.2 ** np.clip(t / 0.4, 0, 1), 1.5) * env_ad(n, 0.01, 0.12)
    return mix((sat(src(IMPACT + "impactPunch_heavy_002.ogg"), 2.5), 0, -1), (poof, 0, -3),
               (src(FOLEY + "Woosh/woosh3.ogg", 0.7), 0.01, -6), (src(FOLEY + "Water/drip2.ogg", 0.8), 0.03, -12))


def sfx_enemy_shoot():
    n = secs(0.11)
    blob = np.sin(phase(np.geomspace(520, 230, n))) * env_ad(n, 0.004, 0.04)
    hiss = band_noise(0.11, 51, lambda t: 900 * 0.6 ** np.clip(t / 0.1, 0, 1), 1.0) * env_ad(n, 0.004, 0.035)
    return mix((src(FOLEY + "Woosh/woosh7.ogg", 0.8), 0, 0), (blob, 0, -5), (hiss, 0, -8))


def sfx_player_hurt():
    return mix((sat(src(IMPACT + "impactPunch_medium_003.ogg"), 2.5), 0, 0), (sizzle(0.38, 61, 5000, 0.12), 0.01, -3),
               (src(FOLEY + "Woosh/woosh6.ogg", 0.85), 0, -9))


def sfx_wax_pickup():
    return mix((src(UI + "drop_002.ogg"), 0, 0), (music_box(93), 0.03, -10), (celesta(81), 0.0, -14))


def sfx_coin_pickup():
    return mix((src(UI + "glass_002.ogg"), 0, 0), (src(RPG + "handleCoins2.ogg"), 0.01, -7))


def sfx_bomb_pickup():
    return mix((sat(src(IMPACT + "impactMetal_heavy_002.ogg"), 2.0), 0, 0), (src(RPG + "cloth2.ogg"), 0.03, -5))


def sfx_bomb_place():
    return mix((sat(src(IMPACT + "impactPlate_light_000.ogg"), 2.5), 0, 0), (sizzle(0.75, 71, 4200, 0.35), 0.05, -9))


def sfx_explosion():
    n = secs(1.2)
    t = t_(n)
    boom = sat(np.sin(phase(70 * 0.5 ** np.clip(t / 0.5, 0, 1))) * np.exp(-t / 0.35)
               + lp(rng(81).standard_normal(n), 300) * np.exp(-t / 0.25) * 0.5, 2.5)
    x = mix((sat(lp(src(RETRO2 + "explosion2.ogg"), 2500), 1.5), 0, -2), (sat(src(IMPACT + "impactMining_000.ogg"), 3.0), 0, -3),
            (src(IMPACT + "impactPunch_heavy_000.ogg"), 0, -4), (boom, 0, -1),
            (src(FOLEY + "Rocks/stonesHit1.ogg"), 0.10, -11), (src(FOLEY + "Rocks/stonesHit2.ogg"), 0.21, -13),
            (src(FOLEY + "Rocks/rockHit2.ogg"), 0.33, -15))
    return room(x, 0.25, 1.0, 0.2, 3500, 82)


def sfx_door_open():
    return mix((src(RPG + "doorOpen_1.ogg"), 0, 0), (src(RPG + "creak2.ogg", 0.8), 0, -8))


def sfx_door_close():
    return mix((src(RPG + "doorClose_4.ogg"), 0, 0), (sat(src(IMPACT + "impactWood_heavy_000.ogg"), 2.0), 0, -5),
               (src(RPG + "metalLatch.ogg"), 0.16, -10))


def sfx_room_clear():
    x = chime([(0.00, 74, -2), (0.09, 78, -2), (0.18, 81, -1), (0.27, 86, 0)])
    x = mix((x, 0, 0), (celesta(74), 0.27, -9), (celesta(78), 0.27, -10), (church_bell(587.33, 1.6, seed=91), 0.27, -15))
    return room(x, 0.25, 1.2, 0.25, 6000, 92)


def sfx_item_get():
    run = [(i * 0.05, m, -3 + i * 0.4) for i, m in enumerate((69, 74, 78, 81, 86, 90))]
    x = chime(run)
    x = mix((x, 0, 0), *[(celesta(m), 0.30, -8) for m in (74, 78, 81, 86)], (music_box(98), 0.34, -9),
            (church_bell(587.33, 2.0, seed=101), 0.30, -14))
    return room(x, 0.3, 1.4, 0.3, 6000, 102)


def sfx_victory():
    arp = [(i * 0.11, m, -2) for i, m in enumerate((62, 66, 69, 74, 78, 81, 86))]
    pad = sum(organ(m, 1.8, 1.0) for m in (50, 57, 62, 66)) / 4
    x = mix((chime(arp), 0, 0), (church_bell(293.66, 3.2, seed=111), 0.0, -6), (church_bell(587.33, 2.6, seed=112), 0.66, -12),
            (lp(pad, 2500), 0.05, -12), *[(celesta(m), 0.77, -9) for m in (74, 78, 81)])
    return room(x, 0.3, 1.6, 0.35, 6000, 113)


def sfx_shop_buy():
    return mix((src(RPG + "handleCoins.ogg"), 0, 0), (music_box(93), 0.12, -6), (music_box(98), 0.22, -6))


def sfx_chest_open():
    return mix((src(RPG + "metalLatch.ogg"), 0, -2), (src(RPG + "creak1.ogg"), 0.07, 0), (music_box(98), 0.45, -16),
               (music_box(102), 0.52, -18))


def sfx_urn_break():
    return mix((src(IMPACT + "impactGlass_heavy_001.ogg"), 0, 0), (src(IMPACT + "impactGlass_heavy_003.ogg"), 0.025, -3),
               (src(FOLEY + "Rocks/stonesHit1.ogg"), 0.05, -6), (src(FOLEY + "Rocks/rockHit2.ogg"), 0.09, -9),
               (src(IMPACT + "impactGlass_light_000.ogg", 0.8), 0.12, -13))


def sfx_crate_break():
    return mix((src(RPG + "chop.ogg"), 0, -3), (sat(src(IMPACT + "impactPlank_medium_000.ogg"), 2.5), 0, 0),
               (src(IMPACT + "impactWood_medium_002.ogg"), 0.03, -2), (src(IMPACT + "impactWood_light_000.ogg"), 0.08, -6),
               (src(IMPACT + "impactWood_light_003.ogg"), 0.15, -9))


def growl(dur, f_points, seed, formants_a, formants_b, sub=0.7, breathy=0.4, vib=0.0):
    n = secs(dur)
    t = t_(n)
    r = rng(seed)
    tp, fp = zip(*f_points)
    f = np.interp(t, np.array(tp) * dur, fp)
    jit = lp(r.standard_normal(n), 30)
    f = f * (1 + 0.035 * jit / (np.std(jit) + 1e-9)) * (1 + vib * np.sin(2 * np.pi * 5.5 * t))
    s = saw(f) + sub * saw(f * 0.5, 0.25)
    rough = lp(r.standard_normal(n), 70)
    s = s * (1 + 0.45 * rough / (np.std(rough) + 1e-9))
    s = s + breathy * r.standard_normal(n)
    k = lambda tt: np.clip(tt / dur, 0, 1)  # noqa: E731
    fm = [(lambda tt, a=a, b=b: a + (b - a) * k(tt), bw, g) for (a, bw, g), (b, _, _) in zip(formants_a, formants_b)]
    y = formant_filter(s, fm, floor=0.04) + 0.25 * lp(s, 250)
    return norm(y)


def sfx_boss_roar():
    fa = [(560, 110, 1.0), (840, 140, 0.75), (1850, 220, 0.4), (2600, 300, 0.2)]
    fb = [(420, 110, 1.0), (640, 140, 0.75), (1750, 220, 0.4), (2500, 300, 0.2)]
    g = growl(1.7, [(0, 78), (0.3, 118), (0.75, 96), (1.0, 62)], 121, fa, fb, sub=0.8, breathy=0.45)
    g = sat(g * env_ar(len(g), 0.09, 0.4, 1.3), 2.2) * env_ar(len(g), 0.01, 0.35, 1.0)
    x = mix((g, 0, 0), (lp(src(RETRO1 + "rumble1.ogg"), 500), 0, -9), (src(FOLEY + "Rocks/stoneDrag1.ogg", 0.6), 0.02, -14))
    return room(x, 0.2, 1.0, 0.2, 4000, 122)


def sfx_boss_die():
    fa = [(320, 90, 1.0), (800, 140, 0.6), (2300, 250, 0.25)]
    fb = [(650, 110, 1.0), (1050, 150, 0.6), (2400, 260, 0.25)]
    w = growl(2.6, [(0, 420), (0.25, 360), (0.7, 160), (1.0, 80)], 131, fa, fb, sub=0.3, breathy=0.9, vib=0.03)
    w = w * env_ar(len(w), 0.12, 0.55, 1.4)
    x = mix((w, 0.05, -1), (sat(lp(src(RETRO2 + "explosion1.ogg"), 1800), 1.8), 0, -5),
            (sat(src(IMPACT + "impactMining_004.ogg"), 3.0), 0, -3), (src(IMPACT + "impactPunch_heavy_001.ogg"), 0, -5),
            (sizzle(1.4, 132, 4000, 0.5), 0.3, -14))
    return room(x, 0.35, 2.0, 0.45, 4000, 133)


def sfx_bell_toll():
    x = church_bell(146.83, 4.3, seed=7)
    x = room(x, 0.25, 2.0, 0.5, 4500, 141)
    return x[:secs(4.3)] * env_ar(secs(4.3), 0.0005, 0.3, 1.0)


def sfx_tick():
    return clock_tick(False, seed=151)


def sfx_ui_click():
    return src(UI + "select_002.ogg")


def sfx_ui_back():
    return src(UI + "back_002.ogg")


def sfx_ui_open():
    return mix((src(RPG + "bookOpen.ogg"), 0, 0), (src(RPG + "bookFlip3.ogg"), 0.02, -10))


def sfx_low_wax():
    return heartbeat(1.0, 55.0)


def sfx_snuff_out():
    blow = breath(0.42, 161, 900, 1600, 0.05)
    n = secs(0.25)
    puff = lp(rng(162).standard_normal(n), 450) * env_ad(n, 0.01, 0.06)
    fizz = sizzle(0.75, 163, 5500, 0.22)
    return mix((blow, 0, 0), (norm(puff), 0.02, -4), (fizz, 0.18, -7), (crackle(0.5, 164, 30), 0.25, -16))


def sfx_step():
    return hp(src(IMPACT + "footstep_carpet_000.ogg"), 150)


def sfx_charge():
    dur = 0.65
    n = secs(dur)
    t = t_(n)
    sweep = band_noise(dur, 171, lambda tt: 300 * 9 ** np.clip(tt / dur, 0, 1), 1.0)
    rise = (t / dur) ** 1.6
    glide = np.sin(phase(220 * 3 ** (t / dur) * (1 + 0.02 * np.sin(2 * np.pi * (5 + 10 * t / dur) * t))))
    x = sweep * rise + 0.35 * glide * rise + 0.25 * crackle(dur, 172, 80) * rise
    return x * env_ar(n, 0.02, 0.06, 1.0)


def sfx_teleport():
    dur = 0.75
    n = secs(dur)
    t = t_(n)
    r = rng(181)
    sh = np.zeros(n)
    for f0 in r.uniform(1300, 3600, 7):
        sh += np.sin(phase(f0 * 2 ** (t / 0.6))) * (0.5 + 0.5 * np.sin(2 * np.pi * r.uniform(9, 16) * t + r.uniform(0, 6)))
    sh = norm(sh) * env_ar(n, 0.25, 0.55, 1.5)
    rw = src(FOLEY + "Woosh/woosh2.ogg", 0.6, rev=True)
    return room(mix((rw, 0, 0), (sh, 0.05, -5), (band_noise(dur, 182, lambda tt: 600 * 6 ** np.clip(tt / dur, 0, 1), 1.0)
                                                  * env_ar(n, 0.3, 0.5), 0, -8)), 0.3, 0.9, 0.2, 6000, 183)


def sfx_splash():
    return mix((src(FOLEY + "Water/sinkWater1.ogg"), 0, 0), (src(FOLEY + "Water/drip2.ogg"), 0, -4),
               (band_noise(0.15, 191, 1800, 1.5) * env_ad(secs(0.15), 0.002, 0.04), 0, -8))


def sfx_trapdoor():
    return mix((src(RPG + "creak2.ogg"), 0, -2), (sat(src(IMPACT + "impactWood_heavy_000.ogg"), 2.5), 0.32, 0),
               (src(RPG + "doorClose_3.ogg"), 0.32, -4), (src(FOLEY + "Woosh/woosh3.ogg", 0.55), 0.40, -6))


# name: (recipe, loudness target, peak cap dBFS, max length s). Loudness = max 100 ms RMS of a phone-weighted
# signal; louder targets for big events, quieter for UI / steps (the game also applies its own VOLUME table).
SFX = {
    "shoot": (sfx_shoot, -15, -3, 0.24), "hit_wall": (sfx_hit_wall, -16, -3, 0.26),
    "hit_enemy": (sfx_hit_enemy, -15, -3, 0.30), "enemy_die": (sfx_enemy_die, -14, -3, 0.60),
    "enemy_shoot": (sfx_enemy_shoot, -15, -3, 0.26), "player_hurt": (sfx_player_hurt, -13, -3, 0.45),
    "wax_pickup": (sfx_wax_pickup, -15, -3, 0.70), "coin_pickup": (sfx_coin_pickup, -15, -3, 0.40),
    "bomb_pickup": (sfx_bomb_pickup, -15, -3, 0.45), "bomb_place": (sfx_bomb_place, -15, -3, 0.85),
    "explosion": (sfx_explosion, -10, -1, 1.70), "door_open": (sfx_door_open, -15, -3, 1.00),
    "door_close": (sfx_door_close, -14, -3, 0.75), "room_clear": (sfx_room_clear, -14, -3, 1.80),
    "item_get": (sfx_item_get, -13, -3, 2.00), "chest_open": (sfx_chest_open, -15, -3, 1.20),
    "urn_break": (sfx_urn_break, -14, -3, 0.60), "crate_break": (sfx_crate_break, -14, -3, 0.60),
    "boss_roar": (sfx_boss_roar, -10, -1, 2.00), "boss_die": (sfx_boss_die, -10, -1, 3.30),
    "bell_toll": (sfx_bell_toll, -11, -1.5, 4.30), "tick": (sfx_tick, -19, -3, 0.08),
    "ui_click": (sfx_ui_click, -19, -3, 0.10), "ui_back": (sfx_ui_back, -19, -3, 0.12),
    "ui_open": (sfx_ui_open, -18, -3, 0.30), "low_wax": (sfx_low_wax, -13, -3, 0.80),
    "snuff_out": (sfx_snuff_out, -13, -3, 1.10), "victory": (sfx_victory, -12, -2, 3.00),
    "shop_buy": (sfx_shop_buy, -15, -3, 1.00), "step": (sfx_step, -21, -3, 0.11),
    "charge": (sfx_charge, -15, -3, 0.70), "teleport": (sfx_teleport, -15, -3, 1.00),
    "splash": (sfx_splash, -16, -3, 0.60), "trapdoor": (sfx_trapdoor, -14, -3, 1.30),
}


def loudness(x):
    """Rough perceived loudness for a phone speaker: drop lows, lift presence, max RMS over 100 ms."""
    y = hp(x, 120, 2)
    y = y + 0.6 * hp(y, 2000, 1)
    w = secs(0.1)
    p = np.convolve(y ** 2, np.ones(w) / w, "full")
    return 10 * np.log10(np.max(p) + 1e-12)


def decode(path, ch=1):
    r = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-ac", str(ch), "-f", "f32le", "-"],
                       capture_output=True, check=True)
    x = np.frombuffer(r.stdout, np.float32).astype(np.float64)
    return x.reshape(-1, ch) if ch > 1 else x


def build_sfx(name):
    global _CUR
    fn, target, cap, maxlen = SFX[name]
    _CUR = []
    x = hp(np.asarray(fn(), float), 25, 1)
    USED[name] = sorted(set(_CUR))
    pk = peak(x)
    idx = np.where(np.abs(x) > pk * db(-48))[0]
    a = max(0, idx[0] - secs(0.001))
    end_nat = np.where(np.abs(x) > pk * db(-54))[0][-1] + 1
    b = min(end_nat, a + secs(maxlen))
    dur = (b - a) / SR
    fade = min(0.35 * dur, 0.12) if b == end_nat else min(0.4 * dur, 0.2)
    fn_ = secs(fade)

    def faded():
        s_ = x[a:b].copy()
        s_[-fn_:] *= np.linspace(1, 0, fn_)
        return s_
    seg = faded()
    short = (target - loudness(seg)) - (cap - 20 * np.log10(peak(seg)))
    if short > 1.0:  # peak-limited: shave the transient a little so it can reach its loudness
        x = limiter(x[:, None], 20 * np.log10(pk) - min(short, 6.0), False, hold_ms=1.5)[:, 0]
        seg = faded()
    g = min(target - loudness(seg), cap - 20 * np.log10(peak(seg)))
    wav = os.path.join(TMP, name + ".wav")
    wavfile.write(wav, SR, x.astype(np.float32))
    out = os.path.join(SFX_OUT, name + ".ogg")
    for _ in range(3):
        af = (f"atrim=start={a / SR:.5f}:end={b / SR:.5f},asetpts=N/SR/TB,afade=t=in:st=0:d=0.002,"
              f"afade=t=out:st={dur - fade:.5f}:d={fade:.5f},volume={g:.2f}dB")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-af", af, "-ac", "1", "-ar", str(SR),
                        "-c:a", "libvorbis", "-q:a", "5", out], check=True)
        y = decode(out)
        over = 20 * np.log10(peak(y)) - cap
        if over <= 0.1:
            break
        g -= over + 0.1
    print(f"  {name:12s} {len(y) / SR:5.2f}s  peak {20 * np.log10(peak(y)):6.1f} dBFS  loud {loudness(y):6.1f}  "
          f"gain {g:+5.1f} dB  {os.path.getsize(out) // 1024:3d} KB")


# =============================================================================================== music engine
def reverb_ir(dur=3.0, tau=0.75, seed=1, predelay=0.014, hf_damp=3500.0):
    """Exponential-decay noise impulse; high frequencies die faster (STFT mask)."""
    n = secs(dur)
    x = rng(seed).standard_normal(n)
    y = spec_mask(x, lambda f, t: np.exp(-t / (tau / (1 + f / hf_damp))) * (1 / (1 + (f / 9000) ** 2)), nper=512)
    y = np.concatenate([np.zeros(secs(predelay)), y])
    return y / np.sqrt(np.sum(y ** 2))


class Song:
    def __init__(self, bpm, bars, beats_per_bar=3, loop=True, tail=8.0, length_s=None):
        self.spb = 60.0 / bpm
        self.bpb = beats_per_bar
        self.loop = loop
        self.loop_len = secs(length_s) if length_s else int(round(bars * beats_per_bar * self.spb * SR))
        self.L = self.loop_len + secs(tail)
        self.buses = {}

    def add(self, bus, beat, x, gain=1.0, pan=0.0, sec=None):
        st = secs(sec) if sec is not None else int(round(beat * self.spb * SR))
        b = self.buses.setdefault(bus, np.zeros((self.L, 2)))
        st = max(st, 0)
        end = min(self.L, st + len(x))
        if end <= st:
            return
        seg = x[:end - st] * gain
        b[st:end, 0] += seg * np.cos((pan + 1) * np.pi / 4)
        b[st:end, 1] += seg * np.sin((pan + 1) * np.pi / 4)

    def render(self, sends, rev_tau=0.8, rev_dur=3.2, wet=1.0, target_rms=-16.0, ceiling=-1.6):
        dry = np.zeros((self.L, 2))
        rin = np.zeros((self.L, 2))
        for name, b in self.buses.items():
            g, s = sends.get(name, (1.0, 0.25))
            dry += b * g
            rin += b * g * s
        if os.environ.get("AUDIO_DEBUG"):
            tot = np.sqrt(np.mean(dry ** 2))
            print("    buses (dB rel. mix, full / above 300 Hz):", ", ".join(
                f"{k} {20 * np.log10(np.sqrt(np.mean((b * sends.get(k, (1, 0))[0]) ** 2)) / tot):.0f}"
                f"/{20 * np.log10(np.sqrt(np.mean(hp(b * sends.get(k, (1, 0))[0], 300) ** 2)) / tot + 1e-12):.0f}"
                for k, b in self.buses.items()))
        wl = signal.fftconvolve(rin[:, 0], reverb_ir(rev_dur, rev_tau, 11))
        wr = signal.fftconvolve(rin[:, 1], reverb_ir(rev_dur, rev_tau, 23))
        out = np.zeros((len(wl), 2))
        out[:self.L] += dry
        out[:, 0] += wl * wet
        out[:, 1] += wr * wet
        if self.loop:  # wrap everything after the loop end back onto the start -> seamless
            y = np.zeros((self.loop_len, 2))
            for k in range(0, len(out), self.loop_len):
                seg = out[k:k + self.loop_len]
                y[:len(seg)] += seg
        else:
            e = np.where(np.max(np.abs(out), 1) > peak(out) * db(-70))[0][-1] + 1
            y = out[:e]
            fl = min(secs(0.6), len(y) // 4)
            y[-fl:] *= np.linspace(1, 0, fl)[:, None] ** 2
        return master(y, self.loop, target_rms, ceiling)


def master(y, loop, target_rms=-16.0, ceiling=-1.6):
    # DC / rumble removal (circular for loops so the seam stays continuous)
    if loop:
        pre = min(len(y), secs(3))
        z = hp(np.concatenate([y[-pre:], y]), 28, 2)[pre:]
    else:
        z = hp(y, 28, 2)
    base, gtot = z, 1.0
    for _ in range(6):
        rms = 20 * np.log10(np.sqrt(np.mean(z ** 2)))
        gtot *= db(target_rms - rms)
        z = limiter(base * gtot, ceiling, loop)
    gr = 20 * np.log10(np.maximum(np.max(np.abs(z), 1), 1e-12) / np.maximum(np.max(np.abs(base * gtot), 1), 1e-12))
    print(f"    limiter: max {gr.min():.1f} dB, >1 dB on {np.mean(gr < -1) * 100:.2f}% of samples", end="")
    return z


def limiter(y, ceiling_db, loop, hold_ms=6.0):
    """Look-ahead peak limiter: min-filter then equal-width box smoothing (never overshoots)."""
    thr = db(ceiling_db)
    a = np.max(np.abs(y), axis=1)
    r = np.minimum(1.0, thr / np.maximum(a, 1e-9))
    mode = "wrap" if loop else "nearest"
    w = 2 * secs(hold_ms / 1000) + 1
    g = ndimage.minimum_filter1d(r, w, mode=mode)
    g = ndimage.uniform_filter1d(g, w, mode=mode)
    return y * g[:, None]


def export_music(name, y):
    wav = os.path.join(TMP, name + ".wav")
    out = os.path.join(MUSIC_OUT, name + ".ogg")
    gain = 1.0
    for _ in range(4):
        wavfile.write(wav, SR, (y * gain).astype(np.float32))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", out], check=True)
        z = decode(out, 2)
        pk = 20 * np.log10(peak(z))
        if pk <= -1.05:
            break
        gain *= db(-1.15 - pk)
    rms = 20 * np.log10(np.sqrt(np.mean(z ** 2)))
    print(f"  {name:15s} {len(z) / SR:6.2f}s  rms {rms:6.1f} dBFS  peak {pk:5.1f} dBFS  {os.path.getsize(out) // 1024:5d} KB")


# =============================================================================================== composition
# Chords in D minor: name -> (bass pitch class, chord pitch classes, pitch classes a 3-voice voicing must contain)
CH = {
    "Dm": (2, [2, 5, 9], [2, 5, 9]), "A/C#": (1, [9, 1, 4], [9, 1, 4]), "Am/C": (0, [9, 0, 4], [9, 0, 4]),
    "G/B": (11, [7, 11, 2], [7, 11, 2]), "Gm/Bb": (10, [7, 10, 2], [7, 10, 2]), "A7": (9, [9, 1, 4, 7], [1, 7]),
    "A7b9": (9, [9, 1, 7, 10], [1, 7, 10]), "F": (5, [5, 9, 0], [5, 9, 0]), "C7/E": (4, [0, 4, 7, 10], [4, 10]),
    "Bb": (10, [10, 2, 5], [10, 2, 5]), "F/A": (9, [5, 9, 0], [5, 9, 0]), "Gm": (7, [7, 10, 2], [7, 10, 2]),
    "Eb": (3, [3, 7, 10], [3, 7, 10]), "A": (9, [9, 1, 4], [9, 1, 4]), "D": (2, [2, 6, 9], [2, 6, 9]),
    "C": (0, [0, 4, 7], [0, 4, 7]),
}
# The waltz theme (3/4, D minor). Per bar: (beat, midi, beats). Lament bass D-C#-C-B-Bb-A under phrase A.
CHORDS_A = ["Dm", "A/C#", "Am/C", "G/B", "Gm/Bb", "A7", "Dm", "A7"]
CHORDS_A2 = ["Dm", "A/C#", "Am/C", "G/B", "Gm/Bb", "A7", "Dm", "Dm"]
CHORDS_B = ["F", "C7/E", "Dm", "A/C#", "Bb", "F/A", "Gm", "A7"]
MEL_A = [[(0, 81, 1.5), (1.5, 79, .5), (2, 77, 1)], [(0, 76, 1.5), (1.5, 77, .5), (2, 79, 1)],
         [(0, 76, 1), (1, 81, 2)], [(0, 79, 1.5), (1.5, 77, .5), (2, 74, 1)],
         [(0, 74, 1), (1, 79, 1), (2, 82, 1)], [(0, 81, 1.5), (1.5, 79, .5), (2, 76, 1)],
         [(0, 77, 1), (1, 76, 1), (2, 74, 1)], [(0, 73, 1.5), (1.5, 74, .5), (2, 76, 1)]]
MEL_A2 = [[(0, 81, 1.5), (1.5, 79, .5), (2, 77, 1)], [(0, 76, 1.5), (1.5, 77, .5), (2, 79, 1)],
          [(0, 81, 1), (1, 84, 1.5), (2.5, 83, .5)], [(0, 83, 1.5), (1.5, 81, .5), (2, 79, 1)],
          [(0, 82, 1.5), (1.5, 81, .5), (2, 79, 1)], [(0, 79, 1), (1, 76, 1), (2, 73, 1)],
          [(0, 74, 2), (2, 69, 1)], [(0, 74, 3)]]
MEL_B = [[(0, 84, 1.5), (1.5, 81, .5), (2, 77, 1)], [(0, 79, 1.5), (1.5, 81, .5), (2, 82, 1)],
         [(0, 81, 2), (2, 77, 1)], [(0, 76, 1.5), (1.5, 74, .5), (2, 73, 1)],
         [(0, 74, 1), (1, 77, 1), (2, 82, 1)], [(0, 81, 1.5), (1.5, 79, .5), (2, 77, 1)],
         [(0, 79, 1), (1, 82, 1), (2, 86, 1)], [(0, 85, 1.5), (1.5, 82, .5), (2, 81, 1)]]
# counter-melodies (celesta): chromatic lament line for A, a slow descant for B
CTR_A = [[(0, 74, 3)], [(0, 73, 3)], [(0, 72, 3)], [(0, 71, 3)], [(0, 70, 3)], [(0, 69, 3)], [(0, 65, 3)],
         [(0, 64, 1.5), (1.5, 67, 1.5)]]
CTR_B = [[(0, 69, 3)], [(0, 70, 3)], [(0, 69, 3)], [(0, 67, 3)], [(0, 65, 3)], [(0, 72, 3)], [(0, 70, 3)],
         [(0, 69, 1.5), (1.5, 73, 1.5)]]
SECTIONS = {"A": (CHORDS_A, MEL_A, CTR_A), "A2": (CHORDS_A2, MEL_A2, CTR_A), "B": (CHORDS_B, MEL_B, CTR_B),
            "A3": (CHORDS_A, MEL_A, CTR_A)}


def chord(name, key):
    b, pcs, req = CH[name]
    return (b + key) % 12, [(p + key) % 12 for p in pcs], [(p + key) % 12 for p in req]


def voice(pcs, req, prev, lo, hi, n=3):
    """Pick an n-note voicing in [lo, hi] containing `req`, moving as little as possible from `prev`."""
    notes = [m for m in range(lo, hi + 1) if m % 12 in pcs]
    best, bc = None, 1e9
    for combo in itertools.combinations(notes, n):
        s = {c % 12 for c in combo}
        if not set(req) <= s or len(s) < min(n, len(pcs)):
            continue
        span = combo[-1] - combo[0]
        cost = max(0, span - 9) * 0.6 + 0.08 * abs(np.mean(combo) - (lo + hi) / 2)
        if prev is not None:
            cost += sum(abs(a - b) for a, b in zip(combo, prev))
        if cost < bc:
            best, bc = combo, cost
    return list(best)


def nearest(pc, prev, lo, hi):
    cands = [m for m in range(lo, hi + 1) if m % 12 == pc]
    return min(cands, key=lambda m: abs(m - prev))


def waltz(cfg):
    key, bpm, form = cfg["key"], cfg["bpm"], cfg["form"]
    bars = 8 * len(form)
    s = Song(bpm, bars, 3)
    r = rng(cfg.get("seed", 1))
    spb = s.spb
    prev_acc = prev_pad = prev_hi = None
    prev_b = 50 + key - (12 if key > 3 else 0)
    for si, sec in enumerate(form):
        chords, mel, ctr = SECTIONS[sec]
        for b in range(8):
            bar = si * 8 + b
            b0 = bar * 3
            cname = chords[b]
            if cfg.get("b9") and cname == "A7":
                cname = "A7b9"
            bpc, pcs, req = chord(cname, key)
            bass = nearest(bpc, prev_b, 40, 56)
            prev_b = bass
            acc = voice(pcs, req, prev_acc, 62, 76)
            prev_acc = acc
            pad = voice(pcs, req, prev_pad, 52, 67)
            prev_pad = pad
            bar_s = 3 * spb
            # --- bass "oom" (pizzicato) + a long, soft bowed bass under it
            s.add("bass", b0, pizz(bass, 1.0), cfg.get("pizz", 0.42))
            s.add("pad", b0, strings(bass - 12, bar_s, 1.0, bright=500, attack=0.3, release=0.8, seed=bar), cfg.get("lowstr", 0.22))
            # --- pad
            pk = cfg.get("pad", "strings")
            for i, m in enumerate(pad):
                if pk in ("strings", "both"):
                    s.add("pad", b0, strings(m, bar_s, 1.0, bright=1100, attack=0.5, release=0.9, seed=bar * 3 + i),
                          cfg.get("pad_gain", 0.09), pan=(i - 1) * 0.45)
                if pk in ("organ", "both"):
                    s.add("organ", b0, organ(m, bar_s, 1.0, 0.25, 0.6), cfg.get("organ_gain", 0.10), pan=(i - 1) * 0.3)
            if cfg.get("drone"):
                s.add("organ", b0, organ(50 + key - 12, bar_s, 1.0, 0.3, 0.6), cfg["drone"])
            # --- waltz "pah pah" on beats 2 and 3, or a spinning music-box arpeggio
            arp = sec in cfg.get("arp", ())
            if arp:
                tones = sorted({m for m in range(69, 89) if m % 12 in pcs})[:4]
                for k, idx in enumerate((0, 1, 2, 3, 2, 1)):
                    jt = r.normal(0, 0.006) / spb
                    s.add("box", b0 + k * 0.5 + jt, music_box(tones[idx], 0.62 if k == 0 else 0.45), cfg.get("arp_gain", 0.32),
                          pan=0.3 * np.sin(k + bar))
            elif cfg.get("pahpah", True):
                for beat in (1, 2):
                    for i, m in enumerate(acc):
                        s.add("acc", b0 + beat + r.normal(0, 0.004) / spb, music_box(m, 0.9), cfg.get("acc_gain", 0.13),
                              pan=-0.25 + 0.1 * i)
            # --- melody / counter-melody
            for inst, octv, gain in cfg["mel"].get(sec, []):
                for beat, m, d in mel[b]:
                    fn = music_box if inst == "box" else celesta
                    s.add("mel", b0 + beat + r.normal(0, 0.005) / spb, fn(m + key + 12 * octv, 1.0 + r.normal(0, 0.05)),
                          gain, pan=0.12 if inst == "box" else 0.35)
            for inst, octv, gain in cfg.get("ctr", {}).get(sec, []):
                for beat, m, d in ctr[b]:
                    fn = music_box if inst == "box" else celesta
                    s.add("ctr", b0 + beat, fn(m + key + 12 * octv), gain, pan=-0.35)
            # --- pulsing low strings (eighth notes, accent on the downbeat)
            if cfg.get("pulse") and sec in cfg.get("pulse_secs", ("A", "A2", "B", "A3")):
                for k in range(6):
                    m = bass + (1 if cfg.get("pulse_b2") and k == 4 else 0)
                    s.add("pulse", b0 + k * 0.5, spiccato(m, 0.42 * spb, 1.0 if k == 0 else 0.6, bright=900), cfg["pulse"])
            # --- tense tremolo strings up high
            if sec in cfg.get("trem", ()):
                hi = voice(pcs, req, prev_hi, 69, 82, 2 if len(req) < 3 else 3)
                prev_hi = hi
                for i, m in enumerate(hi):
                    s.add("trem", b0, strings(m, bar_s, 1.0, bright=2600, attack=0.4, release=0.6, trem=0.7,
                                              trem_hz=7.5, seed=bar * 5 + i), cfg.get("trem_gain", 0.05),
                          pan=0.5 if i % 2 else -0.5)
            # --- heartbeat
            hb = cfg.get("heart")
            if hb == "every2" and bar % 2 == 0 or hb == "every":
                s.add("heart", b0, heartbeat(1.0), cfg.get("heart_gain", 0.5))
            elif hb == "twice":
                s.add("heart", b0, heartbeat(1.0), cfg.get("heart_gain", 0.5))
                s.add("heart", b0 + 1.5, heartbeat(0.75), cfg.get("heart_gain", 0.5))
            # --- clock ticks
            tk = cfg.get("tick")
            if tk == "beats" or (tk == "title" and (bar < 4 or 24 <= bar < 28)):
                for beat in range(3):
                    s.add("tick", b0 + beat, clock_tick(beat % 2 == 1, seed=bar * 3 + beat), cfg.get("tick_gain", 0.05), pan=0.5)
            elif tk == "sparse" and bar % 2 == 0:
                s.add("tick", b0, clock_tick(False, seed=bar), cfg.get("tick_gain", 0.05), pan=0.5)
                s.add("tick", b0 + 1, clock_tick(True, seed=bar + 99), cfg.get("tick_gain", 0.05) * 0.7, pan=0.5)
            # --- bells
            if bar in cfg.get("bells", ()):
                s.add("bell", b0, church_bell(midi_hz(50 + key - 12), 6.0, seed=bar), cfg.get("bell_gain", 0.3))
                s.add("bell", b0 + 1.5, church_bell(midi_hz(62 + key), 4.0, seed=bar + 1), cfg.get("bell_gain", 0.3) * 0.4, pan=0.3)
    sends = {"box": (1.0, 0.45), "mel": (1.0, 0.45), "acc": (1.0, 0.4), "ctr": (1.0, 0.5), "pad": (1.0, 0.45),
             "organ": (1.0, 0.5), "bass": (1.0, 0.2), "pulse": (1.0, 0.25), "trem": (1.0, 0.5), "heart": (1.0, 0.15),
             "tick": (1.0, 0.35), "bell": (1.0, 0.45)}
    return s.render(sends, rev_tau=cfg.get("rev_tau", 0.9))


def song_title():
    return waltz(dict(key=0, bpm=84, form=("A", "A2", "B", "A3"), seed=1, pad="both", organ_gain=0.05,
                      mel={"A": [("box", 0, 0.5)], "A2": [("box", 0, 0.5)], "B": [("box", 0, 0.5)],
                           "A3": [("box", 0, 0.5), ("cel", -1, 0.16)]},
                      ctr={"B": [("cel", 0, 0.2)]}, tick="title", tick_gain=0.07))


def song_floor_1():  # The Cellar: E minor, calm
    return waltz(dict(key=2, bpm=88, form=("A", "B", "A3"), seed=2, pad="strings",
                      mel={"A": [("box", 0, 0.5)], "B": [("box", 0, 0.5)], "A3": [("box", 0, 0.5)]},
                      ctr={"B": [("cel", 0, 0.22)], "A3": [("cel", 0, 0.16)]}, tick="sparse", tick_gain=0.05))


def song_floor_2():  # The Crypt: C minor, pulsing low strings + slow heartbeat
    return waltz(dict(key=-2, bpm=92, form=("A", "A2", "B", "A3"), seed=3, pad="strings", pad_gain=0.08,
                      mel={"A": [("box", 0, 0.48)], "A2": [("cel", 0, 0.42)], "B": [("box", 0, 0.48)],
                           "A3": [("box", 0, 0.48)]},
                      ctr={"A2": [("box", -1, 0.12)], "B": [("cel", 0, 0.2)], "A3": [("cel", 0, 0.2)]},
                      pulse=0.10, heart="every2", heart_gain=0.42, tick="sparse", tick_gain=0.04))


def song_floor_3():  # The Chapel: F minor, organ, tremolo strings, heartbeat, ticking
    return waltz(dict(key=3, bpm=100, form=("A", "A2", "B", "A3"), seed=4, pad="organ", organ_gain=0.11,
                      arp=("A", "A3"), arp_gain=0.27, drone=0.06,
                      mel={"A": [("cel", -1, 0.34)], "A2": [("box", 0, 0.46)], "B": [("box", 0, 0.46)],
                           "A3": [("box", 0, 0.42)]},
                      ctr={"A2": [("cel", 0, 0.2)], "B": [("cel", 0, 0.2)]},
                      trem=("B", "A3"), trem_gain=0.045, pulse=0.07, heart="every", heart_gain=0.42,
                      tick="beats", tick_gain=0.035))


def song_floor_4():  # The Belfry: Eb minor, everything + bells, b9 dominants, double heartbeat
    return waltz(dict(key=1, bpm=108, form=("A", "A2", "B", "A3"), seed=5, pad="both", organ_gain=0.06, pad_gain=0.08,
                      arp=("A", "A2", "B", "A3"), arp_gain=0.22, b9=True, drone=0.05,
                      mel={"A": [("cel", -1, 0.36)], "A2": [("box", 0, 0.44)], "B": [("box", 0, 0.44), ("cel", -1, 0.18)],
                           "A3": [("box", 0, 0.42), ("cel", -1, 0.2)]},
                      ctr={"B": [("cel", 0, 0.16)]},
                      trem=("A2", "B", "A3"), trem_gain=0.05, pulse=0.10, pulse_b2=True, heart="twice", heart_gain=0.4,
                      tick="beats", tick_gain=0.04, bells=(0, 8, 16, 24), bell_gain=0.22))


BOSS_THEME = [[(0, 74, 1.5), (1.5, 76, .5), (2, 77, 1), (3, 81, 1)], [(0, 82, 2), (2, 81, 1), (3, 77, 1)],
              [(0, 79, 1.5), (1.5, 77, .5), (2, 74, 2)], [(0, 76, 1.5), (1.5, 77, .5), (2, 76, 1), (3, 73, 1)]]
FINAL_THEME = [BOSS_THEME[0], BOSS_THEME[1], [(0, 79, 1.5), (1.5, 77, .5), (2, 75, 2)], BOSS_THEME[3]]


def boss(final=False):
    bpm = 152 if final else 138
    prog = ["Dm", "Bb", "Eb", "A"] if final else ["Dm", "Bb", "Gm", "A"]
    theme = FINAL_THEME if final else BOSS_THEME
    s = Song(bpm, 32, 4)
    r = rng(77 if final else 66)
    spb = s.spb
    prev_b, prev_pad, prev_hi = 50, None, None
    for bar in range(32):
        sec = bar // 8
        b0 = bar * 4
        bpc, pcs, req = chord(prog[bar % 4], 0)
        R = nearest(bpc, prev_b, 43, 52)
        prev_b = R
        # ostinato, 3+3+2 accents
        for k, iv in enumerate((0, 0, 12, 0, 0, 12, 7, 12)):
            acc = k in (0, 3, 6)
            s.add("ost", b0 + k * 0.5, spiccato(R + iv, 0.5 * spb * 0.8, 1.0 if acc else 0.55, bright=2000), 0.30, pan=-0.15)
            if acc:
                s.add("ost", b0 + k * 0.5, pizz(R - 12, 0.8), 0.35)
        # drums: toms on the accents, deep drum each phrase, fills
        for pos, f0, g in ((0, 82, 0.9), (1.5, 82, 0.65), (3, 82, 0.7)):
            s.add("drums", b0 + pos, tom(f0, 1.0, seed=bar), g)
        if bar % 2 == 1:
            s.add("drums", b0 + 3.5, tom(125, 1.0, 0.2, seed=bar + 50), 0.45, pan=0.3)
        if bar % 4 == 0:
            s.add("drums", b0, tom(52, 1.0, 0.5, seed=bar + 90), 0.9)
        if bar % 8 == 7 or (final and bar % 4 == 3):
            for i, f0 in enumerate((170, 160, 140, 130, 115, 105, 95, 85)):
                s.add("drums", b0 + 2 + i * 0.25, tom(f0, 1.0, 0.18, seed=bar * 9 + i), 0.35 + 0.05 * i, pan=0.4 - 0.1 * i)
        if sec >= 1:
            for beat in (1, 3):
                s.add("drums", b0 + beat, norm(hp(rng(bar + beat).standard_normal(secs(0.12)), 1800)) * env_ad(secs(0.12), 0.001, 0.03),
                      0.12 if not final else 0.16, pan=0.2)
        # low string pad
        pad = voice(pcs, req, prev_pad, 50, 64)
        prev_pad = pad
        for i, m in enumerate(pad):
            s.add("pad", b0, strings(m, 4 * spb, 1.0, bright=900, attack=0.25, release=0.5, seed=bar * 3 + i), 0.08, pan=(i - 1) * 0.5)
        # tense high tremolo strings
        if sec >= 1:
            hi = voice(pcs, req, prev_hi, 69, 82)
            prev_hi = hi
            for i, m in enumerate(hi):
                s.add("trem", b0, strings(m, 4 * spb, 1.0, bright=3000, attack=0.15, release=0.4, trem=0.6, trem_hz=11,
                                          seed=bar * 7 + i), 0.045 + 0.01 * sec, pan=-0.5 + 0.5 * i)
        # theme: low brass + strings, octave doubling in the last section
        if sec >= 2:
            for beat, m, d in theme[bar % 4]:
                s.add("brass", b0 + beat, brass(m - 12, d * spb * 0.92), 0.17, pan=0.1)
                s.add("lead", b0 + beat, strings(m, d * spb * 0.95, 1.0, bright=3200, attack=0.04, release=0.25, vib=0.006,
                                                 seed=bar * 11 + int(beat * 2)), 0.11, pan=-0.1)
                if sec == 3:
                    s.add("lead", b0 + beat, strings(m + 12, d * spb * 0.95, 1.0, bright=4000, attack=0.04, release=0.25,
                                                     vib=0.006, seed=bar * 13 + int(beat * 2)), 0.05, pan=0.3)
        # the waltz motif on a music box, eerily, over the ostinato
        if sec == 0 and bar >= 4 or sec == 1 and final:
            for beat, m, d in theme[bar % 4]:
                s.add("box", b0 + beat, music_box(m + 12, 0.9), 0.22, pan=0.35)
        # final boss: the bell tolls, the clock ticks, high 16th arpeggios
        if final:
            if bar % 4 == 0:
                s.add("bell", b0, church_bell(146.83, 6.0, seed=bar), 0.5)
                if sec >= 2:
                    s.add("bell", b0 + 2, church_bell(293.66, 4.0, seed=bar + 3), 0.18, pan=0.3)
            for k in range(8):
                s.add("tick", b0 + k * 0.5, clock_tick(k % 2 == 1, seed=bar * 8 + k), 0.05, pan=0.55)
            if sec >= 2:
                tones = sorted({m for m in range(74, 92) if m % 12 in pcs})[:4]
                for k in range(16):
                    m = tones[(0, 1, 2, 3, 2, 1, 2, 3)[k % 8]]
                    s.add("arp", b0 + k * 0.25, spiccato(m, 0.2 * spb, 0.8 if k % 4 == 0 else 0.5, bright=4500), 0.05,
                          pan=0.4 * np.sin(k))
        else:
            if sec >= 2:
                for k in range(8):
                    s.add("tick", b0 + k * 0.5, clock_tick(k % 2 == 1, seed=bar * 8 + k), 0.03, pan=0.55)
        _ = r
    sends = {"ost": (1.0, 0.15), "drums": (1.0, 0.18), "pad": (1.0, 0.4), "trem": (1.0, 0.45), "brass": (1.0, 0.3),
             "lead": (1.0, 0.35), "box": (1.0, 0.5), "bell": (1.0, 0.4), "tick": (1.0, 0.3), "arp": (1.0, 0.3)}
    return s.render(sends, rev_tau=0.7, rev_dur=2.8)


def song_boss():
    return boss(False)


def song_final_boss():
    return boss(True)


def song_victory_jingle():
    s = Song(60, 5, 1, loop=False, tail=4.0, length_s=4.6)
    seq = [(0.0, ["Bb"], (62, 65, 70)), (0.45, ["C"], (64, 67, 72)), (0.9, ["D"], (66, 69, 74, 78))]
    for t0, (cn,), notes in seq:
        bpc, pcs, req = chord(cn, 0)
        for i, m in enumerate(notes):
            s.add("box", 0, music_box(m + 12, 0.9), 0.45, pan=0.2 * (i - 1), sec=t0 + i * 0.1)
        dur = 0.45 if t0 < 0.9 else 3.0
        for i, m in enumerate(voice(pcs, req, None, 55, 69)):
            s.add("pad", 0, strings(m, dur, 1.0, bright=1600, attack=0.08, release=0.8, seed=i + int(t0 * 10)), 0.12,
                  pan=(i - 1) * 0.5, sec=t0)
        s.add("bass", 0, pizz(nearest(bpc, 46, 40, 52)), 0.6, sec=t0)
    for i, m in enumerate((74, 78, 81, 86)):
        s.add("cel", 0, celesta(m, 1.0), 0.22, pan=0.4 - 0.25 * i, sec=1.35 + i * 0.06)
    s.add("bass", 0, strings(38, 3.0, 1.0, bright=500, attack=0.1, release=1.0), 0.3, sec=0.9)
    s.add("organ", 0, sum(organ(m, 3.0, 1.0, 0.2, 0.9) for m in (50, 57, 62, 66)) / 4, 0.25, sec=0.9)
    s.add("bell", 0, church_bell(293.66, 4.0, seed=5), 0.35, sec=0.9)
    s.add("bell", 0, church_bell(587.33, 3.0, seed=6), 0.12, pan=0.3, sec=1.6)
    return s.render({"box": (1.0, 0.4), "pad": (1.0, 0.4), "bass": (1.0, 0.2), "cel": (1.0, 0.5), "organ": (1.0, 0.5),
                     "bell": (1.0, 0.45)}, rev_tau=0.9, target_rms=-17.0)


def song_death_jingle():
    s = Song(60, 4, 1, loop=False, tail=3.0, length_s=3.4)
    # the music box winds down: notes come later and later and sag in pitch
    times = (0.0, 0.32, 0.68, 1.10, 1.62)
    notes = (81, 77, 74, 73, 62)
    sag = (0.0, -0.08, -0.2, -0.38, -0.85)
    for tt, m, sg in zip(times, notes, sag):
        s.add("box", 0, music_box(m + sg, 0.95), 0.5, pan=0.1, sec=tt)
    s.add("box", 0, music_box(50 - 0.85, 0.5), 0.3, sec=1.62)
    for i, m in enumerate((50, 53, 57)):
        s.add("pad", 0, strings(m, 1.7, 1.0, bright=800, attack=0.3, release=1.2, seed=i), 0.12, pan=(i - 1) * 0.5, sec=0.0)
    s.add("pad", 0, strings(38, 1.9, 1.0, bright=400, attack=0.3, release=1.2), 0.25, sec=0.0)
    s.add("breath", 0, breath(1.1, 201, 700, 1400, 0.15), 0.35, sec=2.15)
    return s.render({"box": (1.0, 0.45), "pad": (1.0, 0.4), "breath": (1.0, 0.25)}, rev_tau=0.9, target_rms=-18.0)


MUSIC = {
    "title": song_title, "floor_1": song_floor_1, "floor_2": song_floor_2, "floor_3": song_floor_3,
    "floor_4": song_floor_4, "boss": song_boss, "final_boss": song_final_boss,
    "victory_jingle": song_victory_jingle, "death_jingle": song_death_jingle,
}


# =============================================================================================== credits
KENNEY_LICENSE = """{name}

Created/distributed by Kenney (www.kenney.nl)

License: (Creative Commons Zero, CC0)
http://creativecommons.org/publicdomain/zero/1.0/

This content is free to use in personal, educational and commercial projects.
Support us by crediting Kenney or www.kenney.nl (this is not mandatory)

Source: {pack} (as downloaded to {packs}/{pack}). The License.txt shipped in that download was empty,
so this file restates Kenney's standard CC0 licence for the pack.
"""


def write_credits():
    os.makedirs(LIC_OUT, exist_ok=True)
    packs = sorted({rel.split("/")[0] for rels in USED.values() for rel in rels})
    for p in packs:
        name, fn = PACK_INFO[p]
        srcfile = os.path.join(PACKS, p, "audio", "License.txt")
        dst = os.path.join(LIC_OUT, fn)
        if os.path.exists(srcfile) and os.path.getsize(srcfile) > 0:
            shutil.copyfile(srcfile, dst)
        else:
            with open(dst, "w") as f:
                f.write(KENNEY_LICENSE.format(name=f"{name} by Kenney", pack=p, packs=PACKS))
    lines = [
        "Wax & Wane - audio credits",
        "==========================",
        "",
        "All audio is built by tools/make_audio.py (re-runnable).",
        "",
        "MUSIC (assets/audio/music/): original compositions, synthesized from scratch in numpy for this game",
        "(no samples). No third-party material. Free to use as part of the game.",
        "",
        "SOUND EFFECTS (assets/audio/sfx/): layered, trimmed, faded, mono-mixed and loudness-balanced from the",
        "Kenney audio packs below (all CC0 1.0, public domain - credit appreciated, not required) plus original",
        "numpy synthesis. Licences: " + ", ".join("assets/licenses/" + PACK_INFO[p][1] for p in packs),
        "",
        "Packs used: " + "; ".join(f"Kenney {PACK_INFO[p][0]} (www.kenney.nl, CC0)" for p in packs),
        "",
        "Per-file sources:",
    ]
    for name in SFX:
        rels = USED.get(name)
        if rels is None:
            continue
        srcs = ", ".join(f"{PACK_INFO[r.split('/')[0]][0]}: {os.path.basename(r)}" for r in rels)
        lines.append(f"  {name + '.ogg':16s} " + (srcs + " + synthesis" if srcs else "original synthesis (numpy)"))
    with open(os.path.join(LIC_OUT, "CREDITS_audio.txt"), "w") as f:
        f.write("\n".join(lines) + "\n")


# =============================================================================================== review
def review(out_dir):
    from PIL import Image, ImageDraw
    os.makedirs(out_dir, exist_ok=True)
    print("music:")
    for name in MUSIC:
        p = os.path.join(MUSIC_OUT, name + ".ogg")
        if not os.path.exists(p):
            continue
        x = decode(p, 2)
        m = x.mean(1)
        rms = 20 * np.log10(np.sqrt(np.mean(x ** 2)))
        pk = 20 * np.log10(peak(x))
        dc = np.abs(x.mean(0)).max()
        clip = int(np.sum(np.abs(x) > 0.999))
        d = np.abs(np.diff(m))
        seam = abs(m[0] - m[-1])
        w = secs(0.05)
        e_end, e_start = np.sqrt(np.mean(m[-w:] ** 2)), np.sqrt(np.mean(m[:w] ** 2))
        print(f"  {name:15s} {len(m) / SR:6.2f}s rms {rms:6.1f} peak {pk:5.1f} dc {dc:.4f} clip {clip} "
              f"seam jump {seam:.4f} (p99 step {np.percentile(d, 99):.4f}) rms end/start {e_end:.3f}/{e_start:.3f}")
        # spectrogram (+ for loops: a 4 s window across the seam) + waveform strip
        img_w, img_h = 1400, 360

        def spectro(sig, width, lo=30, hi=16000, rng_db=70, nper=2048, height=img_h):
            hop = max(128, len(sig) // width)
            f, tt, Z = signal.stft(sig, SR, nperseg=nper, noverlap=max(0, nper - hop), boundary=None)
            S = 20 * np.log10(np.abs(Z) + 1e-9)
            fl = np.geomspace(lo, hi, height)
            rows = np.interp(fl, f, np.arange(len(f))).astype(int)
            S = S[rows][::-1]
            S = np.clip((S - (S.max() - rng_db)) / rng_db, 0, 1) ** 1.6
            cols = np.linspace(0, S.shape[1] - 1, width).astype(int)
            S = S[:, cols]
            rgb = np.stack([np.clip(S * 2.2 - 0.6, 0, 1), np.clip(S * 1.8 - 0.9, 0, 1) ** 1.2,
                            np.clip(np.sin(S * np.pi) * 0.9, 0, 1)], -1)
            return (rgb * 255).astype(np.uint8)
        top = spectro(m, img_w)
        seam_sig = np.concatenate([m[-secs(2):], m[:secs(2)]]) if not name.endswith("jingle") else m
        sw = 600
        bot = spectro(seam_sig, sw)
        canvas = Image.new("RGB", (img_w, img_h + 200 + img_h // 2), (20, 20, 24))
        canvas.paste(Image.fromarray(top), (0, 0))
        dr = ImageDraw.Draw(canvas)
        # waveform envelope
        seg = len(m) // img_w
        for i in range(img_w):
            c = m[i * seg:(i + 1) * seg]
            if len(c):
                y0, y1 = int(img_h + 100 - c.max() * 95), int(img_h + 100 - c.min() * 95)
                dr.line([(i, y0), (i, y1)], fill=(120, 200, 255))
        dr.line([(0, img_h + 100 - int(db(-1) * 95)), (img_w, img_h + 100 - int(db(-1) * 95))], fill=(255, 80, 80))
        bimg = Image.fromarray(bot).resize((sw, img_h // 2))
        canvas.paste(bimg, (0, img_h + 200))
        # piano-roll style zoom of the first 12 s (110 Hz - 3.5 kHz) to read the notes
        zoom = spectro(m[:secs(12)], img_w, 110, 3500, 60, 8192, img_h)
        canvas2 = Image.new("RGB", (img_w, canvas.height + img_h), (20, 20, 24))
        canvas2.paste(canvas, (0, 0))
        canvas2.paste(Image.fromarray(zoom), (0, canvas.height))
        canvas = canvas2
        dr = ImageDraw.Draw(canvas)
        if not name.endswith("jingle"):
            dr.line([(sw // 2, img_h + 200), (sw // 2, img_h + 200 + img_h // 2)], fill=(255, 255, 0))
            # zoomed waveform across the seam (+-25 ms)
            z = np.concatenate([m[-secs(0.025):], m[:secs(0.025)]])
            ox, zw = sw + 40, img_w - sw - 60
            pts = [(ox + int(i * zw / len(z)), img_h + 200 + img_h // 4 - int(v * 80)) for i, v in enumerate(z)]
            dr.line(pts, fill=(200, 255, 160))
            dr.line([(ox + zw // 2, img_h + 200), (ox + zw // 2, img_h + 200 + img_h // 2)], fill=(255, 255, 0))
        dr.text((6, 4), f"{name}  {len(m) / SR:.1f}s  rms {rms:.1f}  peak {pk:.1f} dBFS  (30 Hz-16 kHz log)", fill=(255, 255, 255))
        canvas.save(os.path.join(out_dir, f"music_{name}.png"))
    print("sfx:")
    for name in SFX:
        p = os.path.join(SFX_OUT, name + ".ogg")
        if not os.path.exists(p):
            continue
        x = decode(p)
        lead = np.argmax(np.abs(x) > peak(x) * db(-40)) / SR
        print(f"  {name:12s} {len(x) / SR:5.2f}s peak {20 * np.log10(peak(x)):6.1f} loud {loudness(x):6.1f} "
              f"lead {lead * 1000:4.1f}ms dc {x.mean():+.4f} end {abs(x[-1]):.4f}")


# =============================================================================================== main
def main():
    args = sys.argv[1:]
    what = args[0] if args else "all"
    names = args[1:]
    os.makedirs(SFX_OUT, exist_ok=True)
    os.makedirs(MUSIC_OUT, exist_ok=True)
    try:
        if what == "review":
            review(names[0] if names else "/tmp/review_audio")
            return
        if what in ("all", "sfx"):
            print("SFX:")
            for n in (names if what == "sfx" and names else SFX):
                build_sfx(n)
            if not (what == "sfx" and names):
                write_credits()
        if what in ("all", "music"):
            print("music:")
            for n in (names if what == "music" and names else MUSIC):
                export_music(n, MUSIC[n]())
    finally:
        shutil.rmtree(TMP, ignore_errors=True)


if __name__ == "__main__":
    main()
