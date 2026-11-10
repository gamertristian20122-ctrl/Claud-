#!/usr/bin/env python3
"""Wax & Wane: writes docs/marketing/facts.md, the one fact sheet every store text is checked against.

Every number in the "From the code" part is read from the game's own data (Enemy.DEFS, Items.RELICS,
Candles.LIST, Achievements.LIST, world.gd, floor_gen.gd, specials.gd, export_presets.cfg ...), so a
content change upstream shows up here the next time you run it:

    python3 tools/make_facts.py            # rewrite docs/marketing/facts.md
    python3 tools/make_facts.py --check    # exit 1 if facts.md is out of date (nothing is written)

The "Checked by hand" part (run lengths, art sources, AI use) is kept in HAND below.
No Godot needed: it parses the .gd files as text.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "marketing", "facts.md")


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def block(src, name):
    """The text of `const NAME := {...}` or `[...]`, brackets matched, strings skipped."""
    m = re.search(r"const %s\s*:=\s*([\[{])" % re.escape(name), src)
    if not m:
        raise SystemExit("make_facts: no const %s" % name)
    i, depth, quote, comment = m.end(1) - 1, 0, None, False
    for j in range(i, len(src)):
        c = src[j]
        if comment:
            comment = c != "\n"
            continue
        if quote:
            if c == "\\":
                continue
            if c == quote and src[j - 1] != "\\":
                quote = None
            continue
        if c == "#":
            comment = True
        elif c in "\"'":
            quote = c
        elif c in "[{(":
            depth += 1
        elif c in "]})":
            depth -= 1
            if depth == 0:
                return src[i:j + 1]
    raise SystemExit("make_facts: unclosed %s" % name)


def entries(blk):
    """Top-level "key": {...} entries of a dict block -> [(key, text, section comment)]."""
    out, section = [], ""
    lines = blk.splitlines()
    cur = None
    for ln in lines[1:]:
        sm = re.match(r"^\t# ----\s*(.*)", ln)
        if sm:
            section = sm.group(1).strip()
            continue
        km = re.match(r'^\t"([\w]+)":\s*[\[{]', ln)
        if km:
            cur = [km.group(1), ln, section]
            out.append(cur)
        elif cur is not None:
            cur[1] += "\n" + ln
    return [tuple(e) for e in out]


def field(text, key, default=None):
    m = re.search(r'"%s":\s*("([^"]*)"|[-\d.]+|true|false)' % key, text)
    if not m:
        return default
    if m.group(2) is not None:
        return m.group(2)
    v = m.group(1)
    if v in ("true", "false"):
        return v == "true"
    return float(v)


def is_0x72(sprite):
    d = os.path.join(ROOT, "assets", "0x72", "frames")
    return any(os.path.exists(os.path.join(d, p % sprite)) for p in
               ("%s_idle_anim_f0.png", "%s_anim_f1.png", "%s_open_anim_f0.png"))


def title(name):
    """THE WAX MOTHER -> The Wax Mother"""
    small = {"of", "the", "and"}
    words = name.lower().split()
    return " ".join(w if (i and w in small) else w.capitalize() for i, w in enumerate(words))


def facts():
    f = {}
    f["version"] = re.search(r'const VERSION := "([^"]+)"', read("scripts/autoload/game.gd")).group(1)
    world = read("scripts/game/world.gd")
    m = re.search(r"const DRAIN_PER_SEC := ([\d.]+) / \(([\d.]+) \* ([\d.]+)\)", world)
    f["full_wax"], f["candle_min"] = float(m.group(1)), float(m.group(2))
    f["drain"] = float(m.group(1)) / (float(m.group(2)) * float(m.group(3)))
    f["floors"] = [(k, field(t, "name"), field(t, "boss"), re.findall(r'"(\w+)"', re.search(r'"bosses":\s*\[([^\]]*)\]', t).group(1)))
                   for k, t, _ in [(int(re.match(r'\t(\d+)', l).group(1)), l, "") for l in block(world, "FLOORS").splitlines() if re.match(r"\t\d+:", l)]]
    f["last_floor"] = int(re.search(r"const LAST_FLOOR := (\d+)", world).group(1))
    # difficulty levels (one per save slot) and the slots themselves
    f["levels"] = [(int(n), name, line, {k: float(v) for k, v in re.findall(r'"(melt|dmg|hp|champ|wax)": ([\d.]+)', body)})
                   for n, name, line, body in re.findall(r'\t(\d+): \{"name": "([^"]+)", "line": "([^"]+)",(.*?)\}', block(world, "LEVELS"), re.S)]
    f["default_level"] = int(re.search(r"const DEFAULT_LEVEL := (\d+)", world).group(1))
    f["slots"] = int(re.search(r"const SLOTS := (\d+)", read("scripts/autoload/game.gd")).group(1))
    f["omens"] = [field(t, "name") for _, t, _ in entries(block(world, "OMENS"))]
    m = re.search(r"streak_t = ([\d.]+)", world)
    f["kindle_window"] = float(m.group(1))
    f["kindle_gains"] = [(int(n), float(g)) for n, g in re.findall(r"streak == (\d+):\s*gain = ([\d.]+)", world)]
    f["spill"] = float(re.search(r"amount \* ([\d.]+) / k", world).group(1))
    f["warm_life"] = float(re.search(r'"wax_warm":.{0,200}?life = ([\d.]+)', read("scripts/game/pickup.gd"), re.S).group(1))
    tw = read("scripts/game/tower.gd")
    f["tower_by"] = float(re.search(r"const UNLOCK_CLOCK := ([\d.]+)", tw).group(1))
    f["tower_wax"] = float(re.search(r"const ARRIVAL_WAX := ([\d.]+)", tw).group(1))
    gen = read("scripts/game/floor_gen.gd")
    # rooms per floor on a 4-floor night (there a floor's depth is its number; longer nights stretch the depths)
    m = re.search(r'var target := (\d+) \+ roundi\(([\d.]+) \* float\(night\["depth"\]\)\)', gen)
    f["rooms_per_floor"] = [int(m.group(1)) + round(float(m.group(2)) * n) for n in range(1, f["last_floor"] + 1)]
    f["layouts"] = len(re.findall(r'"id": "', block(read("scripts/game/room_templates.gd"), "NORMAL")))

    pools, cur = {}, None
    for ln in block(world, "POOLS").splitlines()[1:]:
        pm = re.match(r"\t(\d+):", ln)
        if pm:
            cur = pools.setdefault(int(pm.group(1)), set())
            ln = ln.split(":", 1)[1]
        if cur is not None:
            cur.update(w for w in re.findall(r'"(\w+)"', ln) if w not in ("e", "h", "f"))
    en = entries(block(read("scripts/game/enemy.gd"), "DEFS"))
    lodgers, guardians = [], []
    for k, t, sec in en:
        sprite = field(t, "sprite", k)
        row = {"id": k, "name": field(t, "name"), "x72": is_0x72(sprite), "secret": bool(field(t, "secret", False)),
               "tower_only": k in pools.get(5, set()) and not any(k in v for n, v in pools.items() if n != 5),
               "area": str(sprite).startswith("areas/")}   # the Long Night's new areas (areas.gd, LONG_NIGHT.md)
        (guardians if field(t, "boss", False) else lodgers).append(row)
    f["lodgers"], f["guardians"] = lodgers, guardians
    sp = read("scripts/game/specials.gd")
    f["specials"] = [(title(field(t, "name")), field(t, "sub")) for _, t, _ in entries(block(sp, "INFO"))]
    f["minis"] = [title(field(t, "name")) for _, t, _ in entries(block(sp, "MINIS"))]
    f["crank"] = int(re.search(r"const CRANK_COST := (\d+)", sp).group(1))

    it = read("scripts/game/items.gd")
    relics = entries(block(it, "RELICS"))
    f["relics"] = [(field(t, "name"), int(field(t, "q", 0))) for _, t, _ in relics]
    f["rites"] = [field(t, "name") for _, t, _ in entries(block(it, "RITES"))]
    f["keepsakes"] = [(field(t, "name"), field(t, "desc")) for _, t, _ in entries(block(it, "KEEPSAKES"))]
    f["tonics"] = len(entries(block(it, "TONICS")))
    un = entries(block(read("scripts/game/unlocks.gd"), "TABLE"))
    keep_ids = {k for k, _, _ in entries(block(it, "KEEPSAKES"))}
    f["unlock_relics"] = sum(1 for k, _, _ in un if k not in keep_ids)
    f["unlock_keepsakes"] = sum(1 for k, _, _ in un if k in keep_ids)

    ca = read("scripts/game/candles.gd")
    order = re.findall(r'"(\w+)"', re.search(r"const ORDER := \[([^\]]*)\]", ca).group(1))
    cl = {k: t for k, t, _ in entries(block(ca, "LIST"))}
    f["candles"] = []
    for k in order:
        t = cl[k]
        wax, drain = field(t, "wax"), field(t, "drain")
        mins = wax / (f["drain"] * drain) / 60.0
        f["candles"].append({"id": k, "name": field(t, "name"), "line": field(t, "line"), "wax": wax,
                             "minutes": mins, "unlock": field(t, "unlock_text") or "from the start",
                             "move": field(t, "move", "")})
    # v2.3 special moves (moves.gd) and v2.2 night length (areas.gd: every built floor of the house, the tower aside)
    f["moves"] = {k: field(t, "name") for k, t, _ in entries(block(read("scripts/game/moves.gd"), "LIST"))}
    ar = entries(block(read("scripts/game/areas.gd"), "LIST"))
    f["max_floors"] = sum(1 for _k, t, _ in ar if field(t, "built", False) and not field(t, "secret", False))

    ach = block(read("scripts/autoload/achievements.gd"), "LIST")
    f["achievements"] = len(re.findall(r'\{"id": "', ach))
    f["achievements_hidden"] = len(re.findall(r'"hidden": true', ach))

    mus = read("assets/licenses/CREDITS_music.txt")
    f["music"] = re.findall(r'^\s+(\w+)\.ogg\s+"([^"]+)" - Ninja Adventure', mus, re.M)
    f["jingles"] = re.findall(r'^\s+(\w+)\.ogg\s+original', mus, re.M)
    f["sfx"] = len([n for n in os.listdir(os.path.join(ROOT, "assets", "audio", "sfx")) if not n.endswith(".import")])

    ex = read("export_presets.cfg")
    f["presets"] = re.findall(r'^name="([^"]+)"', ex, re.M)
    f["permissions"] = sorted(set(re.findall(r"^permissions/(\w+)=true", ex, re.M)))
    f["package"] = re.search(r'package/unique_name="([^"]+)"', ex).group(1)
    f["min_sdk"] = (re.search(r'gradle_build/min_sdk="(\d+)"', ex) or re.search("(24)", "24")).group(1)
    f["target_sdk"] = (re.search(r'gradle_build/target_sdk="(\d+)"', ex) or re.search("(36)", "36")).group(1)
    f["backup"] = "user_data_backup/allow=true" in ex
    pg = read("project.godot")
    f["user_dir"] = re.search(r'config/custom_user_dir_name="([^"]+)"', pg).group(1) if "use_custom_user_dir=true" in pg else None
    return f


# Facts no script can read: measured, decided or checked by hand. Keep them true.
HAND = """
## Checked by hand (not in the code)

| Fact | Value | How it was checked |
|---|---|---|
| Run length | About 4 to 12 minutes: a winning night takes the test bot 8 to 12 (ten on average; the longer ones climb to the Clock Tower), a lost one ends sooner | `--playtest --speed=4` bot, fresh saves, 2.8.0: eight wins on seeds 7-18 at 7.9 to 12.3 min, two losses at 3.9 and 10.0 min (`docs/streams/v28_pace.md`). 2.0.0 ran longer (a true-ending win 16.4 min): 2.8 cut the walking. People who dodge do better than the bot. Re-measure after balance changes |
| Win rate (bot, fresh save) | About half of the bot's runs win (7 of 12 at the last balance pass) | `--playtest --speed=4`, 12 runs per setting (CLAUDE.md > Balance). Re-measure after balance changes |
| Art made for this game | Tallow and the other 5 candles, the house's own lodgers and guardians (counts above), relics and keepsake icons, costumes, effects, rooms and decor, special rooms, the Clock Tower, chalk drawings, UI, logo, icons | Drawn by Python scripts written with Claude (an AI assistant), `tools/art_*.py`, on the 0x72 palette; every sheet was looked at and kept or redrawn by the developer |
| Art from 0x72 (CC0) | The dungeon tiles, chests, coins, bombs, flasks and the 0x72 lodgers and guardians (counts above) | `assets/0x72/frames/`, `assets/licenses/0x72_DungeonTilesetII_CC0.txt` |
| Music | 13 tracks, all from the Ninja Adventure Asset Pack by Pixel-boy and AAA (CC0). Not AI | `assets/licenses/CREDITS_music.txt` |
| Jingles | 2 (victory, death): original, synthesized by `tools/make_audio.py` (a script written with Claude) | same file |
| Sound effects | Layered and processed from Kenney packs (CC0), a few Ninja Adventure sounds (CC0), plus original synthesis | `assets/licenses/CREDITS_audio.txt` |
| Fonts | Kenney Pixel and Kenney Mini (CC0) | `assets/licenses/Kenney_Fonts_CC0.txt` |
| Code | Written with Claude (AI coding assistant), directed, played and checked by the developer | git history |
| Trailer narration | AI voice: Kokoro TTS (Kokoro-82M, Apache-2.0, voice am_michael). Only in the trailer and shorts, never in the game | `docs/marketing/voice/` |
| AI while playing | None. Nothing is generated while you play | the game has no network access and no AI model |
| Data collected | None. No ads, analytics, accounts or network access | `PRIVACY.md`; the Android build's only permission is listed above |
| Blood | Cartoon only: creatures burst into small chunks that fade and leave flat coloured splats on the floor; some splats are red (`#9f294e`, `#62232f`, `#da4e38`) | `scripts/game/fx_gibs.gd`, `stains.gd`, `Enemy.DEFS` stain colours |
| Random rewards | Chests, the Music Box (3 in-game coins a crank) and the Wax Font use in-game coins or wax only. No real money anywhere | `scripts/game/specials.gd` |
| Steam features at launch | No Steam achievements or Steam overlay calls yet (GodotSteam is not in the build); the {ach} achievements are in-game. Steam Cloud works without code (Auto-Cloud) | `scripts/autoload/achievements.gd` (Steam bridge waits for GodotSteam) |
| Demo | The browser build (`./tools/build_web.sh`) is the demo once it is uploaded to itch.io. It is not on any store page yet: do not call it live before it is | `docs/marketing/pitch/README.md` |
| Languages | English only | |
"""


def md(f):
    L = []
    a = L.append
    lod, gua = f["lodgers"], f["guardians"]
    l72 = sum(1 for x in lod if x["x72"])
    g72 = sum(1 for x in gua if x["x72"])
    a("# Wax & Wane: fact sheet")
    a("")
    a("The one list every store text, the press kit and the trailer cards are checked against. The first part")
    a("is written by `python3 tools/make_facts.py` from the game's own code (do not edit it by hand: re-run the")
    a("script after any content change; `--check` tells you if it is out of date). Game version in the code:")
    a("**%s** (the store release is 2.0.0)." % f["version"])
    a("")
    a("## From the code")
    a("")
    a("| Fact | Value | Read from |")
    a("|---|---|---|")
    a("| The candle | %d wax = 12:00 AM to 2:00 AM; one minute of wax is one minute on the clock | `world.gd`, `candles.gd` |" % f["full_wax"])
    a("| A full candle lasts | **%g minutes** of real time if you are never hit | `world.DRAIN_PER_SEC` = %g / (%g x 60) |" % (f["full_wax"] / f["drain"] / 60.0, f["full_wax"], f["candle_min"]))
    names = [n for k, n, _, _ in f["floors"] if k <= f["last_floor"]]
    secret = [n for k, n, _, _ in f["floors"] if k > f["last_floor"]]
    a("| Floors | **%d**: %s, plus a secret fifth floor, **%s** | `world.FLOORS` |" % (len(names), ", ".join(names), ", ".join(secret)))
    by = int(f["tower_by"])
    a("| The secret floor opens | if the Belfry's guardian falls by **%d:%02d AM** (you arrive with +%g minutes of wax) | `Tower.UNLOCK_CLOCK`, `ARRIVAL_WAX` |" % (
        12 if by < 60 else by // 60, by % 60, f["tower_wax"]))
    a("| Kindling | kills less than %g s apart chain; %s | `world._kindle` |" % (f["kindle_window"], ", ".join("x%d gives +%g min" % kg for kg in f["kindle_gains"])))
    a("| Spilled Wax | %d%% of the wax a hit melts splashes out as warm drops that cool after %g s | `world.gd`, `pickup.gd` |" % (round(f["spill"] * 100), f["warm_life"]))
    a("| Rooms per floor | %s (with the start, shop, treasure and boss rooms), plus a hidden Hollow and any special rooms | `floor_gen.gd` |" % " / ".join(str(n) for n in f["rooms_per_floor"]))
    a("| Hand-made room layouts | **%d** | `RoomTemplates.NORMAL` |" % f["layouts"])
    a("| Lodgers (creatures) | **%d**: %d from 0x72's DungeonTileset II, %d made for this game (%d of them only in the Clock Tower, %d only in the Long Night's new areas) | `Enemy.DEFS` |" % (
        len(lod), l72, len(lod) - l72, sum(1 for x in lod if x["tower_only"]), sum(1 for x in lod if x["area"])))
    per = {len(bs) for fn, _nm, _b1, bs in f["floors"] if fn <= 4}
    per = ("%s per floor" % ["no", "one", "two", "three", "four", "five"][per.pop()]) if len(per) == 1 else "per floor"
    ga = [x for x in gua if x["area"]]
    a("| Guardians (bosses) | **%d**: %d on the four floors (%s, picked by the run seed)%s + a secret one, %s. %d use 0x72 sprites, %d were made for this game | `Enemy.DEFS`, `world.FLOORS`, `Areas.LIST` |" % (
        len(gua), sum(1 for x in gua if not x["secret"] and not x["area"]), per,
        (", %d in the Long Night's new areas (%s)" % (len(ga), ", ".join(title(x["name"]) for x in ga))) if ga else "",
        ", ".join(title(x["name"]) for x in gua if x["secret"]), g72, len(gua) - g72))
    a("| House champions (mini-bosses) | **%d**: %s | `Specials.MINIS` |" % (len(f["minis"]), ", ".join(f["minis"])))
    a("| Relics | **%d** in %d quality tiers; %d of them move into the house as you earn achievements | `Items.RELICS`, `Unlocks.TABLE` |" % (
        len(f["relics"]), len({q for _, q in f["relics"]}), f["unlock_relics"]))
    a("| Candle Rites (set bonuses) | **%d**: %s | `Items.RITES` |" % (len(f["rites"]), ", ".join(r.replace("Rite of the ", "").replace("Rite of ", "") for r in f["rites"])))
    a("| Keepsakes (charged items) | **%d**: %s (%d unlock with achievements) | `Items.KEEPSAKES` |" % (
        len(f["keepsakes"]), ", ".join(n for n, _ in f["keepsakes"]), f["unlock_keepsakes"]))
    a("| Tonics | %d unlabelled flasks | `Items.TONICS` |" % f["tonics"])
    a("| Candles (playable) | **%d** (%d to unlock) | `Candles.LIST` |" % (len(f["candles"]), len(f["candles"]) - 1))
    a("| Special moves | **%d**, one per candle (its own button): %s | `Moves.LIST`, `Candles.LIST` |" % (
        len(f["moves"]), ", ".join("%s (%s)" % (f["moves"].get(c["move"], "?"), c["name"]) for c in f["candles"] if c["move"])))
    a("| Night length | **4 to %d floors**, picked before a run and kept per save slot (Tonight's Candle is always 4). Each floor past four adds half an hour: a %d-floor night ends at %s | `Areas`, `Game.night_minutes` |" % (
        f["max_floors"], f["max_floors"], "%d:%02d AM" % divmod(120 + 30 * (f["max_floors"] - 4), 60)))
    a("| Special rooms | **%d**: %s | `Specials.INFO` |" % (len(f["specials"]), ", ".join(n for n, _ in f["specials"])))
    a("| Omens (floor twists) | **%d**: %s | `world.OMENS` |" % (len(f["omens"]), ", ".join(f["omens"])))
    a("| Achievements | **%d** (%d hidden), shown in the game | `Achievements.LIST` |" % (f["achievements"], f["achievements_hidden"]))
    a("| Save slots | **%d**, each with its own difficulty level, records, Journal, unlocks, achievements and saved run; settings are shared | `Game.SLOTS` |" % f["slots"])

    def lv_terms(m):
        names = {"melt": "melt", "dmg": "foe damage", "hp": "foe health", "champ": "marked foes", "wax": "drip wax"}
        parts = ["%s x%g" % (names[k], v) for k, v in m.items() if v != 1.0]
        return ", ".join(parts) if parts else "the game as it was made"
    a("| Difficulty levels | **%d**: %s. Tonight's Candle always plays level %d | `world.LEVELS` |" % (
        len(f["levels"]), "; ".join("%d %s (%s)" % (n, name, lv_terms(m)) for n, name, _, m in f["levels"]), f["default_level"]))
    a("| Music | %d tracks + %d original jingles | `assets/licenses/CREDITS_music.txt` |" % (len(f["music"]), len(f["jingles"])))
    a("| Sound effect files | %d | `assets/audio/sfx/` |" % f["sfx"])
    a("| Builds | %s | `export_presets.cfg` |" % ", ".join(f["presets"]))
    a("| Android | package `%s`, min SDK %s, target SDK %s, permissions: %s; Auto Backup %s | `export_presets.cfg` |" % (
        f["package"], f["min_sdk"], f["target_sdk"], ", ".join(f["permissions"]) or "none", "on" if f["backup"] else "off"))
    a("| PC save folder | %s | `project.godot` |" % ("`%%APPDATA%%\\%s` (Windows), `~/.local/share/%s` (Linux)" % (f["user_dir"], f["user_dir"]) if f["user_dir"] else "Godot's default app_userdata folder"))
    a("")
    a("### The candles")
    a("")
    a("| Candle | Lit at | Lasts unhurt | Unlock | In the game's words |")
    a("|---|---|---|---|---|")
    for c in f["candles"]:
        lit = 120 - c["wax"]
        if lit >= 0:
            at = "12:%02d AM" % lit
        else:
            at = "11:%02d PM" % (60 + lit)
        a("| %s | %s | %.1f min | %s | %s |" % (c["name"], at, c["minutes"], c["unlock"], c["line"]))
    a("")
    a("### The guardians")
    a("")
    a("| Floor | Guardians |")
    a("|---|---|")
    byid = {x["id"]: x for x in gua}
    for k, n, _, bosses in f["floors"]:
        names = ["%s%s" % (title(byid[b]["name"]), " (0x72 sprite)" if byid[b]["x72"] else "") for b in bosses if b in byid]
        a("| %s | %s |" % (n, " or ".join(names) if len(names) < 3 else ", ".join(names[:-1]) + " or " + names[-1]))
    a("")
    a("### The lodgers")
    a("")
    a("- Made for this game (%d): %s" % (len(lod) - l72, ", ".join(x["name"] for x in lod if not x["x72"])))
    a("- From 0x72, renamed and given their own lore (%d): %s" % (l72, ", ".join(x["name"] for x in lod if x["x72"])))
    a("")
    a("### Music slots")
    a("")
    a(", ".join("%s: %s" % (slot, track) for slot, track in f["music"]) + ".")
    a(HAND.rstrip().replace("{ach}", str(f["achievements"])))
    a("")
    return "\n".join(L) + "\n"


def main():
    text = md(facts())
    if "--check" in sys.argv:
        cur = open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else ""
        if cur != text:
            print("facts.md is out of date: run python3 tools/make_facts.py")
            sys.exit(1)
        print("facts.md is up to date")
        return
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(text)
    print("[make_facts] wrote %s" % os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
