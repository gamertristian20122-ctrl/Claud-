#!/usr/bin/env bash
# Build the Google Play app bundle build/WaxAndWane_v<version>.aab and check it is Play-ready.
#
#   ./tools/build_aab.sh                       build + check (one command, safe to re-run)
#   ./tools/build_aab.sh --verify FILE.aab     only run the checks on an existing bundle
#
# What it does:
#   1. tools/android_sdk_setup.sh: platform + build-tools that Godot's Gradle template needs.
#   2. Installs Godot's Android build template into android/ (git-ignored, re-created from the
#      export templates whenever the Godot version changes).
#   3. Copies version/code + version/name from the "Android" (APK) preset into "Android Play",
#      so a version bump only has to be made in the usual place.
#   4. Exports the "Android Play" preset (Gradle build, AAB, arm64-v8a, min SDK 24, target SDK 36),
#      signed with the same private release key as tools/build_apk.sh. Gradle downloads are retried
#      with backoff (repo.maven.apache.org sometimes answers 429).
#   5. Checks the bundle with bundletool: validate, manifest (package, versionCode, targetSdk 36,
#      not debuggable, permissions, label), a universal APK signed with the same key, 16 KB page
#      alignment of the native libraries, and that the signing certificate is the release key.
#
# The release key lives in the PRIVATE repo FailedIdolsOfTheAbyss (keystore/). Never copy it here.
# Env overrides: KS_DIR, KEYSTORE, KEYSTORE_USER, KEYSTORE_PASS (same as build_apk.sh), GODOT,
#   ANDROID_HOME, JAVA_HOME, MAVEN_MIRROR (Maven Central mirror for Gradle, "none" to turn off),
#   GRADLE_TRIES (default 4), BUNDLETOOL (path to a bundletool-all jar).
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
GODOT="${GODOT:-godot}"
SDK="${ANDROID_HOME:-/usr/lib/android-sdk}"
PRESET="Android Play"
APK_PRESET="Android"
PKG="com.tallow.waxandwane"
LABEL="Wax & Wane"
TARGET_SDK=36
MIN_SDK=24
BT_VER=1.18.3
BT_SHA256=a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29
MAVEN_MIRROR="${MAVEN_MIRROR:-https://maven-central.storage-download.googleapis.com/maven2/}"
GRADLE_TRIES="${GRADLE_TRIES:-4}"

if [ -z "${JAVA_HOME:-}" ]; then
  for j in /usr/lib/jvm/java-21-openjdk-amd64 /usr/lib/jvm/java-17-openjdk-amd64; do
    [ -x "$j/bin/java" ] && JAVA_HOME="$j" && break
  done
fi
export JAVA_HOME ANDROID_HOME="$SDK"
JAVA="$JAVA_HOME/bin/java"
KEYTOOL="$JAVA_HOME/bin/keytool"
BT_DIR="$(ls -d "$SDK"/build-tools/* | sort -V | tail -1)"

say()  { printf '\n== %s\n' "$*"; }
fail() { printf 'FAILED: %s\n' "$*" >&2; exit 1; }

# ---------- signing key (same rules as build_apk.sh, plus a few more places to look) ----------
find_ks_dir() {
  local d
  for d in "${KS_DIR:-}" "$ROOT/../../FailedIdolsOfTheAbyss/keystore" \
           "$HOME/FailedIdolsOfTheAbyss/keystore" "/home/user/FailedIdolsOfTheAbyss/keystore"; do
    if [ -n "$d" ] && [ -f "$d/release.keystore" ]; then echo "$d"; return 0; fi
  done
  return 1
}
load_key() {
  local ks_dir=""
  ks_dir="$(find_ks_dir || true)"
  KEYSTORE="${KEYSTORE:-$ks_dir/release.keystore}"
  KEYSTORE_USER="${KEYSTORE_USER:-failedidols}"
  if [ -z "${KEYSTORE_PASS:-}" ]; then
    [ -f "$ks_dir/KEYSTORE_PASSWORD.txt" ] || fail "release key not found (set KS_DIR to FailedIdolsOfTheAbyss/keystore)"
    KEYSTORE_PASS="$(grep '^Password:' "$ks_dir/KEYSTORE_PASSWORD.txt" | awk '{print $2}')"
  fi
  [ -f "$KEYSTORE" ] || fail "keystore missing: $KEYSTORE"
  export KEYSTORE_PASS
  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE"
  export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$KEYSTORE_USER"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$KEYSTORE_PASS"
}

# ---------- export_presets.cfg helpers ----------
preset_index() {  # preset name -> N of [preset.N]
  awk -v want="name=\"$1\"" '/^\[preset\.[0-9]+\]$/ { n = $0; gsub(/[^0-9]/, "", n) } $0 == want { print n; exit }' export_presets.cfg
}
get_opt() {  # N key -> raw value
  awk -v sec="[preset.$1.options]" -v key="$2=" '
    $0 == sec { f = 1; next } /^\[/ { f = 0 } f && index($0, key) == 1 { print substr($0, length(key) + 1); exit }' export_presets.cfg
}
set_opt() {  # N key value
  sed -i "/^\[preset\.$1\.options\]/,/^\[/ s|^$2=.*|$2=$3|" export_presets.cfg
}

# ---------- 1-3: SDK, build template, versions ----------
prepare() {
  say "Android SDK"
  ./tools/android_sdk_setup.sh

  say "Godot Android build template"
  local gv tpl
  gv="$("$GODOT" --version | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?\.[a-z0-9]+).*/\1/')"
  tpl="$HOME/.local/share/godot/export_templates/$gv/android_source.zip"
  [ -f "$tpl" ] || fail "missing $tpl (install Godot $gv export templates)"
  if [ "$(cat android/.build_version 2>/dev/null)" != "$gv" ] || [ ! -f android/build/build.gradle ]; then
    echo "Installing the $gv template into android/build"
    rm -rf android/build
    mkdir -p android/build
    unzip -q "$tpl" -d android/build
    printf '\n' > android/build/.gdignore      # keep Godot's importer out of it
    printf '%s\n' "$gv" > android/.build_version
    chmod +x android/build/gradlew
  else
    echo "Template $gv already installed"
  fi
  # Ask Gradle to try a Maven Central mirror before repo.maven.apache.org (which rate-limits with
  # HTTP 429). Same artifacts, same checksums; mavenCentral() stays as the fallback.
  local f
  for f in android/build/settings.gradle android/build/build.gradle; do
    sed -i '/build_aab.sh mirror/d' "$f"
    if [ "$MAVEN_MIRROR" != "none" ]; then
      sed -i -E "s#^([[:space:]]*)mavenCentral\(\)#\1maven { url \"$MAVEN_MIRROR\" } // build_aab.sh mirror\n\1mavenCentral()#" "$f"
    fi
  done
  [ "$MAVEN_MIRROR" != "none" ] && echo "Gradle: Maven Central mirror $MAVEN_MIRROR" || echo "Gradle: no mirror"

  say "Versions"
  local a p code name
  a="$(preset_index "$APK_PRESET")"; p="$(preset_index "$PRESET")"
  [ -n "$a" ] && [ -n "$p" ] || fail "export_presets.cfg needs the \"$APK_PRESET\" and \"$PRESET\" presets"
  code="$(get_opt "$a" version/code)"; name="$(get_opt "$a" version/name)"
  if [ "$(get_opt "$p" version/code)" != "$code" ] || [ "$(get_opt "$p" version/name)" != "$name" ]; then
    set_opt "$p" version/code "$code"
    set_opt "$p" version/name "$name"
    echo "Copied version code $code / name $name into \"$PRESET\" (commit export_presets.cfg)"
  fi
  VERSION_CODE="$code"
  VERSION_NAME="$(printf '%s' "$name" | tr -d '"')"
  echo "versionCode $VERSION_CODE, versionName $VERSION_NAME"
}

# ---------- 4: export with retries ----------
export_aab() {
  local out="build/WaxAndWane_v$VERSION_NAME.aab" log="build/build_aab.log" try=1 wait=30
  mkdir -p build
  "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
  while :; do
    say "Export \"$PRESET\" -> $out (try $try/$GRADLE_TRIES)"
    rm -f "$out"
    if "$GODOT" --headless --path . --export-release "$PRESET" "$out" >"$log" 2>&1 && [ -s "$out" ]; then
      break
    fi
    grep -E "BUILD FAILED|What went wrong|Could not (GET|HEAD|download|resolve)|status code|ERROR:" "$log" \
      | sed 's/^[[:space:]]*//' | sort | uniq -c | sort -rn | head -12 || true
    if grep -q -E "status code (429|5[0-9][0-9])|Could not (GET|HEAD|download)|Connection (reset|refused)|timed out|Read timed out" "$log" \
       && [ "$try" -lt "$GRADLE_TRIES" ]; then
      echo "Network trouble while Gradle downloaded (hosts above). Retrying in ${wait}s; finished downloads are cached."
      sleep "$wait"; try=$((try + 1)); wait=$((wait * 2)); continue
    fi
    fail "export failed, full log: $log"
  done
  AAB="$out"
  ls -lh "$AAB"
}

# ---------- 5: checks ----------
get_bundletool() {
  if [ -n "${BUNDLETOOL:-}" ]; then return 0; fi
  local dir="${XDG_CACHE_HOME:-$HOME/.cache}/waxandwane"
  BUNDLETOOL="$dir/bundletool-all-$BT_VER.jar"
  if [ ! -f "$BUNDLETOOL" ] || ! echo "$BT_SHA256  $BUNDLETOOL" | sha256sum -c --quiet - 2>/dev/null; then
    mkdir -p "$dir"
    echo "Downloading bundletool $BT_VER (github.com release asset)"
    curl -fsSL --retry 4 --retry-delay 5 -o "$BUNDLETOOL.part" \
      "https://github.com/google/bundletool/releases/download/$BT_VER/bundletool-all-$BT_VER.jar" \
      || fail "could not download bundletool from github.com / release-assets.githubusercontent.com"
    echo "$BT_SHA256  $BUNDLETOOL.part" | sha256sum -c --quiet - || fail "bundletool checksum mismatch"
    mv "$BUNDLETOOL.part" "$BUNDLETOOL"
  fi
}

verify_aab() {
  local aab="$1" chk errs=0 tmp
  [ -s "$aab" ] || fail "no bundle at $aab"
  get_bundletool
  load_key
  chk="build/aab_check"
  rm -rf "$chk"; mkdir -p "$chk"
  bt() { "$JAVA" -jar "$BUNDLETOOL" "$@"; }
  ok()  { printf '  ok    %s\n' "$*"; }
  bad() { printf '  FAIL  %s\n' "$*"; errs=$((errs + 1)); }

  say "bundletool validate"
  if bt validate --bundle="$aab" >"$chk/validate.txt" 2>&1; then ok "bundle is valid"; else bad "validate (see $chk/validate.txt)"; fi

  say "Manifest"
  bt dump manifest --bundle="$aab" >"$chk/AndroidManifest.xml" 2>"$chk/dump.txt" || bad "bundletool dump manifest"
  local m="$chk/AndroidManifest.xml"
  grep -q "package=\"$PKG\"" "$m" && ok "package $PKG" || bad "package is not $PKG"
  local vc vn
  vc="$(grep -o 'android:versionCode="[0-9]*"' "$m" | grep -o '[0-9]*' || true)"
  vn="$(grep -o 'android:versionName="[^"]*"' "$m" | cut -d'"' -f2 || true)"
  [ -n "${VERSION_CODE:-}" ] && [ "$vc" != "$VERSION_CODE" ] && bad "versionCode $vc (expected $VERSION_CODE)" || ok "versionCode $vc, versionName $vn"
  grep -q "android:targetSdkVersion=\"$TARGET_SDK\"" "$m" && ok "targetSdkVersion $TARGET_SDK" || bad "targetSdkVersion is not $TARGET_SDK"
  grep -q "android:minSdkVersion=\"$MIN_SDK\"" "$m" && ok "minSdkVersion $MIN_SDK" || bad "minSdkVersion is not $MIN_SDK"
  grep -q 'android:debuggable="true"' "$m" && bad "debuggable=true" || ok "not debuggable"
  local perms
  perms="$(grep -o 'android:name="android.permission[^"]*"' "$m" | cut -d'"' -f2 | sort -u | tr '\n' ' ' || true)"
  echo "        permissions: ${perms:-none}"
  for p in $perms; do
    case "$p" in
      android.permission.VIBRATE) ;;
      *) bad "unexpected permission $p" ;;
    esac
  done

  say "Universal APK (signed with the release key)"
  tmp="$(mktemp)"; chmod 600 "$tmp"; printf '%s' "$KEYSTORE_PASS" >"$tmp"
  if bt build-apks --bundle="$aab" --output="$chk/universal.apks" --mode=universal --overwrite \
       --ks="$KEYSTORE" --ks-key-alias="$KEYSTORE_USER" --ks-pass="file:$tmp" --key-pass="file:$tmp" \
       >"$chk/build-apks.txt" 2>&1; then
    rm -f "$tmp"
    unzip -o -q "$chk/universal.apks" universal.apk -d "$chk"
    ok "universal.apk $(du -h "$chk/universal.apk" | cut -f1)"
    "$BT_DIR/aapt2" dump badging "$chk/universal.apk" 2>/dev/null >"$chk/badging.txt" || true
    grep -E "^package:|^sdkVersion|^targetSdkVersion|^uses-permission|^application-label:|^native-code|debuggable" \
      "$chk/badging.txt" | sed 's/^/        /'
    grep -q "^application-label:'$LABEL'" "$chk/badging.txt" && ok "app label \"$LABEL\"" || bad "app label is not \"$LABEL\""
    local other
    other="$(grep "^application-label-" "$chk/badging.txt" | grep -v ":'$LABEL'$" | head -3 || true)"
    [ -z "$other" ] && ok "same label in every language" || bad "label differs in some languages: $other"
    grep -q "application-debuggable" "$chk/badging.txt" && bad "APK is debuggable" || true
  else
    rm -f "$tmp"
    bad "build-apks failed (see $chk/build-apks.txt)"
  fi

  say "16 KB page size"
  mkdir -p "$chk/so"
  unzip -o -q "$aab" 'base/lib/*' -d "$chk/so" 2>/dev/null || true
  local so n=0 abis
  abis="$(cd "$chk/so/base/lib" 2>/dev/null && ls | tr '\n' ' ' || true)"
  [ "$abis" = "arm64-v8a " ] && ok "native code: arm64-v8a only" || echo "        ABIs: ${abis:-none}"
  local al min
  while IFS= read -r so; do
    n=$((n + 1))
    # every LOAD segment must be aligned to at least 16 KB (0x4000)
    min=""
    for al in $(readelf -lW "$so" | awk '$1 == "LOAD" { print $NF }'); do
      if [ -z "$min" ] || [ $((al)) -lt "$min" ]; then min=$((al)); fi
    done
    if [ -n "$min" ] && [ "$min" -ge 16384 ]; then
      ok "$(basename "$so"): ELF LOAD segments aligned to $((min / 1024)) KB"
    else
      bad "$(basename "$so"): ELF LOAD segment alignment ${min:-?} bytes, below 16 KB"
    fi
  done < <(find "$chk/so" -name '*.so')
  [ "$n" -gt 0 ] || bad "no native libraries found in the bundle"
  if [ -f "$chk/universal.apk" ]; then
    if "$BT_DIR/zipalign" -c -P 16 -v 4 "$chk/universal.apk" >"$chk/zipalign.txt" 2>&1; then
      ok "zipalign -c -P 16: universal APK passes"
    else
      bad "zipalign -c -P 16 failed (see $chk/zipalign.txt)"
    fi
  fi

  say "Signature"
  local want got_aab got_apk
  want="$("$KEYTOOL" -list -v -keystore "$KEYSTORE" -alias "$KEYSTORE_USER" -storepass:env KEYSTORE_PASS 2>/dev/null \
          | awk '/SHA256:/ { print $2; exit }' | tr -d ':' | tr 'A-F' 'a-f')"
  got_aab="$("$KEYTOOL" -printcert -jarfile "$aab" 2>/dev/null | awk '/SHA256:/ { print $2; exit }' | tr -d ':' | tr 'A-F' 'a-f')"
  [ -n "$want" ] && [ "$got_aab" = "$want" ] && ok "bundle signed with the release key (SHA-256 ${want:0:16}...)" \
    || bad "bundle signer ${got_aab:-none} is not the release key ${want:-?}"
  if [ -f "$chk/universal.apk" ]; then
    got_apk="$("$BT_DIR/apksigner" verify --print-certs "$chk/universal.apk" 2>/dev/null | awk '/SHA-256 digest/ { print $NF; exit }')"
    [ "$got_apk" = "$want" ] && ok "universal APK verifies with the same key" || bad "universal APK signer $got_apk"
  fi

  say "Result"
  if [ "$errs" -eq 0 ]; then
    echo "PLAY-READY: $aab ($(du -h "$aab" | cut -f1)). Check files: $chk/"
  else
    fail "$errs check(s) failed for $aab (details in $chk/)"
  fi
}

if [ "${1:-}" = "--verify" ]; then
  verify_aab "${2:?usage: tools/build_aab.sh --verify FILE.aab}"
  exit 0
fi
load_key
prepare
export_aab
verify_aab "$AAB"
