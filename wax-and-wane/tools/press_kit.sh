#!/usr/bin/env bash
# Wax & Wane: puts the press kit together from the current store art, as one zip to upload.
#
#   ./tools/press_kit.sh                 -> build/WaxAndWane_presskit_<version>.zip (and build/presskit/)
#   VERSION=2.0.0 ./tools/press_kit.sh   name the zip for a version other than the one in game.gd
#   HEROSHEET=0 ./tools/press_kit.sh     skip the Tallow sheets (they need godot + xvfb-run)
#
# What goes in (docs/marketing/press_kit.md lists it too): the logos, the app icon, the key art (with and
# without the logo, plus the landscape and portrait capsules), every 1920x1080 screenshot (desktop and the
# touch-screen set), the fight loop GIF if the trailer has been made, Tallow in every state at x6, and the
# text: press_kit.md, facts.md and the game's LICENSE. The trailer is not in it (47 MB): link the YouTube one.
# Make the store art first if anything visible changed: python3 tools/store_art.py
set -euo pipefail
cd "$(dirname "$0")/.."

VER="${VERSION:-$(sed -n 's/^const VERSION := "\(.*\)"/\1/p' scripts/autoload/game.gd)}"
[ -n "$VER" ] || { echo "[press_kit] could not read VERSION from scripts/autoload/game.gd" >&2; exit 1; }
A="docs/marketing/store_assets"
OUT="build/presskit"
ZIP="build/WaxAndWane_presskit_${VER}.zip"

mkdir -p build
touch build/.gdignore   # Godot must never import build/
rm -rf "$OUT" "$ZIP"
mkdir -p "$OUT/logo" "$OUT/icon" "$OUT/key_art" "$OUT/screenshots" "$OUT/gif" "$OUT/tallow"

put() {   # put SOURCE DEST: copy one file into the kit, stop if it is missing
	if [ ! -f "$1" ]; then
		echo "[press_kit] missing $1 (run: python3 tools/store_art.py)" >&2
		exit 1
	fi
	cp "$1" "$OUT/$2"
}

put "$A/press/logo_1280x720.png" logo/logo_1280x720.png
put "$A/press/logo_640x360.png" logo/logo_640x360.png
put "$A/steam/library_logo_1280x246.png" logo/logo_wide_1280x246.png
put docs/marketing/icons/google_play_512.png icon/icon_512.png
put "$A/press/keyart_1920x1080.png" key_art/key_art_1920x1080.png
put "$A/press/keyart_3840x2160.png" key_art/key_art_3840x2160.png
put "$A/press/keyart_logo_1920x1080.png" key_art/key_art_logo_1920x1080.png
put "$A/steam/main_capsule_1232x706.png" key_art/key_art_landscape_1232x706.png
put "$A/steam/vertical_capsule_748x896.png" key_art/key_art_portrait_748x896.png

n=0
for f in "$A"/screenshots/*.png; do
	cp "$f" "$OUT/screenshots/"
	n=$((n + 1))
done
p=0
for f in "$A"/google_play/phone16x9_*.png; do
	[ -f "$f" ] || continue
	p=$((p + 1))
	cp "$f" "$OUT/screenshots/phone_$(basename "$f" | sed 's/^phone16x9_//')"
done
[ "$n" -gt 0 ] || { echo "[press_kit] no screenshots in $A/screenshots" >&2; exit 1; }

if [ -f build/videos/loop_fight.gif ]; then
	cp build/videos/loop_fight.gif "$OUT/gif/loop_fight.gif"
else
	echo "[press_kit] no build/videos/loop_fight.gif yet (./tools/make_trailer.sh all makes it): skipped"
	rmdir "$OUT/gif"
fi

if [ "${HEROSHEET:-1}" != "0" ] && command -v xvfb-run > /dev/null && command -v godot > /dev/null; then
	tmp="$(mktemp -d)"
	prof="$(mktemp -d)"
	XDG_DATA_HOME="$prof" timeout 300 xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 \
		--resolution 1600x720 -- --autotest --herosheet --shots="$tmp" > "$tmp/log.txt" 2>&1 || true
	if [ -f "$tmp/hero_states.png" ]; then
		cp "$tmp/hero_states.png" "$OUT/tallow/tallow_states_x6.png"
		cp "$tmp/hero_candles.png" "$OUT/tallow/candles_x6.png"
	else
		echo "[press_kit] the Tallow sheet did not render (see $tmp/log.txt): skipped"
	fi
	rm -rf -- "$prof"
else
	echo "[press_kit] HEROSHEET=0 or no godot / xvfb-run: Tallow sheets skipped"
fi
rmdir "$OUT/tallow" 2> /dev/null || true

cp docs/marketing/press_kit.md "$OUT/press_kit.md"
cp docs/marketing/facts.md "$OUT/facts.md"
cp LICENSE "$OUT/LICENSE.txt"

(cd "$OUT" && zip -qr "../$(basename "$ZIP")" .)
echo "[press_kit] $n screenshots + $p touch-screen shots, $(find "$OUT" -type f | wc -l) files"
ls -lh "$ZIP"
