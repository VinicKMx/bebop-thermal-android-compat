#!/usr/bin/env bash
set -euo pipefail

APK="${1:-output/freeflightthermal-3.0.4-android15-thermal-compat-signed.apk}"
OBB="${2:-output/main.30003201.com.parrot.freeflightthermal.obb}"

[ -f "$APK" ] || { echo "APK not found: $APK" >&2; exit 1; }
[ -f "$OBB" ] || { echo "OBB not found: $OBB" >&2; exit 1; }

adb install -r "$APK"
adb shell mkdir -p /sdcard/Android/obb/com.parrot.freeflightthermal
adb push "$OBB" /sdcard/Android/obb/com.parrot.freeflightthermal/
adb shell pm grant com.parrot.freeflightthermal android.permission.ACCESS_FINE_LOCATION || true
adb shell pm grant com.parrot.freeflightthermal android.permission.ACCESS_COARSE_LOCATION || true
adb shell pm grant com.parrot.freeflightthermal android.permission.CAMERA || true

echo "Installed FreeFlight Thermal compatibility package."
