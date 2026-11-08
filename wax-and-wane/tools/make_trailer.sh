#!/usr/bin/env bash
# Wax & Wane trailer, vertical shorts and loop, re-made from the current build in one go:
#
#   ./tools/make_trailer.sh                 record every scene, then edit everything (about 10 minutes)
#   ./tools/make_trailer.sh --edit          edit only, from the footage already in build/trailer_raw/
#   ./tools/make_trailer.sh --record a b    record only scenes a and b (then edit)
#   ./tools/make_trailer.sh --record-only a b   record only, no edit
#
# 1. Each scene (scripts/trailer.gd) is played by the game itself under Godot's movie writer at a fixed
#    60 fps: build/trailer_raw/<scene>/f########.png (the game's own 384x216 picture, lossless) + f.wav
#    (the game's sound) + marks.json (the frame of each staged moment).
# 2. tools/trailer_edit.py cuts the footage on those marks, scales it x5 with nearest-neighbour (pixel
#    perfect at 1920x1080), draws the text cards in the game's font, lays the game's own music under the
#    game's sound with ducking, and writes build/videos/.
# 3. Finished files under 25 MB are copied to docs/marketing/videos/ (the rest stay in build/videos/).
#
# Needs: godot (4.7.2) on PATH, xvfb-run, ffmpeg with libx264 + libvpx-vp9, Python 3 with Pillow + numpy.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
RAW="$ROOT/build/trailer_raw"
OUT="$ROOT/build/videos"
DOCS="$ROOT/docs/marketing/videos"
SCENES=(title cellar hook floors build chapel seance cards boss clutch ladder keeper dawn)
LIMIT=$((25 * 1024 * 1024))

record() {
	local scene="$1"
	local dir="$RAW/$scene"
	rm -rf "$dir"
	mkdir -p "$dir"
	echo "[make_trailer] recording $scene"
	xvfb-run -a -s "-screen 0 1920x1080x24" godot --path "$ROOT" --rendering-driver opengl3 \
		--resolution 1920x1080 --write-movie "$dir/f.png" --fixed-fps 60 \
		-- --autotest --trailer="$scene" > "$dir/log.txt" 2>&1 || true
	if [ ! -f "$dir/marks.json" ]; then
		echo "[make_trailer] $scene: no marks.json, see $dir/log.txt" >&2
		exit 1
	fi
	grep -E "^\[trailer\] mark|movie length" "$dir/log.txt" | tr '\n' ' '
	echo
}

mode="all"
list=("${SCENES[@]}")
if [ "${1:-}" = "--edit" ]; then
	mode="edit"
elif [ "${1:-}" = "--record" ] || [ "${1:-}" = "--record-only" ]; then
	[ "$1" = "--record-only" ] && mode="record"
	shift
	list=("$@")
fi

if [ "$mode" != "edit" ]; then
	godot --headless --path "$ROOT" --import > /dev/null 2>&1 || true
	for s in "${list[@]}"; do
		record "$s"
	done
fi

[ "$mode" = "record" ] && exit 0
python3 "$ROOT/tools/trailer_edit.py" --raw "$RAW" --out "$OUT"

mkdir -p "$DOCS"
for f in "$OUT"/*.mp4 "$OUT"/*.webm "$OUT"/*.gif; do
	[ -f "$f" ] || continue
	size=$(stat -c %s "$f")
	if [ "$size" -lt "$LIMIT" ]; then
		cp "$f" "$DOCS/"
		echo "[make_trailer] $(basename "$f") $((size / 1024)) KB -> docs/marketing/videos/"
	else
		echo "[make_trailer] $(basename "$f") $((size / 1024 / 1024)) MB: too big for git, kept in build/videos/"
	fi
done
