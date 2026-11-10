#!/usr/bin/env python3
"""Wax & Wane - free sounds: every sound effect is one sound file from a human-made free pack, as it is.

Until 2.9 the sounds were built by a script (tools/make_audio.py, now retired): pack samples layered with tones
and noise the script made up. Since 2.10 the owner wants nothing generated, so each sound is now ONE pack file,
copied byte for byte:

  - this tool fetches the pack file (cached in ~/.cache/waxandwane_free_art, like tools/free_art.py),
  - copies it unchanged to assets/audio/sfx/<game name>.<ogg|wav> (the two short jingles: assets/audio/music/),
  - measures how loud it is and writes scripts/autoload/sfx_pack.gd: the dB that brings each file to the level
    the game's mix was made for (LEVEL below: what the 2.9 files measured), and the speed it is played at.
    Level and speed are set when the game plays the file; the file itself is never changed,
  - and writes assets/licenses/CREDITS_audio.txt: every game sound and the pack file it is.

Run it from wax-and-wane/:   python3 tools/free_sounds.py            (then: godot --headless --path . --import)
                              python3 tools/free_sounds.py --list     (the table with measurements, nothing written)

Needs ffmpeg (to measure) and numpy. Source: the public library github.com/series-ai/jam-ready-assets; every pack
there carries its own License.txt. Only CC0 packs are used. Nobody could listen where this was put together: the
choices follow the old recipes' main samples and the packs' own names, so they want a human ear before release.
"""
import os
import shutil
import subprocess
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX = os.path.join(ROOT, "assets", "audio", "sfx")
MUSIC = os.path.join(ROOT, "assets", "audio", "music")
CACHE = os.path.expanduser("~/.cache/waxandwane_free_art")
MEDIA = "https://media.githubusercontent.com/media/series-ai/jam-ready-assets/main/"
SR = 44100

# pack folder in the library -> (name, maker, licence, the maker's page)
PACKS = {
    "kenney-impact-sounds": ("Impact Sounds", "Kenney", "CC0", "https://kenney.nl/assets/impact-sounds"),
    "kenney-foley-sounds": ("Foley Sounds", "Kenney", "CC0", "https://kenney.nl/assets/foley-sounds"),
    "kenney-rpg-audio": ("RPG Audio", "Kenney", "CC0", "https://kenney.nl/assets/rpg-audio"),
    "kenney-interface-sounds": ("Interface Sounds", "Kenney", "CC0", "https://kenney.nl/assets/interface-sounds"),
    "kenney-sci-fi-sounds": ("Sci-Fi Sounds", "Kenney", "CC0", "https://kenney.nl/assets/sci-fi-sounds"),
    "kenney-digital-audio": ("Digital Audio", "Kenney", "CC0", "https://kenney.nl/assets/digital-audio"),
    "kenney-retro-sounds-1": ("Retro Sounds 1", "Kenney", "CC0", "https://kenney.nl/assets/retro-sounds-1"),
    "kenney-retro-sounds-2": ("Retro Sounds 2", "Kenney", "CC0", "https://kenney.nl/assets/retro-sounds-2"),
    "ninja-adventure": ("Ninja Adventure Asset Pack", "Pixel-boy and AAA", "CC0",
                        "https://pixel-boy.itch.io/ninja-adventure-asset-pack"),
}

IMPACT = "kenney-impact-sounds/audio/Audio/"
WOOSH = "kenney-foley-sounds/audio/Audio/Woosh/"
WATER = "kenney-foley-sounds/audio/Audio/Water/"
RPG = "kenney-rpg-audio/audio/Audio/"
UI = "kenney-interface-sounds/audio/Audio/"
SCIFI = "kenney-sci-fi-sounds/audio/Audio/"
DIGITAL = "kenney-digital-audio/audio/Audio/"
RETRO1 = "kenney-retro-sounds-1/audio/Audio/"
RETRO2 = "kenney-retro-sounds-2/audio/Audio/"
NA = "ninja-adventure/2D/top-down-rpg/Audio/Sounds/"
JINGLE = "ninja-adventure/2D/top-down-rpg/Audio/Jingles/"

# game sound -> pack file, or (pack file, speed): 1.2 plays it a fifth faster and higher, 0.6 slower and deeper
SOUNDS = {
    # the candle's own: a bolt of wax, where it lands, what it does
    "shoot": (WOOSH + "woosh4.ogg", 1.2), "shoot_2": (WOOSH + "woosh8.ogg", 1.2), "shoot_3": (WOOSH + "woosh5.ogg", 1.2),
    "hit_wall": IMPACT + "impactGeneric_light_000.ogg", "hit_wall_2": IMPACT + "impactGeneric_light_001.ogg",
    "hit_wall_3": IMPACT + "impactGeneric_light_003.ogg",
    "hit_enemy": IMPACT + "impactPunch_medium_002.ogg", "hit_enemy_2": IMPACT + "impactPunch_medium_001.ogg",
    "hit_enemy_3": IMPACT + "impactPunch_medium_004.ogg",
    "enemy_die": IMPACT + "impactPunch_heavy_001.ogg", "enemy_die_2": IMPACT + "impactPunch_heavy_003.ogg",
    "enemy_die_3": IMPACT + "impactPunch_heavy_004.ogg",
    "enemy_shoot": (WOOSH + "woosh7.ogg", 0.8),
    "player_hurt": IMPACT + "impactPunch_medium_003.ogg",
    "step": IMPACT + "footstep_carpet_000.ogg", "step_2": IMPACT + "footstep_carpet_001.ogg",
    "step_3": IMPACT + "footstep_carpet_003.ogg", "step_4": IMPACT + "footstep_grass_003.ogg",
    "dodge": (WOOSH + "woosh3.ogg", 1.2),
    "charge": NA + "Bonus/PowerUp1.wav", "charge_up": DIGITAL + "powerUp3.ogg",
    "teleport": DIGITAL + "phaseJump3.ogg",
    "snuff_out": (UI + "close_002.ogg", 0.8),
    "low_wax": NA + "Alert/Alert2.wav", "low_wax_tick": UI + "tick_004.ogg",
    # pickups and the shop
    "wax_pickup": UI + "drop_002.ogg",
    "coin_pickup": UI + "glass_002.ogg", "coin_pickup_2": UI + "glass_003.ogg", "coin_pickup_3": (UI + "glass_001.ogg", 1.05),
    "bomb_pickup": IMPACT + "impactMetal_heavy_002.ogg", "bomb_place": IMPACT + "impactPlate_light_000.ogg",
    "shop_buy": RPG + "handleCoins.ogg", "chest_open": RPG + "creak1.ogg", "unlock": RPG + "metalLatch.ogg",
    "item_get": JINGLE + "Secret1.wav", "relic_fanfare": JINGLE + "LevelUp2.wav", "achievement": JINGLE + "LevelUp1.wav",
    "room_clear": JINGLE + "Success1.wav", "victory": JINGLE + "Success3.wav",
    # the house: doors, things that break, fire and water
    "door_open": RPG + "doorOpen_1.ogg", "door_close": RPG + "doorClose_4.ogg", "trapdoor": RPG + "doorClose_3.ogg",
    "door_burst": IMPACT + "impactPlank_medium_001.ogg",
    "urn_break": IMPACT + "impactGlass_heavy_003.ogg", "crate_break": RPG + "chop.ogg",
    "jar_explode": IMPACT + "impactGlass_heavy_002.ogg",
    "explosion": SCIFI + "explosionCrunch_001.ogg",
    "splash": NA + "Elemental/Water1.wav", "splash_2": NA + "Elemental/Water2.wav", "splash_3": NA + "Elemental/Water4.wav",
    "splat": (WATER + "drip2.ogg", 0.8), "gib": NA + "Elemental/Water9.wav",
    "match_strike": (UI + "scratch_004.ogg", 0.85), "burn_whoosh": NA + "Elemental/Fireball2.wav",
    "sizzle": NA + "Elemental/Fire3.wav", "fire_crackle": NA + "Elemental/Fire2.wav",
    "wax_bubble": NA + "Elemental/Bubble2.wav", "web": (RPG + "cloth3.ogg", 0.8),
    "moth_flutter": NA + "Creature/Wings2.wav", "summon": NA + "Magic & Skill/Spirit.wav",
    "thud_heavy": IMPACT + "impactPunch_heavy_000.ogg",
    "beam_loop": SCIFI + "engineCircular_002.ogg",
    # the guardians and the clock
    "boss_roar": (WOOSH.replace("Woosh", "Rocks") + "stoneDrag1.ogg", 0.8), "boss_sting": (RETRO1 + "rumble1.ogg", 0.7),
    "boss_die": SCIFI + "explosionCrunch_004.ogg",
    "bell_toll": (IMPACT + "impactBell_heavy_001.ogg", 0.5), "bell_small": (IMPACT + "impactBell_heavy_000.ogg", 1.5),
    "tick": UI + "tick_004.ogg", "clock_tick_fast": UI + "tick_001.ogg",
    # menus
    "ui_click": UI + "select_002.ogg", "ui_back": UI + "back_002.ogg", "ui_move": UI + "tick_002.ogg",
    "ui_open": RPG + "bookOpen.ogg", "page_flip": RPG + "bookFlip2.ogg",
}

# the two short pieces of music that the script used to compose: pack jingles now
JINGLES = {"victory_jingle": JINGLE + "Success4.wav", "death_jingle": JINGLE + "GameOver3.wav"}

# how loud the 2.9 files were (dB, the loudest 0.3 s of each): the level the game's mix (Audio.VOLUME) expects
LEVEL = {'achievement': -16.5,
 'beam_loop': -15.7,
 'bell_small': -16.3,
 'bell_toll': -10.4,
 'bomb_pickup': -19.6,
 'bomb_place': -20.4,
 'boss_die': -10.1,
 'boss_roar': -11.0,
 'boss_sting': -8.8,
 'burn_whoosh': -16.4,
 'charge': -18.4,
 'charge_up': -18.0,
 'chest_open': -21.0,
 'clock_tick_fast': -22.6,
 'coin_pickup': -23.1,
 'coin_pickup_2': -22.1,
 'coin_pickup_3': -22.8,
 'crate_break': -18.0,
 'death_jingle': -14.9,
 'dodge': -23.6,
 'door_burst': -14.4,
 'door_close': -16.7,
 'door_open': -20.4,
 'enemy_die': -15.8,
 'enemy_die_2': -15.7,
 'enemy_die_3': -16.5,
 'enemy_shoot': -18.0,
 'explosion': -7.7,
 'fire_crackle': -18.9,
 'gib': -16.1,
 'hit_enemy': -18.9,
 'hit_enemy_2': -18.4,
 'hit_enemy_3': -18.8,
 'hit_wall': -16.9,
 'hit_wall_2': -17.5,
 'hit_wall_3': -15.5,
 'item_get': -14.7,
 'jar_explode': -13.4,
 'low_wax': -10.2,
 'low_wax_tick': -14.0,
 'match_strike': -18.2,
 'moth_flutter': -24.5,
 'page_flip': -26.1,
 'player_hurt': -17.3,
 'relic_fanfare': -13.1,
 'room_clear': -16.0,
 'shoot': -19.3,
 'shoot_2': -19.1,
 'shoot_3': -20.2,
 'shop_buy': -18.5,
 'sizzle': -21.3,
 'snuff_out': -17.3,
 'splash': -21.1,
 'splash_2': -21.1,
 'splash_3': -21.0,
 'splat': -14.1,
 'step': -19.4,
 'step_2': -19.9,
 'step_3': -20.6,
 'step_4': -20.1,
 'summon': -14.0,
 'teleport': -18.3,
 'thud_heavy': -9.8,
 'tick': -21.3,
 'trapdoor': -17.2,
 'ui_back': -18.6,
 'ui_click': -17.8,
 'ui_move': -19.7,
 'ui_open': -22.4,
 'unlock': -17.3,
 'urn_break': -18.9,
 'victory': -12.7,
 'victory_jingle': -10.9,
 'wax_bubble': -18.2,
 'wax_pickup': -18.6,
 'web': -18.7}


def fetch(path):
    dst = os.path.join(CACHE, path)
    if not (os.path.exists(dst) and os.path.getsize(dst) > 200):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        url = MEDIA + path.replace(" ", "%20").replace("&", "%26")
        subprocess.run(["curl", "-sS", "-L", "--fail", "--max-time", "90", "-o", dst, url], check=True)
    return dst


def decode(path):
    r = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                       capture_output=True, check=True)
    return np.frombuffer(r.stdout, np.float32).astype(np.float64)


def measure(path):
    """(seconds until it has died away, level dB of its loudest 0.3 s, peak dB, where its weight sits in Hz)."""
    x = decode(path)
    if len(x) == 0 or np.max(np.abs(x)) <= 0:
        return 0.0, -120.0, -120.0, 0.0
    peak = float(np.max(np.abs(x)))
    loud = np.where(np.abs(x) > peak * 10 ** (-40 / 20.0))[0]
    dur = (loud[-1] - loud[0] + 1) / SR
    win = min(len(x), int(0.3 * SR))
    c = np.concatenate([[0.0], np.cumsum(x * x)])
    rms = np.sqrt(np.max(c[win:] - c[:-win]) / win) if len(x) > win else np.sqrt(np.mean(x * x))
    spec = np.abs(np.fft.rfft(x * np.hanning(len(x))))
    freq = np.fft.rfftfreq(len(x), 1.0 / SR)
    centroid = float(np.sum(spec * freq) / max(1e-9, np.sum(spec)))
    return dur, 20 * np.log10(max(rms, 1e-9)), 20 * np.log10(peak), centroid


def level_gain(want, level, peak):
    """dB to add when the file plays: down as far as needed; up at most 9 dB and never past full scale (a file
    that already peaks at full scale is not raised at all)."""
    g = min(want - level, 9.0)
    if g > 0.0:
        g = min(g, max(0.0, -0.5 - peak))
    return round(float(g), 1)


def spec_of(v):
    return (v, 1.0) if isinstance(v, str) else v


def place(name, src, folder):
    """Copy the pack file, unchanged, under the game's name; a file of that name with the other ending goes."""
    ext = os.path.splitext(src)[1].lower()
    for e in (".ogg", ".wav"):
        old = os.path.join(folder, name + e)
        if e != ext and os.path.exists(old):
            os.remove(old)
            if os.path.exists(old + ".import"):
                os.remove(old + ".import")
    dst = os.path.join(folder, name + ext)
    shutil.copyfile(fetch(src), dst)
    return dst


def main():
    only_list = "--list" in sys.argv
    rows, gain, pitch, credits = [], {}, {}, {}
    for name in sorted(SOUNDS):
        src, speed = spec_of(SOUNDS[name])
        dur, level, peak, cen = measure(fetch(src))
        g = level_gain(LEVEL.get(name, -20.0), level, peak)
        gain[name] = g
        if abs(speed - 1.0) > 0.001:
            pitch[name] = speed
        rows.append("%-18s %-62s %5.2f s  level %6.1f  peak %5.1f  %5.0f Hz  gain %+5.1f  x%.2f"
                    % (name, src.split("/", 1)[1][-62:], dur / speed, level, peak, cen, g, speed))
        credits.setdefault(src.split("/")[0], []).append((name + os.path.splitext(src)[1].lower(), src, speed, "sfx"))
        if not only_list:
            place(name, src, SFX)
    for name in sorted(JINGLES):
        src, speed = spec_of(JINGLES[name])
        dur, level, peak, cen = measure(fetch(src))
        gain[name] = level_gain(LEVEL.get(name, -14.0), level, peak)
        rows.append("%-18s %-62s %5.2f s  level %6.1f  peak %5.1f  gain %+5.1f  (music)"
                    % (name, src.split("/", 1)[1][-62:], dur, level, peak, gain[name]))
        credits.setdefault(src.split("/")[0], []).append((name + os.path.splitext(src)[1].lower(), src, speed, "music"))
        if not only_list:
            place(name, src, MUSIC)
    print("\n".join(rows))
    if only_list:
        return
    for stale in STALE:
        for e in (".ogg", ".wav"):
            f = os.path.join(SFX, stale + e)
            for g_ in (f, f + ".import"):
                if os.path.exists(g_):
                    os.remove(g_)
    with open(os.path.join(ROOT, "scripts", "autoload", "sfx_pack.gd"), "w") as f:
        f.write("class_name SfxPack\nextends RefCounted\n"
                "## Written by tools/free_sounds.py (do not edit by hand): every sound effect is one pack file, as it\n"
                "## is. GAIN: the dB that brings a file to the level the game's mix (Audio.VOLUME) was made for.\n"
                "## PITCH: the speed a file is played at. Both are applied when the sound plays (Audio.take_gain /\n"
                "## take_pitch); the files themselves are never changed.\n\n")
        f.write("const GAIN := {\n" + "".join('\t"%s": %.1f,\n' % (k, gain[k]) for k in sorted(gain)) + "}\n\n")
        f.write("const PITCH := {\n" + "".join('\t"%s": %.2f,\n' % (k, pitch[k]) for k in sorted(pitch)) + "}\n")
    lines = ["Wax & Wane - sound credits (tools/free_sounds.py writes this file)", "",
             "Every sound effect is ONE sound file from a free pack, copied byte for byte: nothing is layered,",
             "synthesized, trimmed or re-encoded. The game sets each file's level and, where a number follows the",
             "file below, its speed, when it plays it. The music is listed in CREDITS_music.txt.",
             "The packs are in the public library https://github.com/series-ai/jam-ready-assets, each with its own",
             "License.txt; all are CC0 1.0 (public domain: credit appreciated, not required).", ""]
    for pack in sorted(credits):
        title, who, lic, url = PACKS[pack]
        lines.append("== %s by %s (%s) - %s" % (title, who, lic, url))
        for out, src, speed, kind in sorted(credits[pack]):
            lines.append("assets/audio/%s/%-22s <-  %s%s" % (kind, out, src.split("/", 1)[1],
                                                           "" if abs(speed - 1.0) < 0.001 else "   (played x%.2f)" % speed))
        lines.append("")
    with open(os.path.join(ROOT, "assets", "licenses", "CREDITS_audio.txt"), "w") as f:
        f.write("\n".join(lines))
    print("[free_sounds] %d sounds and %d jingles placed; levels: scripts/autoload/sfx_pack.gd; credits: "
          "assets/licenses/CREDITS_audio.txt" % (len(SOUNDS), len(JINGLES)))


# sounds the game no longer has as files (see scripts/autoload/audio.gd: the low-wax tick is timed in code)
STALE = ["low_wax_loop"]

if __name__ == "__main__":
    main()
