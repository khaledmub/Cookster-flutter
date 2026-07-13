# Cookster patch notes (media_kit_video 1.3.1)

Vendored from pub.dev `media_kit_video` 1.3.1.

## Why

On Honor/MTK devices, odd codec container heights (e.g. 721 for a 720p ladder)
caused `VideoOutputManager.SetSurfaceSize` → ImageReader/BufferQueue recreate
on every reopen, including `switch_cached` revisits. Soft mpv `video-crop` in
app code ran **after** that native path, so it could not prevent the churn.

## Patch

`AndroidVideoController` (`lib/src/video_controller/android_video_controller/real.dart`)
gates raw `videoParams` sizes through `AndroidSurfaceSizeGate` **before**
`VideoOutputManager.SetSurfaceSize`. Benign odd/even ±1 reports either:

- skip `SetSurfaceSize` entirely when the gated size matches the current rect, or
- call `SetSurfaceSize` only with the clamped / previously painted even size.

Log line: `[ReelsPoster] dimension_parity_benign_skip ... action=skip_setSurfaceSize|clamp_before_setSurfaceSize`
(this must appear **before** any native recreate for that generation — or native
calls must not appear at all for a parity-only reopen).
