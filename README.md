# Bebop Thermal Android Compat

Minimal patch workflow for running the legacy Parrot FreeFlight Thermal 3.0.4
Android app on newer Android devices.

This repo does not contain the app. It contains the patch and the build scripts
needed to apply it to an original copy of FreeFlight Thermal 3.0.4.

Tested setup:

- Parrot Bebop-Pro Thermal
- FLIR ONE Pro rear thermal module
- Parrot Skycontroller 2
- Samsung Galaxy Tab S6 Lite `SM-P620`
- Android 15 / SDK 35

## What It Fixes

On the tested Android 15 tablet, the original app could connect to the drone and
show RGB video, but live thermal video stayed black. The drone and thermal
camera were detected, so the failure was in the Android-side video path.

The patch changes only the decoder-side Smali needed for this path:

- sets the AVC decoder size to `720x544`
- requests `COLOR_FormatYUV420Planar`
- uses `MediaCodec.getOutputBuffer(index)`
- keeps the original thermal metadata parser, with a fallback to the alternate
  metadata buffer exposed by the ARStream2 callback

## What This Repository Does Not Contain

This repo intentionally does not include:

- APK, XAPK, or OBB files
- Parrot or FLIR firmware
- native libraries from the original app
- decompiled app source
- proprietary assets

You must provide your own copy of the original FreeFlight Thermal 3.0.4 XAPK.

Expected original hashes:

```text
XAPK  830ded7e46ab1e442b75532b0b96742d5c0d917014ea40dcc6a264a7962c8597
APK   a0ede5bc965df0f06e741d25ccc27b4c2379ca6f442515b1c53f3fdd894d8f35
OBB   1d90477e6a2bc88220f39c2ceabc0af8f66d860cbf4ec3abfb824a636703d2a2
```

## Build

The build scripts are written for Linux. WSL works.

Install the tools used by the scripts:

```bash
sudo apt-get update
sudo apt-get install -y apktool apksigner zipalign default-jdk unzip zip patch adb
```

Put the original XAPK anywhere outside git, for example:

```text
input/freeflight-thermal-3.0.4-original.xapk
```

Verify it:

```bash
./scripts/verify-original.sh input/freeflight-thermal-3.0.4-original.xapk
```

Build the patched package:

```bash
./scripts/build-patched-package.sh input/freeflight-thermal-3.0.4-original.xapk
```

Outputs:

```text
output/freeflightthermal-3.0.4-android15-thermal-compat-signed.apk
output/freeflightthermal-3.0.4-android15-thermal-compat.xapk
output/main.30003201.com.parrot.freeflightthermal.obb
```

The generated APK is signed with a local test key. It is not Parrot-signed.

## Install

### Option 1: ADB

Enable USB debugging on the Android device, connect it to the computer, then
run:

```bash
./scripts/install-adb.sh
```

If another build of FreeFlight Thermal is already installed with a different
signature, uninstall it first.

### Option 2: XAPK installer

The build also creates:

```text
output/freeflightthermal-3.0.4-android15-thermal-compat.xapk
```

Install that file with any XAPK-capable Android installer. This is useful when
you want the APK and OBB expansion file installed together.

If installation fails because another FreeFlight Thermal build is already
installed, uninstall the existing app and try again.

## Use

Connect the Android device to the Skycontroller 2 over USB, power on the drone
and controller, then open FreeFlight Thermal.

The patch only addresses the Android live thermal video path. It does not pair
the drone, calibrate sensors, update firmware, or change flight behavior.

## Firmware

Do not update the Bebop, Skycontroller 2, or FLIR ONE Pro firmware as part of
this process. This fix was made entirely in the Android app package.

No reset, flash, or bootloader work is involved.

## Details

See [docs/technical-notes.md](docs/technical-notes.md).

## License

The original scripts and documentation in this repo are MIT licensed. That does
not grant rights to third-party proprietary apps, firmware, binaries, assets, or
trademarks.

See [DISCLAIMER.md](DISCLAIMER.md).
