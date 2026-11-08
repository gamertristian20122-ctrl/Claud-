#!/usr/bin/env bash
# Install what the Google Play build (tools/build_aab.sh) needs in the Android SDK:
#   cmdline-tools (sdkmanager), the SDK licences, platform-tools, and the platform + build-tools
#   versions that Godot's Android build template asks for (read from android_source.zip, so this
#   follows Godot upgrades by itself: Godot 4.7.2 wants platforms;android-36 + build-tools;36.1.0).
# Also points Godot's editor settings at the SDK and JDK if they are not set yet.
# Safe to re-run: it only downloads what is missing.
#
# Env overrides: ANDROID_HOME (default /usr/lib/android-sdk), JAVA_HOME (default: JDK 21, else 17),
#                GODOT (default godot), CMDLINE_TOOLS_ZIP (cmdline-tools build to fetch if missing).
set -euo pipefail

SDK="${ANDROID_HOME:-/usr/lib/android-sdk}"
GODOT="${GODOT:-godot}"
if [ -z "${JAVA_HOME:-}" ]; then
  for j in /usr/lib/jvm/java-21-openjdk-amd64 /usr/lib/jvm/java-17-openjdk-amd64; do
    [ -x "$j/bin/java" ] && JAVA_HOME="$j" && break
  done
fi
export JAVA_HOME
[ -x "$JAVA_HOME/bin/java" ] || { echo "No JDK found (set JAVA_HOME to a JDK 17 or 21)." >&2; exit 1; }

GODOT_VER="$("$GODOT" --version | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?\.[a-z0-9]+).*/\1/')"
TPL_ZIP="${TPL_ZIP:-$HOME/.local/share/godot/export_templates/$GODOT_VER/android_source.zip}"
[ -f "$TPL_ZIP" ] || { echo "Godot export templates for $GODOT_VER are missing ($TPL_ZIP)." >&2; exit 1; }

# What the template's config.gradle asks for, e.g. compileSdk: 36, buildTools: '36.1.0'.
CFG="$(unzip -p "$TPL_ZIP" config.gradle)"
COMPILE_SDK="$(printf '%s\n' "$CFG" | sed -nE "s/^ *compileSdk *: *([0-9]+).*/\1/p" | head -1)"
BUILD_TOOLS="$(printf '%s\n' "$CFG" | sed -nE "s/^ *buildTools *: *'([0-9.]+)'.*/\1/p" | head -1)"
echo "Godot $GODOT_VER build template wants platform android-$COMPILE_SDK and build-tools $BUILD_TOOLS"

# 1. cmdline-tools (sdkmanager)
SDKMANAGER="$SDK/cmdline-tools/latest/bin/sdkmanager"
if [ ! -x "$SDKMANAGER" ]; then
  ZIP="${CMDLINE_TOOLS_ZIP:-commandlinetools-linux-13114758_latest.zip}"
  echo "Downloading Android cmdline-tools ($ZIP) from dl.google.com ..."
  TMP="$(mktemp -d)"
  curl -fsSL --retry 4 --retry-delay 5 -o "$TMP/clt.zip" "https://dl.google.com/android/repository/$ZIP"
  unzip -q "$TMP/clt.zip" -d "$TMP"
  mkdir -p "$SDK/cmdline-tools"
  rm -rf "$SDK/cmdline-tools/latest"
  mv "$TMP/cmdline-tools" "$SDK/cmdline-tools/latest"
  rm -rf "$TMP"
fi

# 2. licences, then the packages (only the missing ones)
yes 2>/dev/null | "$SDKMANAGER" --sdk_root="$SDK" --licenses >/dev/null 2>&1 || true
PKGS=()
[ -f "$SDK/platforms/android-$COMPILE_SDK/android.jar" ] || PKGS+=("platforms;android-$COMPILE_SDK")
[ -x "$SDK/build-tools/$BUILD_TOOLS/aapt2" ] || PKGS+=("build-tools;$BUILD_TOOLS")
[ -x "$SDK/platform-tools/adb" ] || PKGS+=("platform-tools")
if [ "${#PKGS[@]}" -gt 0 ]; then
  echo "Installing: ${PKGS[*]}"
  LOG="$(mktemp)"
  if ! "$SDKMANAGER" --sdk_root="$SDK" "${PKGS[@]}" >"$LOG" 2>&1; then
    tr '\r' '\n' <"$LOG" | grep -iE "error|warning|fail|http|host" | tail -10 >&2
    echo "sdkmanager failed (log: $LOG). It downloads from dl.google.com." >&2
    exit 1
  fi
  rm -f "$LOG"
else
  echo "SDK packages already installed."
fi

# 3. Godot editor settings: SDK + JDK paths (Godot's Android export reads them from here)
ES="$(ls -1 "$HOME"/.config/godot/editor_settings-4*.tres 2>/dev/null | sort -V | tail -1 || true)"
if [ -z "$ES" ]; then
  "$GODOT" --headless --editor --quit >/dev/null 2>&1 || true
  ES="$(ls -1 "$HOME"/.config/godot/editor_settings-4*.tres 2>/dev/null | sort -V | tail -1 || true)"
fi
if [ -n "$ES" ]; then
  for kv in "export/android/android_sdk_path=$SDK" "export/android/java_sdk_path=$JAVA_HOME"; do
    k="${kv%%=*}"; v="${kv#*=}"
    if ! grep -q "^$k = \"$v\"" "$ES"; then
      sed -i "\#^$k = #d" "$ES"
      sed -i "/^\[resource\]/a $k = \"$v\"" "$ES"
      echo "Godot editor setting: $k = \"$v\""
    fi
  done
else
  echo "Could not find Godot's editor settings; set export/android/android_sdk_path and java_sdk_path by hand." >&2
fi
echo "Android SDK ready: $SDK"
