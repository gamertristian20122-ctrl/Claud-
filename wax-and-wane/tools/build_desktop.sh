#!/usr/bin/env bash
# Build the desktop releases (64-bit, game data embedded in the executable):
#   build/WaxAndWane_<version>_windows.zip   WaxAndWane.exe (+ ANGLE dlls if Godot adds them) + licences
#   build/WaxAndWane_<version>_linux.zip     WaxAndWane.x86_64 + licences
# Then boots the Linux build headless (starts a bot run, quits by itself) as a smoke test.
# These zips are what goes to Steam (one depot per OS) and itch.io.
#   SKIP_SMOKE=1 ./tools/build_desktop.sh    skip the boot test
#   GODOT=/path/to/godot ./tools/build_desktop.sh
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
VER="$(sed -n 's/^const VERSION := "\(.*\)"/\1/p' scripts/autoload/game.gd)"
[ -n "$VER" ] || { echo "could not read VERSION from scripts/autoload/game.gd"; exit 1; }

rm -rf build/windows build/linux
mkdir -p build/windows build/linux
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/WaxAndWane.exe
"$GODOT" --headless --path . --export-release "Linux" build/linux/WaxAndWane.x86_64
chmod +x build/linux/WaxAndWane.x86_64

for d in build/windows build/linux; do
	mkdir -p "$d/licenses"
	cp assets/licenses/*.txt "$d/licenses/"
	printf 'Wax & Wane %s\n\nA little candle burns through a haunted house before 2 AM.\n\nKeyboard: WASD move, arrow keys shoot (or hold the left mouse button to fire at the cursor),\nE / Space / right mouse bomb, Q keepsake, Esc pause, F11 fullscreen.\nGamepad: left stick move, right stick or ABXY shoot, RB bomb, LB keepsake, Start pause.\n\nYour saves: %%APPDATA%%\\WaxAndWane on Windows, ~/.local/share/WaxAndWane on Linux.\n' "$VER" > "$d/README.txt"
done

rm -f "build/WaxAndWane_${VER}_windows.zip" "build/WaxAndWane_${VER}_linux.zip"
(cd build/windows && zip -qr "../WaxAndWane_${VER}_windows.zip" .)
(cd build/linux && zip -qr "../WaxAndWane_${VER}_linux.zip" .)

if [ "${SKIP_SMOKE:-0}" != "1" ]; then
	echo "smoke test: booting the Linux build headless..."
	timeout 180 build/linux/WaxAndWane.x86_64 --headless --quit-after 3000 -- --autotest --playtest --speed=4 --god \
		> build/linux_smoke.log 2>&1 || true
	if grep -q "SCRIPT ERROR" build/linux_smoke.log; then
		grep -A3 "SCRIPT ERROR" build/linux_smoke.log | head -20
		echo "smoke test FAILED (script errors, see build/linux_smoke.log)"
		exit 1
	fi
	if ! grep -q "^\[status\]" build/linux_smoke.log; then
		tail -20 build/linux_smoke.log
		echo "smoke test FAILED (no run started, see build/linux_smoke.log)"
		exit 1
	fi
	echo "smoke test passed: $(grep -c '^\[status\]' build/linux_smoke.log) status lines, no script errors"
fi
ls -lh build/WaxAndWane_"${VER}"_*.zip
