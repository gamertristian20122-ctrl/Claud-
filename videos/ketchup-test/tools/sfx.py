#!/usr/bin/env python3
"""Synthesises the cartoon sound effects from scratch (no samples, so no licences).

Run:  python3 tools/sfx.py   (writes assets/sfx/*.wav, 48 kHz mono 16-bit)
"""
import os
import wave

import numpy as np

SR = 48000
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sfx")
rng = np.random.default_rng(1830)


def t_axis(sec):
    return np.arange(int(SR * sec)) / SR


def lowpass(x, cutoff):
    """One-pole low-pass; cutoff may be an array (a sweep)."""
    cutoff = np.broadcast_to(cutoff, x.shape)
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a[i]) * x[i] + a[i] * acc
        y[i] = acc
    return y


def sweep(f0, f1, sec, curve=1.0):
    t = t_axis(sec)
    freq = f0 + (f1 - f0) * (t / sec) ** curve
    return np.sin(2 * np.pi * np.cumsum(freq) / SR)


def fade(x, ms_in=3, ms_out=15):
    n_in, n_out = int(SR * ms_in / 1000), int(SR * ms_out / 1000)
    x = x.copy()
    x[:n_in] *= np.linspace(0, 1, n_in)
    x[-n_out:] *= np.linspace(1, 0, n_out)
    return x


def whoosh():
    sec = 0.4
    t = t_axis(sec)
    noise = rng.standard_normal(len(t))
    env = np.sin(np.pi * t / sec) ** 2
    bright = lowpass(noise, 300 + 2600 * env)
    body = bright - lowpass(bright, 180)
    return body * env * 3.2


def squirt():
    sec = 0.4
    t = t_axis(sec)
    noise = rng.standard_normal(len(t))
    wet = lowpass(noise, 900) * (0.6 + 0.4 * np.sin(2 * np.pi * 26 * t))
    tone = sweep(520, 160, sec, 0.6) * 0.5
    env = np.exp(-t * 6) * np.minimum(1, t / 0.02)
    return (wet * 1.6 + tone) * env


def pop():
    sec = 0.2
    t = t_axis(sec)
    thump = sweep(240, 55, sec, 0.4) * np.exp(-t * 28)
    click = rng.standard_normal(len(t)) * np.exp(-t * 160) * 0.7
    return thump + lowpass(click, 4000)


def ding():
    sec = 0.8
    t = t_axis(sec)
    x = sum(a * np.sin(2 * np.pi * f * t) for f, a in [(1568, 0.6), (2349, 0.35), (3136, 0.25), (4186, 0.12)])
    shimmer = 1 + 0.15 * np.sin(2 * np.pi * 7 * t)
    return x * shimmer * np.exp(-t * 5.5) * np.minimum(1, t / 0.004)


def boing():
    sec = 0.5
    t = t_axis(sec)
    freq = 260 + 120 * np.exp(-t * 6) * np.sin(2 * np.pi * 16 * t) + 60 * t
    x = np.sin(2 * np.pi * np.cumsum(freq) / SR)
    return x * np.exp(-t * 6) * np.minimum(1, t / 0.006)


def glug():
    sec = 0.2
    t = t_axis(sec)
    x = sweep(170, 420, sec, 1.5) * np.exp(-t * 20)
    bubble = lowpass(rng.standard_normal(len(t)), 700) * np.exp(-t * 30) * 0.8
    return x + bubble


def write(name, x, peak_db=-3.0):
    x = fade(x)
    x = x / (np.max(np.abs(x)) + 1e-9) * 10 ** (peak_db / 20)
    data = (x * 32767).astype("<i2").tobytes()
    with wave.open(os.path.join(OUT_DIR, f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print("wrote", name, f"{len(x) / SR:.2f}s")


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, fn in [("whoosh", whoosh), ("squirt", squirt), ("pop", pop), ("ding", ding), ("boing", boing), ("glug", glug)]:
        write(name, fn())
