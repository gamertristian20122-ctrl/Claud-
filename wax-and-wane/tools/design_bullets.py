#!/usr/bin/env python3
"""Rebuild only the enemy bullet sprites (assets/art/fx/bullet_*, bolt_*) from the art tools that own
them, without re-running those tools whole (they also rebuild rooms, monsters and the hero):

    python3 tools/design_bullets.py [--review <dir>]

  bullet_purple / green / water   tools/art_hero_fx_items.py   ORB, ORB_COLS, orb_frame()
  bolt_page / ring / wax / bone   tools/art_monsters.py        BOLTS, build_bolts()
  bolt_cog                        tools/art_tower.py           build_bolts()

Then judge them with tools/design_contrast.py (docs/design/MDA.md, "Fair deaths").
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import art_hero_fx_items as hero  # noqa: E402
import art_monsters as mon  # noqa: E402
import art_tower as tower  # noqa: E402


def main():
    for name, cols in hero.ORB_COLS.items():
        for i in range(2):
            hero.save(hero.orb_frame(i, cols), "fx", "bullet_%s_f%d.png" % (name, i))
    mon.build_bolts()
    tower.build_bolts()
    for name, im in tower.MADE.items():
        if name.startswith("fx/bolt_cog"):
            tower.check(name, im)
            im.save(os.path.join(tower.ART, name + ".png"), optimize=True)
    if "--review" in sys.argv:
        from PIL import Image
        d = sys.argv[sys.argv.index("--review") + 1]
        os.makedirs(d, exist_ok=True)
        names = ["bullet_purple", "bullet_green", "bullet_water", "bolt_bone", "bolt_cog", "bolt_page", "bolt_ring", "bolt_wax"]
        sheet = Image.new("RGBA", (len(names) * 10 * 8, 2 * 10 * 8), (40, 30, 34, 255))
        for i, n in enumerate(names):
            for f in range(2):
                im = Image.open(os.path.join(hero.ART, "fx", "%s_f%d.png" % (n, f))).convert("RGBA")
                big = im.resize((im.width * 8, im.height * 8), Image.NEAREST)
                sheet.alpha_composite(big, (i * 80 + 8, f * 80 + 8))
        sheet.save(os.path.join(d, "bullets_8x.png"))
    print("bullets rebuilt")


if __name__ == "__main__":
    main()
