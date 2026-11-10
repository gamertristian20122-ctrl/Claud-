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
    "16x16-rpg-item-pack": ("16x16 RPG Item Pack", "Alex's Assets", "CC0",
                            "https://alexs-assets.itch.io/16x16-rpg-item-pack"),
    "foozle-lucifer-skeleton-ancient": ("Lucifer: Ancient Skeleton", "Foozle (drawn by Baldur)", "CC0",
                                        "https://foozlecc.itch.io/lucifer-skeleton-ancient-boss"),
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


NA_ANIMAL = "ninja-adventure/2D/top-down-rpg/Actor/Animal/%s/SpriteSheet.png"


def face(name, fname="SpriteSheet"):
    """One standing frame of a Ninja Adventure monster, as an icon."""
    return (NA_MON % (name, fname), (0, 0, 16, 16))


def pair(path):
    """Two steps of a small follower."""
    return {"": [(path, (0, 0, 16, 16)), (path, (0, 16, 16, 16))]}


# relic, keepsake and pickup icons: one whole pack file each (the picks are mine, the pictures are theirs)
ICONS = {
    "items/beeswax": "ninja-adventure/2D/top-down-rpg/Items/Food/Honey.png",
    "items/bell_rope": "ninja-adventure/2D/top-down-rpg/Items/Weapons/Whip/Sprite.png",
    "items/bell_wire": "ninja-adventure/2D/top-down-rpg/Items/Weapons/Ninjaku/Sprite.png",
    "items/bellows": "ninja-adventure/2D/top-down-rpg/Items/Object/Gourd.png",
    "items/blowlamp": "16x16-rpg-item-pack/2D/top-down-rpg/Item__23.png",
    "items/blue_flame": "16x16-rpg-item-pack/2D/top-down-rpg/Item__30.png",
    "items/both_ends": "ninja-adventure/2D/top-down-rpg/Items/Weapons/Sai/Sprite.png",
    "items/candelabra": "16x16-rpg-item-pack/2D/top-down-rpg/Item__70.png",
    "items/cold_wax": "ninja-adventure/2D/top-down-rpg/Items/Scroll/ScrollIce.png",
    "items/collection_plate": "16x16-rpg-item-pack/2D/top-down-rpg/Item__27.png",
    "items/cuckoo_clock": "ninja-adventure/2D/top-down-rpg/Items/Treasure/LittleTreasureChest.png",
    "items/dowsing_rod": "ninja-adventure/2D/top-down-rpg/Items/Resource/Branch.png",
    "items/dust_bunny": "ninja-adventure/2D/top-down-rpg/Items/Food/Nut.png",
    "items/ember_heart": "ninja-adventure/2D/top-down-rpg/Items/Resource/GemRed.png",
    "items/fire_tongs": "ninja-adventure/2D/top-down-rpg/Items/Weapons/Fork/Sprite.png",
    "items/glass_chimney": "ninja-adventure/2D/top-down-rpg/Items/Potion/EmptyPot.png",
    "items/honeycomb": "16x16-rpg-item-pack/2D/top-down-rpg/Item__65.png",
    "items/hot_drip": "ninja-adventure/2D/top-down-rpg/Items/Scroll/ScrollFire.png",
    "items/hourglass": "ninja-adventure/2D/top-down-rpg/Items/Object/Hourglass.png",
    "items/house_deed": "16x16-rpg-item-pack/2D/top-down-rpg/Item__38.png",
    "items/iron_stick": "ninja-adventure/2D/top-down-rpg/Items/Weapons/Stick/Sprite.png",
    "items/jet_brooch": "16x16-rpg-item-pack/2D/top-down-rpg/Item__34.png",
    "items/ks_censer": "ninja-adventure/2D/top-down-rpg/Items/Object/MoneyBag.png",
    "items/ks_flare_match": "ninja-adventure/2D/top-down-rpg/Items/Projectile/Dynamite.png",
    "items/ks_hand_bell": "ninja-adventure/2D/top-down-rpg/Items/Treasure/GoldCup.png",
    "items/ks_hand_mirror": "16x16-rpg-item-pack/2D/top-down-rpg/Item__25.png",
    "items/ks_music_box": "ninja-adventure/2D/top-down-rpg/Items/Treasure/BigTreasureChest.png",
    "items/ks_oil_jug": "ninja-adventure/2D/top-down-rpg/Items/Potion/LifePot.png",
    "items/ks_smoke_jar": "16x16-rpg-item-pack/2D/top-down-rpg/Item__31.png",
    "items/ks_winding_key": "16x16-rpg-item-pack/2D/top-down-rpg/Item__69.png",
    "items/lace_fan": "ninja-adventure/2D/top-down-rpg/Items/Object/PanFlute.png",
    "items/lamp_oil": "ninja-adventure/2D/top-down-rpg/Items/Potion/WaterPot.png",
    "items/lodestone": "ninja-adventure/2D/top-down-rpg/Items/Resource/Rock.png",
    "items/love_letter": "ninja-adventure/2D/top-down-rpg/Items/Other/Letter.png",
    "items/lucky_ash": "16x16-rpg-item-pack/2D/top-down-rpg/Item__39.png",
    "items/magpie_nest": "16x16-rpg-item-pack/2D/top-down-rpg/Item__56.png",
    "items/matchbook": "ninja-adventure/2D/top-down-rpg/Items/Weapons/Book/Sprite.png",
    "items/matchling": "16x16-rpg-item-pack/2D/top-down-rpg/Item__28.png",
    "items/minute_hand": "ninja-adventure/2D/top-down-rpg/Items/Weapons/Lance/Sprite.png",
    "items/nightshade": "ninja-adventure/2D/top-down-rpg/Items/Resource/Grass.png",
    "items/old_pipe": "ninja-adventure/2D/top-down-rpg/Items/Weapons/Club/Sprite.png",
    "items/pale_taper": "ninja-adventure/2D/top-down-rpg/Items/Scroll/Scroll.png",
    "items/pantry_key": "16x16-rpg-item-pack/2D/top-down-rpg/Item__68.png",
    "items/pendulum": "16x16-rpg-item-pack/2D/top-down-rpg/Item__33.png",
    "items/phoenix_feather": "ninja-adventure/2D/top-down-rpg/Items/Resource/feather.png",
    "items/pocket_watch": "ninja-adventure/2D/top-down-rpg/Items/Treasure/GoldCoin.png",
    "items/powder_tin": "ninja-adventure/2D/top-down-rpg/Items/Potion/MilkPot.png",
    "items/salt_line": "ninja-adventure/2D/top-down-rpg/Items/Projectile/Caltrop.png",
    "items/scalding_wax": "16x16-rpg-item-pack/2D/top-down-rpg/Item__29.png",
    "items/shadow_puppet": "16x16-rpg-item-pack/2D/top-down-rpg/Item__55.png",
    "items/sharp_wick": "ninja-adventure/2D/top-down-rpg/Items/Projectile/Kunai.png",
    "items/slow_burn": "ninja-adventure/2D/top-down-rpg/Items/Tool/WateringCan.png",
    "items/snuffer_cap": "16x16-rpg-item-pack/2D/top-down-rpg/Item__44.png",
    "items/soft_soles": "16x16-rpg-item-pack/2D/top-down-rpg/Item__48.png",
    "items/spare_wick": "16x16-rpg-item-pack/2D/top-down-rpg/Item__37.png",
    "items/split_wick": "ninja-adventure/2D/top-down-rpg/Items/Weapons/Axe/Sprite.png",
    "items/stopped_clock": "16x16-rpg-item-pack/2D/top-down-rpg/Item__24.png",
    "items/stove_door": "ninja-adventure/2D/top-down-rpg/Items/Tool/Anvil.png",
    "items/sweep_brush": "ninja-adventure/2D/top-down-rpg/Items/Tool/Hoe.png",
    "items/tallow_heart": "ninja-adventure/2D/top-down-rpg/Items/Potion/Heart.png",
    "items/thimble": "ninja-adventure/2D/top-down-rpg/Items/Treasure/SilverCup.png",
    "items/tin_sconce": "16x16-rpg-item-pack/2D/top-down-rpg/Item__71.png",
    "items/tinderbox": "ninja-adventure/2D/top-down-rpg/Items/Object/CrateEmpty.png",
    "items/twin_wick": "ninja-adventure/2D/top-down-rpg/Items/Food/SeedBig2.png",
    "items/warming_pan": "16x16-rpg-item-pack/2D/top-down-rpg/Item__26.png",
    "items/wax_coat": "16x16-rpg-item-pack/2D/top-down-rpg/Item__57.png",
    "items/wax_seal": "ninja-adventure/2D/top-down-rpg/Items/Other/Stamp.png",
    "items/wick_trimmer": "ninja-adventure/2D/top-down-rpg/Items/Tool/Sickle.png",
    "items/will_o_wisp": "ninja-adventure/2D/top-down-rpg/Items/Resource/GemPurple.png",
    "items/witching_hour": "16x16-rpg-item-pack/2D/top-down-rpg/Item__52.png",
    "pickups/bomb_pickup": "ninja-adventure/2D/top-down-rpg/Items/Projectile/Bomb.png",
    "pickups/match": "ninja-adventure/2D/top-down-rpg/Items/Weapons/MagicWand/Sprite.png",
    "pickups/wax_big": "ninja-adventure/2D/top-down-rpg/Items/Food/SeedLargeWhite.png",
    "pickups/wax_small": "ninja-adventure/2D/top-down-rpg/Items/Food/Seed2.png",
}
ICONS.update({
    "items/clockwork_mouse": face("Mouse"),
    "items/moth_friend": face("ButterflyBlue"),
    "items/paper_lantern": face("LanternGreen"),
    "items/fam_mouse": pair(NA_MON % ("Mouse", "SpriteSheet")),
    "items/fam_lantern": pair(NA_MON % ("LanternGreen", "SpriteSheet")),
    "items/fam_coal": pair(NA_MON % ("Flam", "SpriteSheet")),
    "items/fam_matchling": pair(NA_MON % ("Spirit2", "SpriteSheet")),
    "items/fam_bunny": pair(NA_ANIMAL % "Hamster"),
    "pickups/pedestal": "0x72/crate",
})


FX = "ninja-adventure/2D/top-down-rpg/FX/%s.png"
NA_ITEM = "ninja-adventure/2D/top-down-rpg/Items/%s.png"


def fx(name, w, h, pick=None):
    return strip(FX % name, w, h, pick)


# shots, bursts and special-move effects (the floor stains and the shockwave ring are plain shapes drawn by
# the game itself now: Stains._shape, MoveFx)
def effects():
    P = "Projectile/"
    return {
        "fx/ember": {"": fx(P + "Fireball", 16, 16)},
        "fx/ember_big": {"": fx(P + "SpriteSheetRock", 16, 16)},
        "fx/ember_blue": {"": fx("Particle/Spark", 10, 8, [1, 2, 3, 4])},
        "fx/bolt_bone": {"": fx("Particle/RockGray", 16, 16, [3, 4])},
        "fx/bolt_cog": {"": fx(P + "Shuriken", 16, 16)},
        "fx/bolt_page": {"": fx(P + "ShurikenMagic", 16, 16, [0, 0])},
        "fx/bolt_pin": {"": fx(P + "Kunai", 14, 5, [0, 0])},
        "fx/bolt_ring": {"": fx("Particle/RainOnFloor", 8, 8, [1, 2])},
        "fx/bolt_wax": {"": fx("Particle/Snow", 8, 8, [3, 4])},
        "fx/bullet_green": {"": fx("Particle/Leaf", 12, 7, [0, 1])},
        "fx/bullet_purple": {"": fx(P + "ShurikenMagic", 16, 16, [1, 1])},
        "fx/bullet_water": {"": fx(P + "EnergyBall", 16, 16, [0, 1])},
        "fx/explosion": {"": fx("Elemental/Explosion/SpriteSheet", 40, 40)},
        "fx/glint": {"": fx("Particle/Spark", 10, 8, [2, 3])},
        "fx/poof": {"": fx("Smoke/Smoke/SpriteSheet", 32, 32)},
        "fx/smoke": {"": fx("Smoke/Smoke/SpriteSheet", 32, 32, [2, 3, 4, 5])},
        "moves/blackflame": {"": fx(P + "CanonBall", 16, 16, [0, 1, 2, 3])},
        "moves/blink": {"": fx("Magic/Spirit/SpriteSheet", 32, 32)},
        "moves/burst": {"": fx("Elemental/Flam/SpriteSheet", 25, 30, [1, 2, 3])},
        "moves/relight": {"": fx("Particle/Fire", 8, 12, [3, 5, 7])},
        "moves/spark": {"": fx("Particle/Spark", 10, 8, [0, 1, 2])},
        "moves/ring": {"": fx("Magic/Circle/SpriteSheetWhite", 32, 32)},
        "moves/icon_flare": (FX % (P + "Fireball"), (0, 0, 16, 16)),
        "moves/icon_blink": (FX % (P + "EnergyBall"), (0, 0, 16, 16)),
        "moves/icon_sparkler": (FX % (P + "ShurikenMagic"), (0, 0, 16, 16)),
        "moves/icon_skip": NA_ITEM % "Scroll/ScrollThunder",
        "moves/icon_slam": NA_ITEM % "Tool/Hammer",
        "moves/icon_snuff": NA_ITEM % "Resource/Water",
    }


# single pictures a script drew that the game now does without (globs under assets/art)
GONE = ["fx/*_lg_f*.png", "fx/gib_*.png", "fx/splat_*.png", "fx/scorch.png", "fx/light/soft_light.png"]

# pictures a script drew that are simply taken away: the game then shows 0x72's own frames for that creature
# (Enemy.frames_for falls back to assets/0x72/frames; Enemy.DEFS "sprite" names the 0x72 sprite where it differs)
REMOVED = [
    "monsters/tiny_slug", "monsters/tiny_zombie", "monsters/goblin", "monsters/muddy",
    "monsters/snuffer",        # -> 0x72 dwarf_m
    "monsters/waxwork",        # -> 0x72 elf_f
    "areas/attic/mannequin",   # -> 0x72 knight_m
    "areas/attic/trunk",       # -> 0x72 chest_full_open
]

SETS = [("creatures", lambda: CREATURES), ("guardians", guardians), ("icons", lambda: ICONS), ("effects", effects)]


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
            if not isinstance(anims, dict):   # one picture: a whole pack file, or one crop of it
                src, box = (anims, None) if isinstance(anims, str) else anims
                out = target + ".png"
                credits.setdefault(src.split("/")[0], []).append((out, src, box))
                if not only_list:
                    im = Image.open(fetch(src)).convert("RGBA")
                    if box:
                        im = im.crop((box[0], box[1], box[0] + box[2], box[1] + box[3]))
                    im.save(os.path.join(ART, out))
                    n += 1
                continue
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
        for pat in GONE:
            for f in glob.glob(os.path.join(ART, pat)):
                os.remove(f)
                if os.path.exists(f + ".import"):
                    os.remove(f + ".import")
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
