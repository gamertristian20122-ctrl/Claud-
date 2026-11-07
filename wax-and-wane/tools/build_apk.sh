#!/usr/bin/env bash
# Build the signed release APK: build/WaxAndWane.apk
# Signed with the owner's private release key, which lives in the PRIVATE repo
# FailedIdolsOfTheAbyss (keystore/). Never copy the key into this public repo.
# Override with KEYSTORE=/path/to/release.keystore KEYSTORE_USER=alias KEYSTORE_PASS=...
set -euo pipefail
cd "$(dirname "$0")/.."

KS_DIR="${KS_DIR:-$PWD/../../FailedIdolsOfTheAbyss/keystore}"
KEYSTORE="${KEYSTORE:-$KS_DIR/release.keystore}"
KEYSTORE_USER="${KEYSTORE_USER:-failedidols}"
KEYSTORE_PASS="${KEYSTORE_PASS:-$(grep "^Password:" "$KS_DIR/KEYSTORE_PASSWORD.txt" | awk '{print $2}')}"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$KEYSTORE_USER"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$KEYSTORE_PASS"

mkdir -p build
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --export-release "Android" build/WaxAndWane.apk

BT=$(ls -d "${ANDROID_HOME:-/usr/lib/android-sdk}"/build-tools/* | sort -V | tail -1)
"$BT/apksigner" verify --print-certs build/WaxAndWane.apk | head -3
ls -lh build/WaxAndWane.apk
