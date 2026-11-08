#!/usr/bin/env bash
# Wax & Wane: the trailer, three vertical shorts and the store loop, re-made from the current build.
#
#   ./tools/make_trailer.sh all                 record every scene, then edit and check everything (~15 min)
#   ./tools/make_trailer.sh record [scene ...]  record scenes only (all of them when none are named)
#   ./tools/make_trailer.sh edit [--only trailer,short_a,short_b,short_c,loop]   edit from the recorded footage
#   ./tools/make_trailer.sh check               judge the finished files (length, size, loudness, narration)
#   ./tools/make_trailer.sh stills              contact sheets of every cut (fast, no video encode)
#   ./tools/make_trailer.sh voice               re-make the AI narrator's lines (Kokoro TTS, judged by Whisper)
#   ./tools/make_trailer.sh audition            four narrator voices side by side -> build/voice_audition/
#   ./tools/make_trailer.sh voicecheck DIR [--fix]   judge (and level) your own recordings, e.g. docs/marketing/voice/owner
#
# Finished videos: build/videos/ (git-ignored). COPY_TO=/some/dir also copies the finals there.
# Narrator: docs/marketing/voice/owner/ when all seven lines are there (your own voice), otherwise the AI
# voice in docs/marketing/voice/ai_narrator/; VOICE=<dir> picks one.
#
# 1. Each scene (scripts/trailer.gd) is played by the game itself under Godot's movie writer at a fixed
#    60 fps in a 1920x1080 window: build/trailer_raw/<scene>/f########.png (the game's own 384x216 picture,
#    lossless, so the x5 scale-up stays pixel-perfect) + f.wav (the game's sound) + marks.json (the frame of
#    each staged moment). Every scene runs on its own fresh, private save profile.
# 2. tools/trailer_edit.py cuts on those marks, scales x5 (x10 for the close-up) with nearest-neighbour, draws
#    the text cards in the game's pixel font, lays the narrator over the game's sound and the game's own
#    CC0 music (ducked under the voice), and sets the loudness (-16 LUFS trailer, -14 LUFS shorts).
# 3. check: durations, sizes, loudness, and the narration heard back by Whisper from the finished mix.
#
# Needs: godot 4.7.2, xvfb-run, ffmpeg (libx264, libvpx-vp9, aac), Python 3 + Pillow + numpy + scipy.
# voice / audition / voicecheck / check's narration test need the voice venv: ./tools/voice_setup.sh (once).
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
RAW="$ROOT/build/trailer_raw"
OUT="$ROOT/build/videos"
VENV="${VOICE_VENV:-$HOME/.cache/waxandwane/voice_venv}"
SCENES=(title intro cellar hook floors build chapel seance specials cards boss clutch ladder keeper dawn)
FINALS=(trailer_60s.mp4 short_a_candle_is_the_timer.mp4 short_b_every_fire_relic.mp4 short_c_one_minute_left.mp4
	loop_fight.webm loop_fight.gif trailer_60s.srt short_a_candle_is_the_timer.srt short_c_one_minute_left.srt)
# build/ holds thousands of footage PNGs: Godot must never import them (that took minutes and 250 MB of cache)
mkdir -p "$ROOT/build"
touch "$ROOT/build/.gdignore"

voice_py() {
	if [ ! -x "$VENV/bin/python" ]; then
		echo "[make_trailer] no voice venv at $VENV: run ./tools/voice_setup.sh once" >&2
		return 1
	fi
	OMP_NUM_THREADS="${OMP_NUM_THREADS:-2}" TOKENIZERS_PARALLELISM=false PYTHONWARNINGS=ignore \
		"$VENV/bin/python" "$ROOT/tools/make_voice.py" "$@"
}

voice_dir() {
	if [ -n "${VOICE:-}" ]; then
		echo "$VOICE"
		return
	fi
	local own="$ROOT/docs/marketing/voice/owner" n=0 f
	for f in 01_this_is_tallow 02_midnight 03_wax_is_health 04_every_hit 05_four_floors 06_done_by_two 07_light_the_wick; do
		ls "$own/$f".* > /dev/null 2>&1 && n=$((n + 1))
	done
	if [ "$n" -eq 7 ]; then
		echo "$own"
	else
		echo "$ROOT/docs/marketing/voice/ai_narrator"
	fi
}

record() {
	local scene="$1"
	local dir="$RAW/$scene"
	local profile
	profile="$(mktemp -d /tmp/waxandwane_trailer.XXXXXX)"
	rm -rf "$dir"
	mkdir -p "$dir"
	local t0=$SECONDS
	XDG_DATA_HOME="$profile" xvfb-run -a -s "-screen 0 1920x1080x24" godot --path "$ROOT" --rendering-driver opengl3 \
		--resolution 1920x1080 --write-movie "$dir/f.png" --fixed-fps 60 \
		-- --autotest --trailer="$scene" > "$dir/log.txt" 2>&1 || true
	rm -rf -- "$profile"
	if [ ! -f "$dir/marks.json" ]; then
		echo "[make_trailer] $scene: no marks.json, see $dir/log.txt" >&2
		exit 1
	fi
	if grep -q "SCRIPT ERROR" "$dir/log.txt"; then
		echo "[make_trailer] $scene: script error, see $dir/log.txt" >&2
		grep -m3 -A2 "SCRIPT ERROR" "$dir/log.txt" >&2
		exit 1
	fi
	echo "[make_trailer] $scene: $(find "$dir" -name 'f*.png' | wc -l) frames in $((SECONDS - t0)) s;" \
		"$(grep -E '^\[trailer\] (mark|spot)' "$dir/log.txt" | sed 's/\[trailer\] //' | tr '\n' ' ')"
}

record_all() {
	godot --headless --path "$ROOT" --import > /dev/null 2>&1 || true
	local list=("$@")
	[ ${#list[@]} -eq 0 ] && list=("${SCENES[@]}")
	for s in "${list[@]}"; do
		record "$s"
	done
}

edit() {
	local vd
	vd="$(voice_dir)"
	echo "[make_trailer] narrator: $vd"
	python3 "$ROOT/tools/trailer_edit.py" --raw "$RAW" --out "$OUT" --voice "$vd" "$@"
}

copy_out() {
	[ -z "${COPY_TO:-}" ] && return 0
	mkdir -p "$COPY_TO"
	for f in "${FINALS[@]}"; do
		[ -f "$OUT/$f" ] && cp "$OUT/$f" "$COPY_TO/"
	done
	echo "[make_trailer] copied the finals to $COPY_TO"
}

check() {
	python3 "$ROOT/tools/trailer_edit.py" --check --out "$OUT"
	if [ -x "$VENV/bin/python" ]; then
		voice_py mixcheck "$OUT/trailer_60s.mp4" "$OUT/short_a_candle_is_the_timer.mp4" "$OUT/short_c_one_minute_left.mp4"
	else
		echo "[make_trailer] (no voice venv: skipped hearing the narration back from the mix)"
	fi
}

cmd="${1:-all}"
[ $# -gt 0 ] && shift
case "$cmd" in
	all)
		record_all
		edit
		copy_out
		check
		;;
	record) record_all "$@" ;;
	edit)
		edit "$@"
		copy_out
		;;
	check) check ;;
	stills) edit --stills "$ROOT/build/videos/stills" "$@" ;;
	voice) voice_py make "$@" ;;
	audition) voice_py audition "$@" ;;
	voicecheck) voice_py check "$@" ;;
	*)
		sed -n '2,13p' "$0"
		exit 1
		;;
esac
