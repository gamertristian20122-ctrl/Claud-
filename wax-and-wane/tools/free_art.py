#!/usr/bin/env python3
"""Wax & Wane - free art: pictures taken from human-made free packs, in place of the ones scripts drew.

Since 2.10 the owner wants every picture that is not Tallow to come from a pack a person drew ("don't generate
anything"). This tool is the only way such a picture enters the game:

  - it fetches the pack file (cached in ~/.cache/waxandwane_free_art),
  - cuts frames out of it. A frame is a crop: no pixel is changed, recoloured or scaled,
  - writes the game's frame files (assets/art/<target>_<anim>_f<i>.png),
  - and writes assets/licenses/CREDITS_free_art.txt: every game file and the pack file and rectangle it is.

Run it from wax-and-wane/:   python3 tools/free_art.py            (then: godot --headless --path . --import)
                              python3 tools/free_art.py --list     (what comes from where, nothing written)

Source: the public library github.com/series-ai/jam-ready-assets (the same one tools/import_audio.py takes the
music from). Every pack there carries its own License.txt; only CC0 packs made by people are used here.
NEVER use its `angais-pixel-art-atlas` or `codepawl-pixel-art-atlas-models`: those are AI-generated.
"""
import glob
import os
import subprocess
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "assets", "art")
CACHE = os.path.expanduser("~/.cache/waxandwane_free_art")
MEDIA = "https://media.githubusercontent.com/media/series-ai/jam-ready-assets/main/"

# pack folder in the library -> (what to call it in the credits, who made it, licence, where it lives)
PACKS = {
    "ninja-adventure": ("Ninja Adventure Asset Pack", "Pixel-boy and AAA", "CC0",
                        "https://pixel-boy.itch.io/ninja-adventure-asset-pack"),
    "0x72": ("16x16 DungeonTileset II", "0x72", "CC0", "https://0x72.itch.io/dungeontileset-ii"),
    "foozle-lucifer-skeleton-ancient": ("Lucifer: Ancient Skeleton", "Foozle (drawn by Baldur)", "CC0",
                                        "https://foozlecc.itch.io/"),
}

NA_MON = "ninja-adventure/2D/top-down-rpg/Actor/Monster/%s/%s.png"


def na(name, fname="SpriteSheet"):
    """A Ninja Adventure monster sheet: 64 x 64, a column per direction (front, back, left, right), a row per
    step. The game shows the front column only: the face stays readable, and its left / right flip is harmless."""
    p = NA_MON % (name, fname)
    front = [(p, (0, r * 16, 16, 16)) for r in range(4)]
    return {"idle": [front[0], front[0], front[1], front[1]], "run": front, "atk": front}


def ox72(names):
    """0x72's own frames from assets/0x72/frames, whole and unchanged, under the game's frame names (its zombie
    ships as f10, f1, f2, f3 with no f0, which the game's loader does not find by itself)."""
    fr = [("0x72/" + n, None) for n in names]
    return {"idle": fr, "run": fr[1:] + fr[:1]}


def with_anims(spec, **extra):
    """More animations out of the same frames (indices into the standing frames)."""
    front = [spec["atk"][i] for i in range(4)]
    out = dict(spec)
    for a, idx in extra.items():
        out[a] = [front[i] for i in idx]
    return out


# game picture (under assets/art/) -> animation -> frames
CREATURES = {
    "monsters/cinder_rat": na("MouseBlack"),
    "monsters/clapper_bat": na("BlueBat"),
    "monsters/cog_sentry": na("Eye2", "Eye2"),
    "monsters/deathwatch": na("Larva", "Larva"),
    "monsters/grave_hand": with_anims(na("Skull"), mound=[0], rise=[0, 1, 2], grab=[1]),
    "monsters/gutterspout": na("GreenOctopus"),
    "monsters/minute_wraith": na("SkullBlue"),
    "monsters/moth": na("Butterfly"),
    "monsters/psalter": na("LanternRed"),
    "monsters/sootling": na("Beast2", "Beast2"),
    "monsters/wax_bit": na("Mole2", "Mole2"),
    "monsters/wax_blob": na("Mole", "Mole"),
    "monsters/wisp": na("Flam2"),
    "monsters/zombie": ox72(["zombie_anim_f10", "zombie_anim_f1", "zombie_anim_f2", "zombie_anim_f3"]),
    "areas/kitchen/lid_crab": na("Mollusc", "Mollusc"),
    "areas/kitchen/flour_ghost": na("Spirit"),
    "areas/library/bookworm": na("Snake3", "Snake3"),
    "areas/library/inkblot": na("Octopus2"),
    "areas/library/ink_drop": na("Slime3", "Slime3"),
}

NA_BOSS = "ninja-adventure/2D/top-down-rpg/Actor/Boss/%s/%s.png"
ANCIENT = "foozle-lucifer-skeleton-ancient/2D/characters/Down/Png/AncientSkeleton%s.png"


def strip(path, w, h, pick=None):
    """Frames of a one-row strip, w x h each (all of them, or the ones in `pick`)."""
    n = Image.open(fetch(path)).width // w
    return [(path, (i * w, 0, w, h)) for i in (pick if pick is not None else range(n))]


def boss(name, w, h, idle="Idle", run=None, atk=None, **more):
    """A Ninja Adventure guardian: strips of w x h frames. `run` / `atk` / more: a strip's name, or a
    (name, [frames]) pair; left out, the idle strip stands in (a strip of another frame size would jump)."""
    def get(a):
        if a is None:
            a = idle
        if isinstance(a, tuple):
            return strip(NA_BOSS % (name, a[0]), w, h, a[1])
        return strip(NA_BOSS % (name, a), w, h)
    out = {"idle": get(idle), "run": get(run), "atk": get(atk)}
    for k, v in more.items():
        out[k] = get(v)
    return out


def ancient():
    def g(a, pick=None):
        return strip(ANCIENT % a, 80, 80, pick)
    return {"idle": g("DownIdle"), "run": g("DownWalk"), "atk": g("DownAttack01"),
            "mound": g("DownIdle", [0]), "rise": g("DownIdle", [0, 1, 2])}


# the guardians keep their names and their talk: these are stand-ins, picked to suit what each one says
def guardians():
    return {
        "monsters/furnace": boss("GiantFlam", 50, 50, mound=("Idle", [0, 1])),
        "monsters/wax_mother": boss("DemonCyclop", 50, 50, run="Walk"),
        "monsters/choir": boss("GiantSpirit", 50, 50, sing="Idle"),
        "monsters/necro_boss": boss("GiantRedSamurai", 96, 48, run="Walk"),
        "monsters/organist": boss("SquidRed", 76, 79, run="Walk", atk="Attack", sing="AttackLoop"),
        "monsters/ossuary": ancient(),
        "monsters/ossuary_roll": {"": [(NA_MON % ("Skull", "SpriteSheet"), (0, r * 16, 16, 16)) for r in range(4)]},
        "monsters/pendulum": boss("DemonCyclop2", 50, 50, run="Walk"),
        "monsters/sexton": boss("GiantRacoon", 60, 60, run="Jump", atk="Attack", mound="Charge"),
        "monsters/weathercock": boss("TenguRed", 82, 82, run="Walk", atk=("Attack", list(range(8))),
                                     grab=("Attack", [8, 9, 10, 11])),
        "monsters/keeper": boss("GiantBlueSamurai", 96, 48, run="Walk"),
        "areas/attic/dress_form": boss("GiantBamboo2", 62, 62, run="Walk", atk="Attack"),
        "areas/kitchen/stockpot": boss("GiantSlime2", 62, 52, run="Jump"),
        "areas/library/librarian": boss("TenguBlue", 68, 68),
    }


# pictures a script drew that are simply taken away: the game then shows 0x72's own frames for that creature
# (Enemy.frames_for falls back to assets/0x72/frames; Enemy.DEFS "sprite" names the 0x72 sprite where it differs)
REMOVED = [
    "monsters/tiny_slug", "monsters/tiny_zombie", "monsters/goblin", "monsters/muddy",
    "monsters/snuffer",        # -> 0x72 dwarf_m
    "monsters/waxwork",        # -> 0x72 elf_f
    "areas/attic/mannequin",   # -> 0x72 knight_m
    "areas/attic/trunk",       # -> 0x72 chest_full_open
]

SETS = [("creatures", lambda: CREATURES), ("guardians", guardians)]


def fetch(path):
    if path.startswith("0x72/"):   # already in the game, as 0x72 made it
        return os.path.join(ROOT, "assets", "0x72", "frames", path[5:] + ".png")
    dst = os.path.join(CACHE, path)
    if not (os.path.exists(dst) and os.path.getsize(dst) > 200):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        url = MEDIA + path.replace(" ", "%20")
        subprocess.run(["curl", "-sS", "-L", "--fail", "--max-time", "90", "-o", dst, url], check=True)
    return dst


def clear(target):
    for f in glob.glob(os.path.join(ART, target + "_*.png")) + glob.glob(os.path.join(ART, target + "_*.png.import")):
        os.remove(f)


def main():
    only_list = "--list" in sys.argv
    credits = {}
    n = 0
    for _set, table in SETS:
        for target, anims in sorted(table().items()):
            if not only_list:
                clear(target)
            for anim, frames in anims.items():
                for i, (src, box) in enumerate(frames):
                    out = ("%s_%s_f%d.png" % (target, anim, i)) if anim else ("%s_f%d.png" % (target, i))
                    credits.setdefault(src.split("/")[0], []).append((out, src, box))
                    if only_list:
                        continue
                    im = Image.open(fetch(src)).convert("RGBA")
                    if box:
                        x, y, w, h = box
                        im = im.crop((x, y, x + w, y + h))
                    os.makedirs(os.path.dirname(os.path.join(ART, out)), exist_ok=True)
                    im.save(os.path.join(ART, out))
                    n += 1
    if not only_list:
        for target in REMOVED:
            clear(target)
    lines = ["Wax & Wane - pictures taken from free packs (tools/free_art.py writes this file)",
             "Every file below is a crop of the pack file named beside it: x, y, width, height. No pixel was changed.",
             "The packs are in the public library https://github.com/series-ai/jam-ready-assets, each with its own",
             "License.txt; the makers' own pages are named here.", ""]
    for pack in sorted(credits):
        title, who, lic, url = PACKS[pack]
        lines += ["== %s by %s (%s) - %s" % (title, who, lic, url)]
        for out, src, box in sorted(credits[pack]):
            lines.append("assets/art/%s  <-  %s  %s" % (out, src.split("/", 1)[1], list(box) if box else "(whole)"))
        lines.append("")
    lines += ["== Shown as 0x72's own frames again (the redrawn copies were taken out): " + ", ".join(REMOVED), ""]
    text = "\n".join(lines)
    if only_list:
        print(text)
        return
    with open(os.path.join(ROOT, "assets", "licenses", "CREDITS_free_art.txt"), "w") as f:
        f.write(text)
    print("[free_art] %d frames written, %d redrawn sets removed; credits: assets/licenses/CREDITS_free_art.txt"
          % (n, len(REMOVED)))


if __name__ == "__main__":
    main()
