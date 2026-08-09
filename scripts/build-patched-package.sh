#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH_FILE="$PROJECT_DIR/patches/final-clean-smali.patch"
WORK_DIR="$PROJECT_DIR/work/build"
OUT_DIR="$PROJECT_DIR/output"
APKTOOL_FRAMEWORK_DIR="$WORK_DIR/apktool-framework"
APKTOOL_HOME="$WORK_DIR/apktool-home"
APKTOOL_XDG_DATA_HOME="$WORK_DIR/xdg-data"
KEYSTORE="$PROJECT_DIR/output/freeflightthermal-compat-test.keystore"
ALIAS="freeflightthermal-compat"
STOREPASS="android"
KEYPASS="android"

EXPECTED_XAPK_SHA256="830ded7e46ab1e442b75532b0b96742d5c0d917014ea40dcc6a264a7962c8597"
EXPECTED_APK_SHA256="a0ede5bc965df0f06e741d25ccc27b4c2379ca6f442515b1c53f3fdd894d8f35"
EXPECTED_OBB_SHA256="1d90477e6a2bc88220f39c2ceabc0af8f66d860cbf4ec3abfb824a636703d2a2"

die() {
  echo "error: $*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "missing required tool: $1"
}

sha256_of() {
  sha256sum "$1" | awk '{print $1}'
}

check_sha256() {
  local label="$1"
  local file="$2"
  local expected="$3"
  local actual
  actual="$(sha256_of "$file")"
  if [ "$actual" != "$expected" ]; then
    die "$label SHA-256 mismatch: expected $expected, got $actual"
  fi
  echo "$label SHA-256 ok: $actual"
}

if [ "$#" -ne 1 ]; then
  die "usage: $0 input/freeflight-thermal-3.0.4-original.xapk"
fi

INPUT="$1"
[ -f "$INPUT" ] || die "file not found: $INPUT"

need sha256sum
need unzip
need zip
need patch
need apktool
need keytool
need apksigner
need zipalign

check_sha256 "XAPK" "$INPUT" "$EXPECTED_XAPK_SHA256"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$OUT_DIR"
mkdir -p "$APKTOOL_HOME" "$APKTOOL_XDG_DATA_HOME"

unzip -q "$INPUT" -d "$WORK_DIR/xapk"

ORIGINAL_APK="$WORK_DIR/xapk/com.parrot.freeflightthermal.apk"
ORIGINAL_OBB="$WORK_DIR/xapk/Android/obb/com.parrot.freeflightthermal/main.30003201.com.parrot.freeflightthermal.obb"

[ -f "$ORIGINAL_APK" ] || die "base APK not found inside XAPK"
[ -f "$ORIGINAL_OBB" ] || die "OBB not found inside XAPK"

check_sha256 "APK" "$ORIGINAL_APK" "$EXPECTED_APK_SHA256"
check_sha256 "OBB" "$ORIGINAL_OBB" "$EXPECTED_OBB_SHA256"

echo "Decoding APK..."
mkdir -p "$APKTOOL_FRAMEWORK_DIR"
HOME="$APKTOOL_HOME" XDG_DATA_HOME="$APKTOOL_XDG_DATA_HOME" \
  apktool d -f -r -p "$APKTOOL_FRAMEWORK_DIR" "$ORIGINAL_APK" -o "$WORK_DIR/decoded" >/dev/null

echo "Applying compatibility patch..."
(
  cd "$WORK_DIR/decoded"
  patch -p1 < "$PATCH_FILE"
)

echo "Rebuilding patched dex files..."
HOME="$APKTOOL_HOME" XDG_DATA_HOME="$APKTOOL_XDG_DATA_HOME" \
  apktool b -p "$APKTOOL_FRAMEWORK_DIR" "$WORK_DIR/decoded" -o "$WORK_DIR/rebuilt-unsigned.apk" >/dev/null

mkdir -p "$WORK_DIR/rebuilt"
unzip -q "$WORK_DIR/rebuilt-unsigned.apk" classes66.dex -d "$WORK_DIR/rebuilt"
[ -f "$WORK_DIR/rebuilt/classes66.dex" ] || die "rebuilt classes66.dex not found"

UNSIGNED_APK="$WORK_DIR/freeflightthermal-compat-unsigned.apk"
cp "$ORIGINAL_APK" "$UNSIGNED_APK"

zip -d "$UNSIGNED_APK" 'META-INF/*' >/dev/null || true
zip -d "$UNSIGNED_APK" classes66.dex >/dev/null
(
  cd "$WORK_DIR/rebuilt"
  zip -q "$UNSIGNED_APK" classes66.dex
)

ALIGNED_APK="$WORK_DIR/freeflightthermal-compat-aligned.apk"
SIGNED_APK="$OUT_DIR/freeflightthermal-3.0.4-android15-thermal-compat-signed.apk"

zipalign -f -p 4 "$UNSIGNED_APK" "$ALIGNED_APK"

if [ ! -f "$KEYSTORE" ]; then
  keytool -genkeypair \
    -keystore "$KEYSTORE" \
    -storepass "$STOREPASS" \
    -keypass "$KEYPASS" \
    -alias "$ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -dname "CN=Bebop Thermal Compat,O=Unofficial,C=BR" >/dev/null
fi

apksigner sign \
  --ks "$KEYSTORE" \
  --ks-key-alias "$ALIAS" \
  --ks-pass "pass:$STOREPASS" \
  --key-pass "pass:$KEYPASS" \
  --out "$SIGNED_APK" \
  "$ALIGNED_APK"

apksigner verify --verbose "$SIGNED_APK" >/dev/null

cp "$ORIGINAL_OBB" "$OUT_DIR/main.30003201.com.parrot.freeflightthermal.obb"

XAPK_DIR="$WORK_DIR/xapk-out"
mkdir -p "$XAPK_DIR/Android/obb/com.parrot.freeflightthermal"
cp "$SIGNED_APK" "$XAPK_DIR/com.parrot.freeflightthermal.apk"
cp "$ORIGINAL_OBB" "$XAPK_DIR/Android/obb/com.parrot.freeflightthermal/main.30003201.com.parrot.freeflightthermal.obb"
if [ -f "$WORK_DIR/xapk/manifest.json" ]; then
  cp "$WORK_DIR/xapk/manifest.json" "$XAPK_DIR/manifest.json"
fi
if [ -f "$WORK_DIR/xapk/icon.png" ]; then
  cp "$WORK_DIR/xapk/icon.png" "$XAPK_DIR/icon.png"
fi

PATCHED_XAPK="$OUT_DIR/freeflightthermal-3.0.4-android15-thermal-compat.xapk"
(
  cd "$XAPK_DIR"
  zip -qr "$PATCHED_XAPK" .
)

echo
echo "Generated:"
sha256sum "$SIGNED_APK"
sha256sum "$PATCHED_XAPK"
echo
echo "APK:  $SIGNED_APK"
echo "XAPK: $PATCHED_XAPK"
