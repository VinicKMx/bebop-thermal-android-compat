# Technical Notes

These notes describe the Android 15 failure that was reproduced on a Samsung
Galaxy Tab S6 Lite `SM-P620`.

## Symptoms

FreeFlight Thermal 3.0.4 installed and opened on Android 15. The Skycontroller 2
connection worked, drone telemetry was visible, and RGB video worked.

The thermal accessory was detected and the app switched into the thermal view,
but the live thermal image stayed black.

Important log lines showed that the problem was not just accessory detection:

```text
ARDrone3DeviceController.enableThermalCam true
ARDrone3DeviceController.onThermalCamCameraStateUpdate cam1: Camera is activated
```

The app also initialized the thermal pipeline:

```text
ThermalBlender: Update: visible 1440x1080, thermal 120x160
Vipera: Texture created for cam 0
Vipera: Texture created for cam 1
```

The repeated failure during live thermal display was in the stream/decoder path:

```text
ARStream2Receiver: No more free buffers
ARSTREAM2_StreamReceiver_RunAppOutputThread: getAuBufferCallback failed: Resource unavailable
```

## Patch Scope

Only two Smali files are patched:

```text
smali_classes66/com/parrot/controller/video/decoder/MediaCodecVideoDecoder.smali
smali_classes66/com/parrot/controller/video/decoder/ARStream2MediaCodecVideoDecoder$1.smali
```

The patch does not touch resources, package name, version name, native
libraries, OBB data, app UI, drone firmware, Skycontroller firmware, or FLIR
firmware.

## MediaCodec Changes

The original decoder initializes an AVC format as `640x368`. The working path
uses the observed thermal stream size:

```text
720x544
```

The patch also requests:

```text
MediaFormat "color-format" = 0x13
```

`0x13` is `COLOR_FormatYUV420Planar`.

## Output Buffer Change

The original code reads decoded frames from the legacy cached output buffer
array:

```text
mOutputBuffers[index]
```

That path is fragile on modern Android. The patch uses the current API:

```text
MediaCodec.getOutputBuffer(index)
```

This keeps the decoded ByteBuffer path alive for the thermal processing code
without changing the RGB surface path globally.

## Thermal Metadata Fallback

The relevant callback is:

```smali
.method public onBufferReady(IJIJIJJJLcom/parrot/arsdk/arstream2/ARSTREAM2_STREAM_RECEIVER_AU_SYNC_TYPE_ENUM;III)V
```

Relevant parameters:

```text
p2/p3 = metadata pointer, long
p4    = metadata size, int
p5/p6 = userdata pointer, long
p7    = userdata size, int
```

The original code tries:

```text
extract(p5, p7)
```

The patch keeps that first. If it returns null, it retries:

```text
extract(p2, p4)
```

This is not an arbitrary pair. The Smali metadata names `p2,p4` as
`metadata/metadataSize`, and nearby code already uses that pair as frame
metadata. The same existing Parrot thermal deserializer validates the fallback,
so the app only accepts the alternate buffer if the native parser returns a
valid thermal metadata object.

## Rejected Changes

These were tested during diagnosis and are not part of the final patch:

- fake thermal frame fallback
- forced software AVC decoder
- forced direct surface rendering
- global ByteBuffer mode, which broke RGB video
- YUV semi-planar output
- extra debug logging in the patched app

The final patch is the smallest set that restored RGB and live thermal video on
the tested Android 15 device.
