#!/usr/bin/env bash
# Wax & Wane: pushes the builds to itch.io with butler, itch.io's own command-line uploader. Optional: the
# itch.io website's "Upload files" button does the same by hand (docs/marketing/POST_IT.md, itch.io steps).
#
#   ITCH_USER=yourname ./tools/upload_itch.sh             push the Windows zip, the Linux zip and the APK
#   ITCH_USER=yourname ./tools/upload_itch.sh --dry-run   only show what would be pushed
#
# Channels (itch.io shows one download button per channel, and updates it in place next time):
#   <user>/wax-and-wane:windows   build/WaxAndWane_<ver>_windows.zip
#   <user>/wax-and-wane:linux     build/WaxAndWane_<ver>_linux.zip
#   <user>/wax-and-wane:android   build/WaxAndWane_v<ver>.apk
# The version comes from scripts/autoload/game.gd (VERSION=2.0.0 overrides it); ITCH_GAME overrides the page.
#
# The itch.io API key: itch.io > Settings > API keys > Generate new API key. Give it to butler as the
# BUTLER_API_KEY environment variable (or run `butler login` once on your own computer). Never write it into
# a file in this repository: the repository is public.
# butler itself is downloaded once into ~/.cache/waxandwane/butler/ if it is not on PATH
# (https://itch.io/docs/butler/installing.html).
set -euo pipefail
cd "$(dirname "$0")/.."

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1
VER="${VERSION:-$(sed -n 's/^const VERSION := "\(.*\)"/\1/p' scripts/autoload/game.gd)}"
[ -n "$VER" ] || { echo "[upload_itch] could not read VERSION from scripts/autoload/game.gd" >&2; exit 1; }
ITCH_USER="${ITCH_USER:-}"
[ -n "$ITCH_USER" ] || { echo "[upload_itch] set ITCH_USER to your itch.io user name, e.g. ITCH_USER=yourname $0" >&2; exit 1; }
GAME="${ITCH_GAME:-wax-and-wane}"

FILES=("build/WaxAndWane_${VER}_windows.zip" "build/WaxAndWane_${VER}_linux.zip" "build/WaxAndWane_v${VER}.apk")
CHANNELS=(windows linux android)
missing=0
for f in "${FILES[@]}"; do
	if [ ! -f "$f" ]; then
		echo "[upload_itch] missing $f" >&2
		missing=1
	fi
done
if [ "$missing" = 1 ]; then
	echo "[upload_itch] make them first: ./tools/build_desktop.sh and ./tools/build_apk.sh (then copy the APK to build/WaxAndWane_v${VER}.apk)" >&2
	exit 1
fi

BUTLER="$(command -v butler || true)"
if [ -z "$BUTLER" ]; then
	BUTLER="$HOME/.cache/waxandwane/butler/butler"
	if [ ! -x "$BUTLER" ] && [ "$DRY" = 0 ]; then
		echo "[upload_itch] downloading butler ..."
		mkdir -p "$(dirname "$BUTLER")"
		curl -fsSL -o "$(dirname "$BUTLER")/butler.zip" https://broth.itch.zone/butler/linux-amd64/LATEST/archive/default
		(cd "$(dirname "$BUTLER")" && unzip -oq butler.zip && chmod +x butler)
	fi
fi

for i in "${!FILES[@]}"; do
	target="$ITCH_USER/$GAME:${CHANNELS[$i]}"
	echo "[upload_itch] ${FILES[$i]} -> $target (version $VER)"
	if [ "$DRY" = 0 ]; then
		"$BUTLER" push "${FILES[$i]}" "$target" --userversion "$VER"
	fi
done
if [ "$DRY" = 0 ]; then
	"$BUTLER" status "$ITCH_USER/$GAME"
else
	echo "[upload_itch] dry run: nothing was uploaded"
fi
