#!/usr/bin/env python3
"""Automatic beat-synced anime edit (an AMV-style short) from your own clips and a song.

    analyze  find the tempo, beats and drop of the song and every shot in the clips;
             writes analysis.json and numbered contact sheets of the shots
    render   cut shots to the beat with flashes, zoom punches, shake and RGB split;
             writes the MP4, a review sheet and edit.json (the timeline)
    auto     analyze + render in one go, picking the shots by itself

Needs only ffmpeg/ffprobe, numpy and Pillow. Run with --help on any command.
"""
from __future__ import annotations

import argparse
import json
import math
import shutil
import subprocess
import sys
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

VIDEO_EXT = {".mp4", ".mkv", ".mov", ".webm", ".avi", ".m4v", ".ts", ".flv", ".wmv", ".mpg", ".mpeg"}
FORMATS = {"vertical": (1080, 1920), "wide": (1920, 1080), "square": (1080, 1080)}
GRADES = {
    "punchy": "eq=contrast=1.07:saturation=1.22:gamma=0.98,vignette=angle=0.5",
    "cool": "eq=contrast=1.07:saturation=1.18:gamma=0.98,colorbalance=rs=-0.04:bs=0.06:rm=-0.02:bm=0.04,vignette=angle=0.5",
    "warm": "eq=contrast=1.07:saturation=1.18:gamma=0.98,colorbalance=rs=0.05:bs=-0.04:rm=0.03:bm=-0.02,vignette=angle=0.5",
    "none": "",
}
SR, HOP, NFFT = 22050, 512, 2048
FPS_A = SR / HOP                 # audio feature frames per second (~43)
AN_FPS, AN_W, AN_H = 8, 96, 54   # low-res decode used to find shots
MARGIN = 0.15                    # seconds kept away from each end of a shot (no frames of the next shot)
OVERSIZE = 1.12                  # base frames are this much bigger than the output: room for shake/zoom
RAMP_SPEED = 0.5                 # slow motion on the shot that leads into the drop
MAX_MB = 30.0                    # owner's upload limit
FONT_CANDIDATES = [
    "/usr/share/fonts/opentype/inter/InterDisplay-Black.otf",
    "/usr/share/fonts/opentype/inter/InterDisplay-ExtraBold.otf",
    "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
]


class EditError(Exception):
    pass


# ----------------------------------------------------------------------------- helpers

def run(cmd: list[str]) -> bytes:
    try:
        return subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout
    except subprocess.CalledProcessError as e:
        tail = e.stderr.decode("utf-8", "replace").strip().splitlines()[-3:]
        raise EditError(f"{cmd[0]} failed: {' | '.join(tail)}") from None


def need_tools() -> None:
    for tool in ("ffmpeg", "ffprobe"):
        if not shutil.which(tool):
            raise EditError(f"{tool} is not installed (needed for video work)")


def even(x: float) -> int:
    return max(2, int(round(x / 2)) * 2)


def probe(path: Path) -> dict:
    out = run(["ffprobe", "-v", "error", "-show_entries",
               "format=duration:stream=codec_type,width,height,avg_frame_rate:stream_side_data=rotation:stream_tags=rotate",
               "-of", "json", str(path)])
    info = json.loads(out or b"{}")
    streams = info.get("streams", [])
    res = {"duration": float(info.get("format", {}).get("duration") or 0.0),
           "has_audio": any(s.get("codec_type") == "audio" for s in streams),
           "has_video": False}
    v = next((s for s in streams if s.get("codec_type") == "video" and s.get("width")), None)
    if v:
        num, _, den = (v.get("avg_frame_rate") or "0/1").partition("/")
        try:
            fps = float(num) / float(den) if float(den or 0) else 0.0
        except ValueError:
            fps = 0.0
        w, h = int(v["width"]), int(v["height"])
        rot = 0
        for sd in v.get("side_data_list", []) or []:
            if "rotation" in sd:
                rot = int(float(sd["rotation"]))
        rot = rot or int(float((v.get("tags") or {}).get("rotate", 0) or 0))
        if abs(rot) % 180 == 90:  # ffmpeg auto-rotates, so the frames we get are turned
            w, h = h, w
        res.update(has_video=True, width=w, height=h, fps=fps)
    return res


def find_font(size: int):
    for p in FONT_CANDIDATES:
        if Path(p).is_file():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default(size=size)


def collect_clips(paths: list[str], exclude: Path | None) -> list[Path]:
    found: list[Path] = []
    for p in map(Path, paths):
        if p.is_dir():
            found += sorted(q for q in p.rglob("*") if q.is_file() and q.suffix.lower() in VIDEO_EXT)
        elif p.is_file():
            found.append(p)
        else:
            raise EditError(f"clip path not found: {p}")
    seen, res = set(), []
    for q in found:
        r = q.resolve()
        if r not in seen and r != exclude:
            seen.add(r)
            res.append(r)
    return res


# ----------------------------------------------------------------------------- song

def load_audio(path: Path) -> np.ndarray:
    raw = run(["ffmpeg", "-v", "error", "-i", str(path), "-vn", "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"])
    return np.frombuffer(raw, dtype=np.float32).copy()


def band_matrix(n_bands: int = 48, fmin: float = 30.0):
    """Averages FFT bins into log-spaced bands (like hearing), so a kick drum counts as much as hi-hats."""
    freqs = np.fft.rfftfreq(NFFT, 1 / SR)
    edges = np.geomspace(fmin, SR / 2, n_bands + 1)
    m = np.zeros((len(freqs), n_bands), np.float32)
    for b in range(n_bands):
        sel = (freqs >= edges[b]) & (freqs < edges[b + 1])
        if not sel.any():  # very narrow low band: use the nearest bin
            sel = np.abs(freqs - np.sqrt(edges[b] * edges[b + 1])) == np.abs(freqs - np.sqrt(edges[b] * edges[b + 1])).min()
        m[sel, b] = 1.0 / sel.sum()
    centers = np.sqrt(edges[:-1] * edges[1:])
    return m, centers < 150


def audio_features(y: np.ndarray):
    """Spectral flux on log-spaced bands (all, and bass only) and RMS per hop."""
    y = np.pad(y, (NFFT // 2, NFFT // 2))
    if len(y) < NFFT:
        y = np.pad(y, (0, NFFT - len(y)))
    frames = np.lib.stride_tricks.sliding_window_view(y, NFFT)[::HOP]
    n = len(frames)
    win = np.hanning(NFFT).astype(np.float32)
    bands, bass = band_matrix()
    flux, low, rms = (np.zeros(n, np.float32) for _ in range(3))
    prev = None
    for i in range(0, n, 1024):
        chunk = frames[i:i + 1024]
        mag = np.log1p(30 * (np.abs(np.fft.rfft(chunk * win, axis=1)) @ bands)).astype(np.float32)
        rms[i:i + len(chunk)] = np.sqrt((chunk.astype(np.float32) ** 2).mean(axis=1))
        stacked = mag if prev is None else np.vstack([prev[None, :], mag])
        d = np.maximum(np.diff(stacked, axis=0), 0)
        if prev is None:
            d = np.vstack([np.zeros((1, mag.shape[1]), np.float32), d])
        flux[i:i + len(chunk)] = d.sum(axis=1)
        low[i:i + len(chunk)] = d[:, bass].sum(axis=1)
        prev = mag[-1]
    return flux, low, rms


def onset_env(flux: np.ndarray) -> np.ndarray:
    k = 17
    o = np.maximum(flux - np.convolve(flux, np.ones(k) / k, mode="same"), 0)
    return o / (o.std() or 1.0)


def estimate_tempo(o: np.ndarray) -> float:
    o = o - o.mean()
    n = len(o)
    spec = np.fft.rfft(o, 2 * n)
    ac = np.fft.irfft(spec * np.conj(spec))[:n]
    bpms = np.arange(60.0, 200.01, 0.25)
    lags = 60.0 * FPS_A / bpms
    grid = np.arange(n)
    score = np.interp(lags, grid, ac) + 0.5 * np.interp(2 * lags, grid, ac)
    score *= np.exp(-0.5 * (np.log2(bpms / 120.0) / 0.9) ** 2)  # prefer common tempos
    return float(bpms[int(np.argmax(score))])


def track_beats(o: np.ndarray, bpm: float, tightness: float = 100.0) -> np.ndarray:
    """Dynamic-programming beat tracker (Ellis 2007)."""
    n = len(o)
    period = 60.0 * FPS_A / bpm
    x = np.arange(-int(period), int(period) + 1)
    local = np.convolve(o, np.exp(-0.5 * (x * 32.0 / period) ** 2), mode="same")
    lo, hi = max(1, int(round(period / 2))), max(2, int(round(2 * period)))
    offs = np.arange(-hi, -lo + 1)
    pen = -tightness * np.log(-offs / period) ** 2
    score = local.astype(np.float64).copy()
    back = np.full(n, -1, dtype=np.int64)
    for t in range(lo, n):
        ok = offs[t + offs >= 0]
        c = score[t + ok] + pen[-len(ok):]
        j = int(np.argmax(c))
        score[t] = local[t] + c[j]
        back[t] = t + ok[j]
    tail = max(0, n - int(2 * period))
    t = tail + int(np.argmax(score[tail:]))
    beats = []
    while t >= 0:
        beats.append(t)
        t = back[t]
    return np.array(beats[::-1], dtype=np.int64)


def analyze_song(path: Path, length: float, song_start: float | None) -> dict:
    info = probe(path)
    if not info["has_audio"]:
        raise EditError(f"the song file has no audio: {path.name}")
    y = load_audio(path)
    total = len(y) / SR
    if total < 3:
        raise EditError("the song is shorter than 3 seconds")
    flux, low, rms = audio_features(y)
    o, ob = onset_env(flux), onset_env(low)
    o = o + ob  # lean on the kick/808: edit music is bass-driven, hi-hats sit between beats
    bpm = estimate_tempo(o)
    bf = track_beats(o, bpm)
    # drop beats in silence at the start/end
    e_db = 20 * np.log10(rms + 1e-5)
    loud = e_db > np.percentile(e_db, 95) - 40
    bf = bf[loud[np.clip(bf, 0, len(loud) - 1)]]
    if len(bf) < 8:
        bf = np.round(np.arange(0, len(o), 60.0 * FPS_A / bpm)).astype(np.int64)
    bpm = float(60.0 * FPS_A / np.median(np.diff(bf)))
    phase = int(np.argmax([ob[bf[p::4]].mean() + 0.5 * o[bf[p::4]].mean() for p in range(4)]))
    beat_t = bf * HOP / SR
    is_down = np.zeros(len(bf), bool)
    is_down[phase::4] = True
    downs = beat_t[is_down]
    period = 60.0 / bpm

    k = max(1, int(FPS_A * 0.5))
    e = np.convolve(e_db, np.ones(k) / k, mode="same")

    def mean_e(t0: float, t1: float) -> float:
        i0, i1 = max(0, int(t0 * FPS_A)), min(len(e), int(t1 * FPS_A))
        return float(e[i0:i1].mean()) if i1 > i0 else -200.0

    hi_e = np.percentile(e, 60) - 3.0  # the part after a drop must be among the loud parts of the song
    drop, jump = None, 0.0
    for d in downs:
        if 3 <= d <= total - 3:
            post, pre = mean_e(d, d + 4), mean_e(d - 4, d)
            if post >= hi_e and post - pre > jump:
                drop, jump = float(d), post - pre
    if jump < 2.5:
        drop = None

    L = min(length, total - 0.05)
    if song_start is not None:
        if not 0 <= song_start < total - 1:
            raise EditError(f"--song-start must be between 0 and {total - 1:.1f} seconds")
        start = float(beat_t[np.argmin(np.abs(beat_t - song_start))])
    elif drop is not None:
        cands = downs[downs <= drop]
        target = drop - 0.35 * L
        start = float(cands[np.argmin(np.abs(cands - target))]) if len(cands) else 0.0
    else:
        cands = [d for d in downs if d + L <= total] or [0.0]
        start = float(max(cands, key=lambda d: mean_e(d, d + L)))
    if start + L > total:
        fit = beat_t[beat_t <= total - L]
        start = float(fit[-1]) if len(fit) else 0.0
    want = start + L
    near = [d for d in downs if abs(d - want) <= 2 * period and start + 2 < d <= total]
    near = near or [b for b in beat_t if abs(b - want) <= period and start + 2 < b <= total]
    end = float(min(near, key=lambda d: abs(d - want))) if near else min(total, want)

    sel = (beat_t >= start - 1e-3) & (beat_t < end - 1e-3)
    rel = list(np.round(beat_t[sel] - start, 4))
    rdown = [bool(v) for v in is_down[sel]]
    if not rel or rel[0] > 0.05:
        rel.insert(0, 0.0)
        rdown.insert(0, True)
    rel[0] = 0.0
    drop_rel = round(drop - start, 4) if drop is not None and start < drop < end else None
    return {"path": str(path), "total": round(total, 3), "bpm": round(bpm, 2), "start": round(start, 3),
            "duration": round(end - start, 3), "beats": [float(b) for b in rel], "downbeats": rdown,
            "drop": drop_rel, "drop_strength_db": round(jump, 2)}


# ----------------------------------------------------------------------------- shots

def decode_small(path: Path) -> np.ndarray:
    raw = run(["ffmpeg", "-v", "error", "-i", str(path), "-an", "-vf",
               f"fps={AN_FPS},scale={AN_W}:{AN_H}:flags=area", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"])
    size = AN_W * AN_H * 3
    n = len(raw) // size
    return np.frombuffer(raw[:n * size], np.uint8).reshape(n, AN_H, AN_W, 3)


def find_cuts(F: np.ndarray, min_len: float = 0.5):
    """Return shot boundaries (frame indices) and the per-frame pixel difference."""
    n = len(F)
    g = F.astype(np.float32).mean(axis=3)
    pd = np.zeros(n, np.float32)
    if n < 2:
        return [(0, n)], pd, g
    pd[1:] = np.abs(np.diff(g, axis=0)).mean(axis=(1, 2)) / 255.0
    q = (F >> 6).astype(np.int64)
    idx = (q[..., 0] * 16 + q[..., 1] * 4 + q[..., 2]).reshape(n, -1)
    hist = np.bincount((idx + 64 * np.arange(n)[:, None]).ravel(), minlength=64 * n).reshape(n, 64)
    hist = hist.astype(np.float32) / idx.shape[1]
    hd = np.zeros(n, np.float32)
    hd[1:] = 0.5 * np.abs(np.diff(hist, axis=0)).sum(axis=1)
    c = hd + 0.5 * pd
    # a cut is a spike: it must stand out from the frames on at least one side, so a shot that keeps
    # changing colour (energy effects, colour cycling) is not chopped into many fake cuts
    k = 6
    pad = np.pad(c, k, mode="edge")
    left = np.median(np.lib.stride_tricks.sliding_window_view(pad[:-k - 1], k), axis=1)[:n]
    right = np.median(np.lib.stride_tricks.sliding_window_view(pad[k + 1:], k), axis=1)[:n]
    base = np.minimum(left, right)
    cand = np.where((c > 0.25) & (c > 2.5 * base + 0.08))[0]
    cuts = [0]
    for t in cand:
        if t > 0 and t - cuts[-1] >= min_len * AN_FPS:
            cuts.append(int(t))
    cuts.append(n)
    return list(zip(cuts[:-1], cuts[1:])), pd, g


def shot_stats(F: np.ndarray) -> list[dict]:
    bounds, pd, g = find_cuts(F)
    shots = []
    for a, b in bounds:
        seg, gs = F[a:b], g[a:b]
        mx, mn = seg.max(axis=3).astype(np.float32), seg.min(axis=3).astype(np.float32)
        motion = float(pd[a + 1:b].mean()) if b - a > 1 else 0.0
        kw = max(1, min(AN_FPS, b - a))
        sm = np.convolve(pd[a:b], np.ones(kw) / kw, mode="same")[: b - a] if b - a > 1 else np.zeros(1)
        colm = np.abs(np.diff(gs, axis=0)).mean(axis=(0, 1)) if b - a > 1 else np.zeros(AN_W)
        cole = np.pad(np.abs(np.diff(gs.mean(axis=0), axis=1)).mean(axis=0), (0, 1))
        col = colm / (colm.max() + 1e-6) + 0.5 * cole / (cole.max() + 1e-6)
        shots.append({
            "start": round(a / AN_FPS, 3), "end": round(b / AN_FPS, 3),
            "motion": round(motion, 4),
            "peak": round((a + int(np.argmax(sm))) / AN_FPS, 3),
            "bright": round(float(gs.mean()) / 255, 3),
            "contrast": round(float(gs.std()) / 255, 3),
            "sat": round(float(((mx - mn) / (mx + 1.0)).mean()), 3),
            "col": [round(float(v), 3) for v in col],
        })
    return shots


def focus_x(col: list[float], crop_frac: float) -> float:
    """Horizontal centre (0..1) of the crop window that holds the most motion/detail."""
    arr = np.asarray(col, np.float64)
    n = len(arr)
    w = max(1, int(round(crop_frac * n)))
    if w >= n:
        return 0.5
    cs = np.concatenate([[0.0], np.cumsum(arr)])
    sums = cs[w:] - cs[:-w]
    centers = (np.arange(len(sums)) + w / 2) / n
    sums = sums * (1 - 0.3 * np.abs(centers - 0.5))  # mild pull to the middle
    return round(float(centers[int(np.argmax(sums))]), 3)


def crop_frac_for(src_w: int, src_h: int, out_w: int, out_h: int) -> float:
    return min(1.0, (src_h * out_w / out_h) / src_w)


def grab_frame(path: str, t: float, w: int, h: int) -> Image.Image:
    vf = f"scale={w}:{h}:force_original_aspect_ratio=decrease,pad={w}:{h}:(ow-iw)/2:(oh-ih)/2"
    try:
        raw = run(["ffmpeg", "-v", "error", "-ss", f"{max(0.0, t):.3f}", "-i", path, "-frames:v", "1",
                   "-vf", vf, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"])
    except EditError:
        raw = b""
    if len(raw) < w * h * 3:
        return Image.new("RGB", (w, h), (40, 0, 0))
    return Image.frombytes("RGB", (w, h), raw[:w * h * 3])


def contact_sheets(work: Path, shots: list[dict], clips: list[dict], out_wh: tuple[int, int]) -> list[str]:
    tw, th, lab, cols, rows = 320, 180, 22, 5, 6
    font = find_font(15)
    with ThreadPoolExecutor(max_workers=4) as pool:
        thumbs = list(pool.map(lambda s: grab_frame(clips[s["clip"]]["path"], s["peak"], tw, th), shots))
    sheets = []
    per = cols * rows
    for page in range(0, len(shots), per):
        batch = shots[page:page + per]
        sheet = Image.new("RGB", (cols * tw, rows * (th + lab)), (18, 18, 22))
        draw = ImageDraw.Draw(sheet)
        for i, (s, im) in enumerate(zip(batch, thumbs[page:page + per])):
            x, y = (i % cols) * tw, (i // cols) * (th + lab)
            sheet.paste(im, (x, y))
            c = clips[s["clip"]]
            sc = min(tw / c["width"], th / c["height"])
            dw, dh = c["width"] * sc, c["height"] * sc
            ox, oy = (tw - dw) / 2, (th - dh) / 2
            frac = crop_frac_for(c["width"], c["height"], *out_wh)
            if frac < 0.999:
                x0 = min(max(s["focus"] - frac / 2, 0.0), 1 - frac) * dw
                draw.rectangle([x + ox + x0, y + oy, x + ox + x0 + frac * dw, y + oy + dh - 1], outline=(0, 230, 255), width=2)
            txt = f"#{s['id']}  {s['end'] - s['start']:.1f}s  mov {s['motion'] * 100:.0f}  clip{s['clip'] + 1} @{s['start']:.0f}s"
            draw.text((x + 6, y + th + 3), txt, fill=(235, 235, 235), font=font)
        p = work / f"sheet_{page // per + 1:02d}.jpg"
        sheet.save(p, quality=85)
        sheets.append(p.name)
    return sheets


def analyze(clips_arg: list[str], song: str, work: Path, length: float, song_start: float | None,
            fmt: str, max_shots: int, quiet: bool = False) -> dict:
    need_tools()
    say = (lambda *a: None) if quiet else print
    if not 3 <= length <= 180:
        raise EditError("--length must be between 3 and 180 seconds")
    song_path = Path(song).resolve()
    if not song_path.is_file():
        raise EditError(f"song not found: {song}")
    clips = collect_clips(clips_arg, exclude=song_path)
    if not clips:
        raise EditError("no video files found in --clips")
    work.mkdir(parents=True, exist_ok=True)
    out_wh = FORMATS[fmt]

    say("1/3 listening to the song ...")
    s = analyze_song(song_path, length, song_start)
    drop_txt = f"drop at {s['drop']:.2f}s" if s["drop"] is not None else "no clear drop"
    say(f"    {s['bpm']:.1f} BPM, using {s['start']:.2f}s to {s['start'] + s['duration']:.2f}s, {drop_txt}")

    say("2/3 finding shots ...")
    clip_info, shots = [], []
    for path in clips:
        info = probe(path)
        if not info["has_video"]:
            say(f"    skipped (no video): {path.name}")
            continue
        ci = len(clip_info)
        clip_info.append({"path": str(path), "duration": info["duration"], "width": info["width"],
                          "height": info["height"], "fps": info["fps"]})
        found = 0
        for st in shot_stats(decode_small(path)):
            ln = st["end"] - st["start"]
            if ln < 0.6 or st["bright"] < 0.05 or st["contrast"] < 0.03:
                continue  # too short, black or blank
            st["clip"] = ci
            st["focus"] = focus_x(st["col"], crop_frac_for(info["width"], info["height"], *out_wh))
            shots.append(st)
            found += 1
        say(f"    {path.name}: {found} usable shots")
    if not shots:
        raise EditError("no usable shots found (clips too short, black or blank?)")
    if len(shots) > max_shots:  # keep the liveliest, plus an even spread of the rest
        by_mot = sorted(range(len(shots)), key=lambda i: -shots[i]["motion"])
        keep = set(by_mot[: max_shots * 2 // 3])
        rest = [i for i in range(len(shots)) if i not in keep]
        need = max_shots - len(keep)
        keep |= {rest[int(j * len(rest) / need)] for j in range(need)} if need > 0 else set()
        shots = [shots[i] for i in sorted(keep)]
    for i, st in enumerate(shots, 1):
        st["id"] = i

    say(f"3/3 making contact sheets of {len(shots)} shots ...")
    sheets = contact_sheets(work, shots, clip_info, out_wh)
    data = {"version": 1, "format": fmt, "song": s, "clips": clip_info, "shots": shots, "sheets": sheets}
    (work / "analysis.json").write_text(json.dumps(data, indent=1))
    say(f"    wrote {work / 'analysis.json'} and {len(sheets)} sheet(s)")
    return data


# ----------------------------------------------------------------------------- plan

def load_plan(path: Path | None, shots: list[dict]) -> dict:
    """Read and validate a plan written by a person or an AI. Never trust it blindly."""
    if path is None:
        return {}
    try:
        plan = json.loads(Path(path).read_text())
    except (OSError, json.JSONDecodeError) as e:
        raise EditError(f"cannot read plan {path}: {e}") from None
    if not isinstance(plan, dict):
        raise EditError("plan must be a JSON object")
    ids = {s["id"] for s in shots}
    allowed = {"pool", "order", "hero", "ramp", "outro", "exclude", "focus", "title", "title_at", "notes"}
    unknown = set(plan) - allowed
    if unknown:
        raise EditError(f"unknown plan keys: {sorted(unknown)} (allowed: {sorted(allowed)})")

    def id_list(key: str) -> list[int]:
        v = plan.get(key, [])
        if not isinstance(v, list) or not all(isinstance(i, int) and not isinstance(i, bool) for i in v):
            raise EditError(f"plan '{key}' must be a list of shot numbers")
        bad = [i for i in v if i not in ids]
        if bad:
            raise EditError(f"plan '{key}' has shot numbers that don't exist: {bad}")
        return v

    out = {k: id_list(k) for k in ("pool", "order", "exclude")}
    for key in ("hero", "ramp", "outro"):
        v = plan.get(key)
        if v is not None:
            if not isinstance(v, int) or isinstance(v, bool) or v not in ids:
                raise EditError(f"plan '{key}' must be one existing shot number")
        out[key] = v
    focus = plan.get("focus", {})
    if not isinstance(focus, dict):
        raise EditError("plan 'focus' must map shot numbers to 0..1")
    out["focus"] = {}
    for k, v in focus.items():
        try:
            sid = int(k)
        except ValueError:
            raise EditError(f"plan 'focus' key {k!r} is not a shot number") from None
        if sid not in ids or not isinstance(v, (int, float)) or isinstance(v, bool) or not 0 <= v <= 1:
            raise EditError(f"plan 'focus' entry {k}: {v!r} must be an existing shot and a number 0..1")
        out["focus"][sid] = float(v)
    title = plan.get("title")
    if title is not None:
        if not isinstance(title, str):
            raise EditError("plan 'title' must be text")
        title = "".join(ch for ch in title if ch.isprintable()).strip()[:40]
    out["title"] = title or None
    ta = plan.get("title_at", "end")
    if ta not in ("start", "end"):
        raise EditError("plan 'title_at' must be 'start' or 'end'")
    out["title_at"] = ta
    return out


# ----------------------------------------------------------------------------- timeline

def build_slots(song: dict, style: str, fps: int) -> list[dict]:
    beats, downs, L = song["beats"], song["downbeats"], song["duration"]
    n = len(beats)
    period = 60.0 / song["bpm"]
    unit = 1 if period >= 0.3 else 2
    if song.get("drop") is not None:
        kd = int(np.argmin(np.abs(np.asarray(beats) - song["drop"])))
    else:
        dn = [i for i in range(n) if downs[i]] or [0]
        kd = min(dn, key=lambda i: abs(beats[i] - 0.3 * L))
    hype = style == "hype"
    pre, fast, post = (2 * unit, unit, 2 * unit) if hype else (4 * unit, 2 * unit, 4 * unit)
    outro_start = n - 4 if n - kd > 4 else (kd + 1 if n - kd >= 2 else n)
    ramp_start = kd - 4 if kd >= 6 else kd
    segs, b = [], 0
    while b < ramp_start:
        step = min(4 if b == 0 else pre, ramp_start - b)
        segs.append((b, b + step, "intro"))
        b += step
    if ramp_start < kd:
        segs.append((ramp_start, kd, "ramp"))
        b = kd
    first = True
    while b < outro_start:
        step = min(fast if b < kd + 8 else post, outro_start - b)
        segs.append((b, b + step, "drop" if first else "hit"))
        first = False
        b += step
    if b < n:
        segs.append((b, n, "outro"))

    def frame_at(i: int) -> int:
        if i >= n:
            return int(round(L * fps))
        return max(0, int(round(beats[i] * fps)) - (1 if i > 0 else 0))  # cut one frame early: feels on time

    slots = []
    for i0, i1, kind in segs:
        f0, f1 = frame_at(i0), frame_at(i1)
        if f1 - f0 < 2:
            if slots:
                slots[-1]["f1"] = f1
            continue
        slots.append({"kind": kind, "f0": f0, "f1": f1, "down": bool(downs[i0]) if i0 < n else False})
    if slots:
        slots[0]["f0"] = 0
        slots[-1]["f1"] = int(round(L * fps))
    for s in slots:
        s["dur"] = (s["f1"] - s["f0"]) / fps
    return slots


def assign_shots(slots: list[dict], shots: list[dict], plan: dict) -> list[dict]:
    byid = {s["id"]: s for s in shots}
    excl = set(plan.get("exclude", []))
    pool = [byid[i] for i in plan.get("pool", [])] or [s for s in shots if s["id"] not in excl]
    pool = [s for s in pool if s["id"] not in excl] or list(shots)
    usable = lambda s: s["end"] - s["start"] - 2 * MARGIN
    min_speed = lambda kind: 0.35 if kind == "ramp" else 0.6
    want_speed = lambda kind: RAMP_SPEED if kind == "ramp" else 1.0
    fits = lambda s, slot: usable(s) >= slot["dur"] * min_speed(slot["kind"])
    used: Counter = Counter()
    chosen: list[dict | None] = [None] * len(slots)

    if plan.get("order"):
        seq = [byid[i] for i in plan["order"]]
        for k in range(len(slots)):
            chosen[k] = seq[k % len(seq)]
    else:
        mot_sorted = sorted(pool, key=lambda s: -s["motion"])
        taken: set[int] = set()

        def take(cands, slot, prefer=None):
            if prefer is not None and fits(byid[prefer], slot):
                taken.add(prefer)
                return byid[prefer]
            for s in cands:
                if s["id"] not in taken and fits(s, slot):
                    taken.add(s["id"])
                    return s
            return None

        idx = {k: [i for i, sl in enumerate(slots) if sl["kind"] == k] for k in ("drop", "ramp", "outro", "hit", "intro")}
        for i in idx["drop"]:
            chosen[i] = take(mot_sorted, slots[i], plan.get("hero"))
        for i in idx["ramp"]:
            chosen[i] = take(sorted(pool, key=lambda s: -(s["motion"] * min(usable(s), 3))), slots[i], plan.get("ramp"))
        for i in idx["outro"]:
            upper = mot_sorted[: max(1, len(mot_sorted) // 2)]
            chosen[i] = take(sorted(upper, key=lambda s: -usable(s)), slots[i], plan.get("outro"))
        intro = idx["intro"]  # build-up before the many fast cuts, so it gets its own (calmer) shots
        mids = [s for s in sorted(pool, key=lambda s: -s["motion"]) if s["id"] not in taken]
        mids = mids[len(mids) // 4:] + mids[: len(mids) // 4]
        ipicks = []
        for s in mids:
            if len(ipicks) == len(intro):
                break
            if fits(s, slots[intro[len(ipicks)]]):
                taken.add(s["id"])
                ipicks.append(s)
        ipicks.sort(key=lambda s: (s["clip"], s["start"]))
        for i, s in zip(intro, ipicks):
            chosen[i] = s
        hits = idx["hit"]
        picks = []
        for s in mot_sorted:
            if len(picks) == len(hits):
                break
            if s["id"] not in taken and fits(s, slots[hits[len(picks)]]):
                taken.add(s["id"])
                picks.append(s)
        picks.sort(key=lambda s: (s["clip"], s["start"]))  # keep story order
        for i, s in zip(hits, picks):
            chosen[i] = s

    planned = Counter(c["id"] for c in chosen if c is not None)
    special = {chosen[i]["id"] for i, sl in enumerate(slots) if sl["kind"] in ("drop", "ramp", "outro") and chosen[i]}
    out = []
    prev_id = None
    for k, slot in enumerate(slots):
        s = chosen[k]
        if s is None or not fits(s, slot):  # pool ran out: reuse a shot, but not the drop/outro ones or the last one
            cands = [c for c in pool if fits(c, slot) and c["id"] != prev_id] or [c for c in shots if fits(c, slot)]
            if not cands:
                raise EditError(f"no shot is long enough for a {slot['dur']:.2f}s slot; add longer clips")
            calm = slot["kind"] == "intro"
            s = min(cands, key=lambda c: (c["id"] in special, used[c["id"]] + planned[c["id"]],
                                          c["motion"] if calm else -c["motion"]))
        speed = min(want_speed(slot["kind"]), usable(s) / slot["dur"])
        src_len = slot["dur"] * speed
        lo, hi = s["start"] + MARGIN, s["end"] - MARGIN - src_len
        if used[s["id"]] and hi > lo:  # reused: take a different part of the shot
            s0 = lo + ((used[s["id"]] * 0.618) % 1.0) * (hi - lo)
        else:
            s0 = min(max(s["peak"] - src_len / 2, lo), max(lo, hi))
        used[s["id"]] += 1
        prev_id = s["id"]
        out.append({**slot, "shot": s["id"], "clip": s["clip"], "src_start": round(s0, 3),
                    "speed": round(speed, 4), "focus": plan.get("focus", {}).get(s["id"])})
    return out


# ----------------------------------------------------------------------------- render

def fx_at(slot: dict, k: int, fps: int, style: str, first: bool) -> dict:
    n = slot["f1"] - slot["f0"]
    tau, d = k / fps, n / fps
    p = k / max(1, n - 1)
    z, sx, sy, flash, rgb, dark = 1.0, 0.0, 0.0, 0.0, 0.0, 0.0
    kind = slot["kind"]
    if kind == "intro":
        z = 1 + 0.05 * p
    elif kind == "ramp":
        z = 1 + 0.16 * p * p
        flash = 0.6 * min(1.0, max(0.0, (tau - (d - 0.12)) / 0.12))
    elif kind in ("drop", "hit"):
        strong, down = kind == "drop", slot["down"]
        punch = 0.20 if strong else (0.10 if down else 0.05)
        z = 1 + punch * math.exp(-tau / 0.10) + 0.03 * p
        flash = (0.9 if strong else 0.45 if down else 0.18) * math.exp(-tau / 0.06)
        amp = (34 if strong else 14 if down else 0) * math.exp(-tau / 0.16)
        sx, sy = amp * math.sin(2 * math.pi * 19 * tau), amp * math.cos(2 * math.pi * 15 * tau)
        rgb = (16 if strong else 7 if down else 0) * math.exp(-tau / 0.12)
    elif kind == "outro":
        z = 1 + 0.06 * p
        dark = min(1.0, max(0.0, (tau - (d - 0.5)) / 0.5))
    if first:
        dark = max(dark, 1 - tau / 0.15)
    if style == "smooth":
        flash, sx, sy, rgb = flash * 0.4, sx * 0.4, sy * 0.4, rgb * 0.4
    return {"z": z, "sx": sx, "sy": sy, "flash": flash, "rgb": rgb, "dark": dark}


def apply_fx(base: np.ndarray, fx: dict, ow: int, oh: int, scale: float) -> np.ndarray:
    bh, bw = base.shape[:2]
    z, sx, sy = fx["z"], fx["sx"] * scale, fx["sy"] * scale
    if abs(z - 1) < 1e-4 and abs(sx) < 0.5 and abs(sy) < 0.5:
        x0, y0 = (bw - ow) // 2, (bh - oh) // 2
        out = base[y0:y0 + oh, x0:x0 + ow]
    else:
        data = (1 / z, 0, bw / 2 - ow / 2 / z + sx, 0, 1 / z, bh / 2 - oh / 2 / z + sy)
        out = np.asarray(Image.fromarray(base).transform((ow, oh), Image.Transform.AFFINE, data, Image.Resampling.BICUBIC))
    k = int(round(fx["rgb"] * scale))
    if k >= 1:
        out = out.copy()
        out[..., 0] = np.roll(out[..., 0], k, axis=1)
        out[..., 2] = np.roll(out[..., 2], -k, axis=1)
    if fx["flash"] > 0.01 or fx["dark"] > 0.01:
        f = out.astype(np.float32)
        if fx["flash"] > 0.01:
            f += fx["flash"] * (255.0 - f)
        if fx["dark"] > 0.01:
            f *= 1.0 - fx["dark"]
        out = np.clip(f, 0, 255).astype(np.uint8)
    return out


def title_layer(text: str, ow: int, oh: int):
    size = int(ow * (0.12 if ow < oh else 0.075))
    font = find_font(size)
    while font.getlength(text) > ow * 0.9 and size > 20:
        size = int(size * 0.9)
        font = find_font(size)
    stroke = max(3, size // 14)
    l, t, r, b = font.getbbox(text, stroke_width=stroke)
    im = Image.new("RGBA", (ow, b - t + 2 * stroke + 8), (0, 0, 0, 0))
    ImageDraw.Draw(im).text(((ow - (r - l)) / 2 - l, stroke + 4 - t), text, font=font, fill=(255, 255, 255, 255),
                            stroke_width=stroke, stroke_fill=(0, 0, 0, 255))
    arr = np.asarray(im).astype(np.float32)
    y = int(oh * (0.68 if ow < oh else 0.72))
    return arr[..., :3], arr[..., 3:] / 255.0, y


def decode_segment(clip: dict, item: dict, out_wh: tuple[int, int], fps: int, grade: str, log):
    ow, oh = out_wh
    bw, bh = even(ow * OVERSIZE), even(oh * OVERSIZE)
    ar = bw / bh
    focus = item["focus"] if item["focus"] is not None else 0.5
    vf = (f"setpts=(PTS-STARTPTS)/{item['speed']:.5f},fps={fps},"
          f"crop=w='trunc(min(iw\\,ih*{ar:.6f})/2)*2':h='trunc(min(ih\\,iw/{ar:.6f})/2)*2':"
          f"x='max(0\\,min(iw-ow\\,{focus:.4f}*iw-ow/2))':y='(ih-oh)/2',"
          f"scale={bw}:{bh}:flags=lanczos,setsar=1")
    if GRADES[grade]:
        vf += "," + GRADES[grade]
    n = item["f1"] - item["f0"]
    cmd = ["ffmpeg", "-v", "error", "-ss", f"{item['src_start']:.3f}", "-i", clip["path"], "-an", "-vf", vf,
           "-frames:v", str(n), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=log)
    size = bw * bh * 3
    last = None
    for _ in range(n):
        buf = proc.stdout.read(size) if proc.stdout else b""
        if len(buf) == size:
            last = np.frombuffer(buf, np.uint8).reshape(bh, bw, 3)
        yield last if last is not None else np.zeros((bh, bw, 3), np.uint8)
    if proc.stdout:
        proc.stdout.close()
    proc.wait()


def render(work: Path, plan_path: Path | None, out: Path, style: str, grade: str, fps: int,
           title: str | None, fmt: str | None, crf: int = 19, quiet: bool = False) -> dict:
    need_tools()
    say = (lambda *a: None) if quiet else print
    ap = work / "analysis.json"
    if not ap.is_file():
        raise EditError(f"run 'analyze' first: {ap} not found")
    A = json.loads(ap.read_text())
    fmt = fmt or A["format"]
    if fmt not in FORMATS or style not in ("hype", "smooth") or grade not in GRADES or fps not in (24, 30, 60):
        raise EditError("bad --format/--style/--grade/--fps value")
    ow, oh = FORMATS[fmt]
    song, clips, shots = A["song"], A["clips"], A["shots"]
    plan = load_plan(plan_path, shots)
    if title:
        plan["title"] = "".join(ch for ch in title if ch.isprintable()).strip()[:40] or None
    slots = build_slots(song, style, fps)
    items = assign_shots(slots, shots, plan)
    byid = {s["id"]: s for s in shots}
    for it in items:  # focus for this output shape unless the plan set one
        if it["focus"] is None:
            c = clips[it["clip"]]
            it["focus"] = focus_x(byid[it["shot"]]["col"], crop_frac_for(c["width"], c["height"], ow, oh))

    L = song["duration"]
    total_frames = int(round(L * fps))
    out = out.resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_suffix(".tmp.mp4")
    log = open(work / "ffmpeg.log", "ab")
    enc = subprocess.Popen(
        ["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{ow}x{oh}", "-r", str(fps),
         "-i", "-", "-ss", f"{song['start']:.3f}", "-t", f"{L:.3f}", "-i", song["path"],
         "-map", "0:v:0", "-map", "1:a:0", "-af", f"afade=t=in:d=0.03,afade=t=out:st={max(0.0, L - 0.8):.3f}:d=0.8",
         "-c:v", "libx264", "-preset", "medium", "-crf", str(crf), "-pix_fmt", "yuv420p",
         "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "-shortest", str(tmp)],
        stdin=subprocess.PIPE, stderr=log)
    scale = ow / 1080
    tl = title_layer(plan["title"], ow, oh) if plan.get("title") else None
    title_slot = 0 if plan.get("title_at") == "start" else len(items) - 1
    written = 0
    say(f"rendering {len(items)} cuts, {L:.1f}s at {fps} fps ...")
    try:
        for si, it in enumerate(items):
            for k, base in enumerate(decode_segment(clips[it["clip"]], it, (ow, oh), fps, grade, log)):
                frame = apply_fx(base, fx_at(it, k, fps, style, si == 0), ow, oh, scale)
                if tl is not None and si == title_slot:
                    rgb, alpha, y = tl
                    a = alpha * min(1.0, k / (0.3 * fps))
                    fx = fx_at(it, k, fps, style, si == 0)
                    if fx["dark"] > 0:
                        a = a * (1 - fx["dark"])
                    h = min(rgb.shape[0], oh - y)
                    region = frame[y:y + h].astype(np.float32)
                    frame = frame.copy()
                    frame[y:y + h] = (region * (1 - a[:h]) + rgb[:h] * a[:h]).astype(np.uint8)
                enc.stdin.write(np.ascontiguousarray(frame).tobytes())
                written += 1
        enc.stdin.close()
    except BrokenPipeError:
        pass
    if enc.wait() != 0 or not tmp.is_file():
        raise EditError(f"encoding failed, see {work / 'ffmpeg.log'}")
    if written != total_frames:
        raise EditError(f"internal timing error: wrote {written} frames, expected {total_frames}")

    mb = tmp.stat().st_size / 2**20
    if mb > MAX_MB:  # shrink to fit the upload limit
        vbr = int((MAX_MB * 0.9 * 8 * 2**20) / L - 192_000)
        run(["ffmpeg", "-y", "-v", "error", "-i", str(tmp), "-c:v", "libx264", "-b:v", str(vbr), "-maxrate", str(vbr),
             "-bufsize", str(vbr * 2), "-preset", "medium", "-pix_fmt", "yuv420p", "-c:a", "copy",
             "-movflags", "+faststart", str(out)])
        tmp.unlink()
    else:
        tmp.replace(out)
    log.close()

    review = review_sheet(work, out, items, fps, (ow, oh))
    edit = {"output": str(out), "size_mb": round(out.stat().st_size / 2**20, 2), "duration": L, "fps": fps,
            "format": fmt, "style": style, "grade": grade, "bpm": song["bpm"], "song_start": song["start"],
            "title": plan.get("title"), "review_sheet": review.name,
            "cuts": [{k: it[k] for k in ("kind", "f0", "f1", "shot", "clip", "src_start", "speed", "focus")} for it in items]}
    (work / "edit.json").write_text(json.dumps(edit, indent=1))
    say(f"done: {out} ({edit['size_mb']} MB). Review sheet: {review}")
    return edit


def review_sheet(work: Path, video: Path, items: list[dict], fps: int, out_wh: tuple[int, int]) -> Path:
    ow, oh = out_wh
    tw = 180 if ow < oh else 320
    th = int(round(tw * oh / ow))
    cols = 8 if ow < oh else 5
    font = find_font(13)
    times = [((it["f0"] + it["f1"]) / 2) / fps for it in items]
    with ThreadPoolExecutor(max_workers=4) as pool:
        frames = list(pool.map(lambda t: grab_frame(str(video), t, tw, th), times))
    rows = math.ceil(len(items) / cols)
    sheet = Image.new("RGB", (cols * tw, rows * (th + 20)), (18, 18, 22))
    draw = ImageDraw.Draw(sheet)
    for i, (it, im) in enumerate(zip(items, frames)):
        x, y = (i % cols) * tw, (i // cols) * (th + 20)
        sheet.paste(im, (x, y))
        draw.text((x + 4, y + th + 3), f"{i + 1} {it['kind']} #{it['shot']} {it['f0'] / fps:.2f}s",
                  fill=(235, 235, 235), font=font)
    p = work / "review.jpg"
    sheet.save(p, quality=85)
    return p


# ----------------------------------------------------------------------------- CLI

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    def add_analyze(p):
        p.add_argument("--clips", nargs="+", required=True, help="video files and/or folders (your own footage)")
        p.add_argument("--song", required=True, help="audio or video file with the song")
        p.add_argument("--length", type=float, default=20.0, help="edit length in seconds (default 20)")
        p.add_argument("--song-start", type=float, default=None, help="where in the song to start (default: auto, around the drop)")
        p.add_argument("--format", choices=sorted(FORMATS), default="vertical")
        p.add_argument("--max-shots", type=int, default=240, help="cap on shots kept for the contact sheets")

    def add_render(p, with_plan=True):
        if with_plan:
            p.add_argument("--plan", type=Path, default=None, help="plan.json with chosen shots (optional)")
        p.add_argument("--out", type=Path, default=None, help="output MP4 (default <work>/edit.mp4)")
        p.add_argument("--style", choices=["hype", "smooth"], default="hype")
        p.add_argument("--grade", choices=sorted(GRADES), default="punchy")
        p.add_argument("--fps", type=int, choices=[24, 30, 60], default=30)
        p.add_argument("--title", default=None, help="text shown on the last shot, e.g. 'GOJO SATORU'")
        p.add_argument("--crf", type=int, default=19)

    pa = sub.add_parser("analyze", help="analyse song + clips, write contact sheets")
    pa.add_argument("--work", type=Path, required=True)
    add_analyze(pa)
    pr = sub.add_parser("render", help="render the edit from an analysis (and optional plan)")
    pr.add_argument("--work", type=Path, required=True)
    pr.add_argument("--format", choices=sorted(FORMATS), default=None)
    add_render(pr)
    pu = sub.add_parser("auto", help="analyze + render, shots picked automatically")
    pu.add_argument("--work", type=Path, required=True)
    add_analyze(pu)
    add_render(pu, with_plan=False)

    a = ap.parse_args(argv)
    try:
        if a.cmd in ("analyze", "auto"):
            analyze(a.clips, a.song, a.work, a.length, a.song_start, a.format, a.max_shots)
        if a.cmd in ("render", "auto"):
            render(a.work, getattr(a, "plan", None), a.out or a.work / "edit.mp4", a.style, a.grade, a.fps,
                   a.title, a.format, a.crf)
    except EditError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
