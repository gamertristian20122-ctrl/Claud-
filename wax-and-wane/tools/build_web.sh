#!/usr/bin/env bash
# Build the browser version (single-threaded WebAssembly: it needs no special server headers, so it runs on itch.io):
#   build/web/                          index.html + the engine + the game
#   build/WaxAndWane_<version>_web.zip  the same, zipped with index.html at the top (what itch.io wants)
# Then, if node and Playwright are here, boots it in headless Chromium and fails on any browser console error.
#   SKIP_SMOKE=1 ./tools/build_web.sh    skip the boot test
# On itch.io: Kind of project "HTML", upload the zip, tick "This file will be played in the browser",
# viewport 1152 x 648 (three game pixels per screen pixel, no border), and turn on the fullscreen button.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
VER="$(sed -n 's/^const VERSION := "\(.*\)"/\1/p' scripts/autoload/game.gd)"
[ -n "$VER" ] || { echo "could not read VERSION from scripts/autoload/game.gd"; exit 1; }

rm -rf build/web
mkdir -p build/web
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
git checkout -- default_bus_layout.tres 2>/dev/null || true
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
[ -f build/web/index.wasm ] || { echo "export failed: no build/web/index.wasm"; exit 1; }

rm -f "build/WaxAndWane_${VER}_web.zip"
(cd build/web && zip -qr "../WaxAndWane_${VER}_web.zip" .)
echo "built build/WaxAndWane_${VER}_web.zip ($(du -h "build/WaxAndWane_${VER}_web.zip" | cut -f1))"

if [ "${SKIP_SMOKE:-0}" != "1" ] && command -v node >/dev/null 2>&1 && node -e "require('playwright')" >/dev/null 2>&1; then
	echo "smoke test: booting the browser build in headless Chromium..."
	(cd build/web && python3 -m http.server 8766 >/dev/null 2>&1 &)
	sleep 1
	set +e
	node tools/web_smoke.js "http://127.0.0.1:8766/index.html" build/web_smoke.png > build/web_smoke.log 2>&1
	rc=$?
	set -e
	pkill -f "http.server 8766" || true
	cat build/web_smoke.log
	[ "$rc" -eq 0 ] || { echo "smoke test FAILED (see build/web_smoke.log)"; exit 1; }
	echo "smoke test passed (screenshot: build/web_smoke.png)"
fi
