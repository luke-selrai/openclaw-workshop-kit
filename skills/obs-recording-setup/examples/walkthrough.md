# OBS Recording Setup — Walkthrough

> **Status: Linux path captured live 2026-06-08** against a real OBS 32 install
> (config at `~/.config/obs-studio`, webcam `/dev/video32` @ 1920×1080 MJPG).
> The mask generator and the oval→circle fix were verified end-to-end. macOS/Windows
> steps are documented from OBS's standard config layout — confirm device names in the UI.

## The problem this solves (captured live)

A webcam circle came out **oval**. Root cause, read from the live OBS scene file:
the webcam captured at **1920×1080 (16:9)** but the Image Mask/Blend filter used a
**1080×1080 square** mask — OBS stretched the square mask across the 16:9 frame → oval.

**Fix (verified):** generate the mask at the camera's exact resolution so OBS scales
it 1:1.

```bash
$ bash scripts/make-circle-mask.sh 1920 1080 ~/Pictures/obs-circle-mask.png
/home/<user>/Pictures/obs-circle-mask.png
Created 1920x1080 circular mask (diameter 1080px, centered).

# verified: alpha is a true circle (centered), transparent on all sides incl. horizontally
center (960,540): 255
right-edge (1900,540): 0
```
Point OBS → webcam → Image Mask/Blend (Alpha Mask) at this file, toggle the filter
off/on to reload → perfect circle. No Crop/Pad needed because the mask already matches
the source.

## Full setup (the order the skill follows)

1. **Detect** OS + OBS/FFmpeg + config dir (Phase 0 table).
2. **Install** OBS + FFmpeg if missing (per-OS commands).
3. **Generate** the camera-matched mask (above).
4. **Output settings:** Recording Format **Hybrid MP4**, Quality **HQ**, Audio **48 kHz**
   (reference: `assets/recording-profile.basic.ini`).
5. **Webcam source:** Add Video Capture Device → pick camera → Image Mask/Blend → the mask.
6. **Screen + audio:** Add Display/Screen Capture; mic → Noise Suppression (RNNoise).
7. **Verify:** record 5s, `ffprobe` it, hand to `video-editor`.

## Capture-resolution cheat by OS

| OS | How to read the camera's W×H |
|---|---|
| Linux | `v4l2-ctl -d /dev/videoN --get-fmt-video` (id from OBS source Properties) |
| macOS | OBS → Video Capture Device → Properties → Preset/Resolution |
| Windows | OBS → Video Capture Device → Properties → Resolution |

Then: `bash scripts/make-circle-mask.sh <W> <H> ~/Pictures/obs-circle-mask.png`

## Hand-off

Record → files land in your videos folder → invoke **`video-editor`** with the paths →
stitch in order → silence-cut → captions → export. Hybrid MP4 keeps joins lossless.
