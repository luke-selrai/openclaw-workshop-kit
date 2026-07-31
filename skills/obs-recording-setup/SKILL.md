---
name: obs-recording-setup
description: "Sets up OBS Studio for cross-platform screen and webcam recording, with a camera-matched circular webcam mask. Use when the user wants to set up OBS, record their screen or webcam for a vlog, podcast or tutorial, fix an oval or squished webcam circle, or get a repeatable recording config."
allowed-tools: Bash, Read, Write, Edit
metadata:
  category: Content & Writing
  tags:
    - obs
    - recording
    - screen-recording
    - webcam
    - vlog
    - podcast
    - tutorial
  pairs-with:
    - skill: video-editor
      reason: This sets up recording; video-editor stitches/silence-cuts/captions/exports the resulting files
    - skill: hyperframes-media
      reason: Captions/transcription for the recorded footage (Whisper → SRT)
    - skill: ad-creative
      reason: Script the video before recording it
    - skill: orientation
      reason: Same conversational-bootstrap pattern for non-technical users
---

# OBS Recording Setup (cross-platform)

> **Tools:** OBS Studio (the recorder) + FFmpeg (to generate the circular webcam mask). The mask generator is `scripts/make-circle-mask.sh`. Linux path verified live; macOS/Windows documented from OBS's known config layout - verify device names in the OBS UI.

## Overview

This skill makes a participant's OBS produce the **same clean recording config**: a **perfectly circular webcam**, a screen-capture scene, and **recording-friendly output settings**. It's the **record** stage of the video pipeline (record → `video-editor` to edit → publish).

The target formats are **vlogs, podcasts, tutorials, and talking-head video** - anything where a webcam and a screen share the frame. It is **cross-platform**: Linux, macOS and Windows (see the per-OS table in Phase 0).

### Why this can't be a copy-paste config (read this first)

Two parts of an OBS setup are **per-machine**, so a shipped scene file breaks on someone else's computer - the skill must **adapt**:

1. **The camera device** - OBS scene files hard-code a device ID (Linux `/dev/videoN`, Windows a DirectShow GUID, macOS an AVFoundation ID). An imported scene points at the *author's* camera. → The participant selects their own camera once (a UI step).
2. **The circular mask aspect ratio** - OBS's *Image Mask/Blend* filter **stretches the mask image to the webcam's dimensions**. A square (1080×1080) mask on a 16:9 (1920×1080) camera becomes an **oval**. → The mask must be generated to match the participant's exact capture resolution. **This is the part this skill automates and the #1 cause of "my circle is squished."**

## PHASE 0 - Detect (silent)

Determine OS and whether OBS + FFmpeg are present, and locate the OBS config dir:

| OS | OBS config dir | Webcam source id | Screen-capture source id |
|---|---|---|---|
| **Linux** | `~/.config/obs-studio` (Flatpak: `~/.var/app/com.obsproject.Studio/config/obs-studio`) | `v4l2_input` | `pipewire-screen-capture-source` (Wayland) / `xshm_input` (X11) |
| **macOS** | `~/Library/Application Support/obs-studio` | `av_capture_input` | `screen_capture` (macOS 13+) / `display_capture` |
| **Windows** | `%APPDATA%\obs-studio` | `dshow_input` | `monitor_capture` (Display) / `window_capture` |

```bash
# OBS installed? FFmpeg present?
command -v obs >/dev/null 2>&1 && echo "obs: yes" || echo "obs: missing"     # macOS app: /Applications/OBS.app
command -v ffmpeg >/dev/null 2>&1 && echo "ffmpeg: yes" || echo "ffmpeg: missing"
```
Active profile + scene collection live in `user.ini` (OBS 30+) or `global.ini` (older): keys `Profile` / `ProfileDir` / `SceneCollection` / `SceneCollectionFile`.

## PHASE 1 - Install (only what's missing)

```bash
# OBS Studio
# macOS:   brew install --cask obs
# Windows: winget install OBSProject.OBSStudio
# Linux:   sudo pacman -S obs-studio   |   sudo apt install obs-studio   |   flatpak install flathub com.obsproject.Studio

# FFmpeg (for the mask generator)
# macOS: brew install ffmpeg   |   Windows: winget install Gyan.FFmpeg   |   Linux: sudo pacman -S ffmpeg / sudo apt install ffmpeg
```
Then ask the user to open OBS once (creates the config dirs) before configuring.

## PHASE 2 - Configure

### Step 1 - Generate the camera-matched circular mask (automated)

Find the camera's **capture resolution**, then generate a mask that matches it exactly:

```bash
# Linux - read it from the device OBS uses (find the id in OBS → source Properties, e.g. /dev/video32):
v4l2-ctl -d /dev/videoN --get-fmt-video    # prints Width/Height
# macOS / Windows - read it in OBS: Video Capture Device → Properties → Resolution/Preset.

# Generate the mask (matches the camera so OBS never ovals it):
bash scripts/make-circle-mask.sh <WIDTH> <HEIGHT> ~/Pictures/obs-circle-mask.png
# e.g.  bash scripts/make-circle-mask.sh 1920 1080 ~/Pictures/obs-circle-mask.png
```
The script writes an RGBA PNG (transparent outside a centered circle) at the camera's W×H. Because it matches the source, OBS scales it **1:1** - perfect circle, **no crop filter needed**.

> If the user later changes their camera's capture resolution, re-run this with the new W×H.

### Step 2 - Recording-friendly output settings

In **OBS → Settings → Output**, set (these are portable across OS via *Simple* output mode):
- **Recording Format: Hybrid MP4** - crash-safe AND edits losslessly in `video-editor`.
- **Recording Quality: High Quality, Medium File Size** (or Advanced → CQP/CRF ~20).
- **Encoder:** Hardware (NVENC/QuickSync/VAAPI/Apple) if available, else Software (x264).
- **Settings → Audio → Sample Rate: 48 kHz.**
- *Optional (Advanced output mode):* enable **two audio tracks** and assign **mic → track 1, desktop → track 2** so editing can balance/remove each.

A reference profile is in `assets/recording-profile.basic.ini`. On **Linux** you may copy a tuned profile in directly (OBS **must be closed** first), then select it in OBS; otherwise just apply the settings above in the UI.

### Step 3 - Add the webcam as a perfect circle

1. **+ Add → Video Capture Device** → pick the user's camera (this is the one unavoidable manual selection).
2. Source → **Filters → + Image Mask/Blend** → Type **Alpha Mask (Alpha Channel)** → Path = the mask from Step 1 (`~/Pictures/obs-circle-mask.png`).
3. On canvas → **Edit Transform (Ctrl+E)** → keep the box **width = height** (don't drag a corner non-uniformly, or it ovals again).

> Using a *square* mask instead? Then you MUST add a **Crop/Pad** filter **above** the mask to crop the camera to 1:1 first. The camera-matched mask (Step 1) avoids that entirely - prefer it.

### Step 4 - Add the screen + audio

- **+ Add → Screen/Display Capture** (use the per-OS source from the Phase 0 table) → pick the monitor.
- Position the circular webcam (usually a corner).
- Mic source → **Filters**: add **Noise Suppression (RNNoise)** → **Noise Gate** (and optionally Compressor). Aim peaks ≈ −6 dB.

### Step 5 - Verify

Record a 5-second test, then confirm the file and that the webcam is round:
```bash
ffprobe -v error -show_entries format=duration:stream=codec_name,width,height -of default=noprint_wrappers=1 "<the test file>"
```
Hand the recording to **`video-editor`** to stitch/silence-cut/caption/export.

## Behaviour Guidelines

- **Generate the mask to the camera's real resolution** - never ship/assume a square mask (that's the oval bug).
- **Edit OBS config files only while OBS is closed** (it overwrites on exit). Prefer UI changes unless you've confirmed OBS is quit.
- **The camera selection is manual** - don't promise to auto-pick the device; guide the one click.
- **Don't record in OBS Safe Mode** - it disables encoders/filters (incl. the mask).
- Re-run the mask generator if the capture resolution changes.

## Scope Limitations

- **Camera/screen device selection is a UI step** (device IDs aren't portable across machines).
- **Live-verified on Linux**; macOS/Windows source ids + config paths are documented from OBS's standard layout - confirm exact names in the OBS UI (Add-source menu is the safe fallback).
- Writing OBS profile/scene files directly is offered as a Linux convenience only; the cross-platform path is guided UI + the generated mask.
- This sets up recording; it does not edit - that's `video-editor`.

## Error Handling

| Symptom | Cause | Fix |
|---|---|---|
| Webcam circle is an oval | square mask stretched onto a non-square cam | regenerate the mask at the camera's exact W×H (Step 1) |
| Mask change doesn't show | OBS cached the image | toggle the Image Mask/Blend filter off/on, or restart OBS |
| `v4l2-ctl: command not found` (Linux) | v4l-utils missing | `sudo pacman -S v4l-utils` / `sudo apt install v4l-utils`, or read the resolution in OBS Properties |
| Recording corrupts after a crash | plain MP4 | switch Recording Format to **Hybrid MP4** |
| Filter/encoder options missing | OBS in **Safe Mode** | restart OBS normally |

## Related Skills

- **video-editor** - edit the recordings (stitch, silence-cut, captions, reframe, export)
- **hyperframes-media** - Whisper transcription → SRT captions for the footage
- **hyperframes** / **higgsfield-connector** - generate B-roll to cut into the recording (HTML compositions and AI-generated footage respectively); this skill records the real footage, those generate the rest
- **ad-creative** / **copywriting** - script the video first
- **orientation** - conversational bootstrap pattern
