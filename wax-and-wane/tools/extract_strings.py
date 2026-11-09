#!/usr/bin/env python3
"""Wax & Wane - string extractor (ROADMAP_V2 4a, groundwork for the v2.6 translations).

English source strings are the keys (gettext style): code says L.t("Light the wick") and
lang/<code>.json maps that key to the translated text ({name} placeholders are kept as they are).

What it does
  1. Collects every key: each L.t("...") literal in scripts/**/*.gd, plus the visible fields of the
     data tables the game shows by name (Candles.LIST, Moves.LIST, Achievements.LIST, Items.RELICS /
     KEEPSAKES / RITES, Diary.PAGES / ENDINGS). Those tables are wrapped where new code shows them (e.g. the move cards).
  2. Writes lang/en.json: {"@meta": ..., "<key>": "<key>", ...} sorted, stable, UTF-8.
  3. Lists visible strings in old code that do not go through L.t yet (UI.label / UI.button / toggles,
     hints, banners, floating texts, `.text = "..."`): a report only, step 4b wraps them.

Usage
    python3 tools/extract_strings.py                  # write lang/en.json + print the report summary
    python3 tools/extract_strings.py --report         # ... and every unwrapped string, file:line
    python3 tools/extract_strings.py --check          # exit 1 if lang/en.json is out of date
    python3 tools/extract_strings.py --strict F1 F2   # exit 1 if those files show an unwrapped string
                                                      # (every NEW script must pass: all its text via L.t)
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "scripts")
LANG = os.path.join(ROOT, "lang")
EN = os.path.join(LANG, "en.json")

# a GDScript string literal: "..." with escapes
STR = r'"((?:[^"\\]|\\.)*)"'
WRAPPED = re.compile(r'\bL\.t\(\s*' + STR)
# the data tables: (file, const name, fields shown to the player)
TABLES = [
    ("scripts/game/candles.gd", "LIST", ["name", "line", "blurb", "unlock_text"]),
    ("scripts/game/moves.gd", "LIST", ["name", "line", "short"]),
    ("scripts/autoload/achievements.gd", "LIST", ["name", "desc"]),
    ("scripts/game/items.gd", "RELICS", ["name", "desc"]),
    ("scripts/game/items.gd", "KEEPSAKES", ["name", "desc"]),
    ("scripts/game/items.gd", "RITES", ["name", "desc"]),
    ("scripts/game/diary.gd", "PAGES", ["title", "text"]),     # v2.5: Martha's diary
    ("scripts/game/diary.gd", "ENDINGS", ["name", "line"]),    # v2.5: the endings' names and results lines
]
# call sites whose string arguments land on screen
VISIBLE_CALLS = re.compile(
    r'\b(?:UI\.label|UI\.button|UI\.toggle|UI\.cycle|UI\.slider_row|UI\.modal|show_hint|show_banner|'
    r'preview_item|fx_text|two_line_button|_text|_head|_line|_hint|_menu_btn|_pop)\s*\(([^\n]*)')
TEXT_SET = re.compile(r'\.text\s*[+]?=\s*' + STR)


def unescape(s):
    return bytes(s, "utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")


def visible(s):
    """A string a player reads: has a letter, is not a resource path, a node name or an id."""
    if not re.search(r"[A-Za-z]", s):
        return False
    if s.startswith(("res://", "user://", "ui/", "hero/", "fx/", "items/", "moves/", "chalk/", "0x72/")):
        return False
    if re.fullmatch(r"[a-z0-9_]+", s):   # ids, animation names, setting keys
        return False
    if re.fullmatch(r"#[0-9a-fA-F]{6,8}", s):   # colours
        return False
    if re.fullmatch(r"%[-0-9.]*[dsf]", s.strip()):
        return False
    return True


def block(src, name):
    """The text of `const NAME := {...}` / `[...]` (bracket matched)."""
    m = re.search(r"const\s+" + name + r"\s*:?=\s*([\[{])", src)
    if not m:
        return ""
    open_c = m.group(1)
    close_c = "]" if open_c == "[" else "}"
    depth = 0
    i = m.start(1)
    in_str = False
    while i < len(src):
        ch = src[i]
        if in_str:
            if ch == "\\":
                i += 2
                continue
            if ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
        elif ch == "#":
            j = src.find("\n", i)
            i = j if j >= 0 else len(src)
            continue
        elif ch in "[{":
            depth += 1
        elif ch in "]}":
            depth -= 1
            if depth == 0:
                return src[m.start(1):i + 1]
        i += 1
    return ""


def gd_files():
    for d, _, fs in os.walk(SCRIPTS):
        for f in sorted(fs):
            if f.endswith(".gd"):
                yield os.path.join(d, f)


def strip_comment(line):
    out = []
    in_str = False
    i = 0
    while i < len(line):
        ch = line[i]
        if in_str:
            out.append(ch)
            if ch == "\\" and i + 1 < len(line):
                out.append(line[i + 1])
                i += 2
                continue
            if ch == '"':
                in_str = False
        else:
            if ch == "#":
                break
            if ch == '"':
                in_str = True
            out.append(ch)
        i += 1
    return "".join(out)


def collect():
    keys = {}       # key -> first source "file:line"
    for path in gd_files():
        rel = os.path.relpath(path, ROOT)
        with open(path, encoding="utf-8") as fh:
            for n, line in enumerate(fh, 1):
                for m in WRAPPED.finditer(strip_comment(line)):
                    keys.setdefault(unescape(m.group(1)), "%s:%d" % (rel, n))
    for rel, const, fields in TABLES:
        p = os.path.join(ROOT, rel)
        if not os.path.exists(p):
            continue
        src = open(p, encoding="utf-8").read()
        b = block(src, const)
        for f in fields:
            for m in re.finditer(r'"' + f + r'"\s*:\s*' + STR, b):
                s = unescape(m.group(1))
                if visible(s):
                    keys.setdefault(s, "%s %s.%s" % (rel, const, f))
    return keys


def unwrapped(path):
    """Visible string literals in `path` that are not inside L.t(...)."""
    out = []
    with open(path, encoding="utf-8") as fh:
        for n, raw in enumerate(fh, 1):
            line = strip_comment(raw)
            if not line.strip():
                continue
            spans = [m.span() for m in WRAPPED.finditer(line)]
            hits = []
            for m in VISIBLE_CALLS.finditer(line):
                arg_start = m.start(1)
                for sm in re.finditer(STR, line[arg_start:]):
                    hits.append((arg_start + sm.start(), sm.group(1)))
            for m in TEXT_SET.finditer(line):
                hits.append((m.start(1) - 1, m.group(1)))
            for pos, s in hits:
                if any(a <= pos < b for a, b in spans):
                    continue
                # the string sits inside an L.t( ... ) further left on the line (args after the key)
                if re.search(r'L\.t\([^)]*$', line[:pos]):
                    continue
                s = unescape(s)
                if visible(s):
                    out.append((n, s))
    return out


def main(argv):
    keys = collect()
    data = {"@meta": "English source strings (the keys). Written by tools/extract_strings.py; "
                     "translations copy this file to lang/<code>.json and replace the values."}
    for k in sorted(keys):
        data[k] = k
    text = json.dumps(data, ensure_ascii=False, indent=1, sort_keys=False) + "\n"
    if "--check" in argv:
        old = open(EN, encoding="utf-8").read() if os.path.exists(EN) else ""
        if old != text:
            print("[strings] lang/en.json is out of date: run python3 tools/extract_strings.py")
            return 1
        print("[strings] lang/en.json up to date (%d keys)" % len(keys))
        return 0
    if "--strict" in argv:
        files = argv[argv.index("--strict") + 1:]
        bad = 0
        for f in files:
            for n, s in unwrapped(os.path.join(ROOT, f) if not os.path.isabs(f) else f):
                print("[strings] UNWRAPPED %s:%d %r" % (f, n, s))
                bad += 1
        print("[strings] strict: %d unwrapped visible strings in %d files -> %s" % (bad, len(files), "FAIL" if bad else "PASS"))
        return 1 if bad else 0
    os.makedirs(LANG, exist_ok=True)
    with open(EN, "w", encoding="utf-8") as fh:
        fh.write(text)
    wrapped_n = sum(1 for k, v in keys.items() if not " " in v)
    total = 0
    per_file = []
    for path in gd_files():
        u = unwrapped(path)
        if u:
            per_file.append((len(u), os.path.relpath(path, ROOT), u))
            total += len(u)
    per_file.sort(reverse=True)
    print("[strings] lang/en.json: %d keys (%d from L.t calls, %d from data tables)" % (len(keys), wrapped_n, len(keys) - wrapped_n))
    print("[strings] old code: %d visible strings not wrapped yet in %d files (step 4b wraps them)" % (total, len(per_file)))
    for n, rel, u in per_file[:12]:
        print("[strings]   %4d  %s" % (n, rel))
    if "--report" in argv:
        for n, rel, u in per_file:
            for ln, s in u:
                print("%s:%d %r" % (rel, ln, s))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
