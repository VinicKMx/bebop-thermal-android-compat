#!/usr/bin/env bash
set -euo pipefail

EXPECTED_XAPK_SHA256="830ded7e46ab1e442b75532b0b96742d5c0d917014ea40dcc6a264a7962c8597"
EXPECTED_APK_SHA256="a0ede5bc965df0f06e741d25ccc27b4c2379ca6f442515b1c53f3fdd894d8f35"
EXPECTED_OBB_SHA256="1d90477e6a2bc88220f39c2ceabc0af8f66d860cbf4ec3abfb824a636703d2a2"
EXPECTED_PACKAGE="com.parrot.freeflightthermal"
EXPECTED_VERSION_NAME="3.0.4"
EXPECTED_VERSION_CODE="30004201"

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

check_sha256 "XAPK" "$INPUT" "$EXPECTED_XAPK_SHA256"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

unzip -q "$INPUT" -d "$TMP_DIR"

APK="$TMP_DIR/com.parrot.freeflightthermal.apk"
OBB="$TMP_DIR/Android/obb/com.parrot.freeflightthermal/main.30003201.com.parrot.freeflightthermal.obb"

[ -f "$APK" ] || die "base APK not found inside XAPK"
[ -f "$OBB" ] || die "OBB not found inside XAPK"

check_sha256 "APK" "$APK" "$EXPECTED_APK_SHA256"
check_sha256 "OBB" "$OBB" "$EXPECTED_OBB_SHA256"

if command -v aapt >/dev/null 2>&1; then
  BADGING="$(aapt dump badging "$APK")"
  echo "$BADGING" | grep -q "package: name='$EXPECTED_PACKAGE'" || die "package name mismatch"
  echo "$BADGING" | grep -q "versionCode='$EXPECTED_VERSION_CODE'" || die "versionCode mismatch"
  echo "$BADGING" | grep -q "versionName='$EXPECTED_VERSION_NAME'" || die "versionName mismatch"
  echo "APK package/version ok"
else
  echo "aapt not found; skipped package/version check"
fi

echo "Original package verified."
