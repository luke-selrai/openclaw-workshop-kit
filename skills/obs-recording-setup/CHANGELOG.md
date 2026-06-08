# Changelog — obs-recording-setup

All notable changes to this skill, oldest at the bottom.

## [0.1.0] — 2026-06-08

Initial release. Cross-platform OBS recording setup for vlogs / podcasts /
tutorials — perfect circular webcam + recording-friendly output.

**Grounded live 2026-06-08** against a real OBS 32 install on Linux: read the actual
config layout (`~/.config/obs-studio`, `user.ini` active profile/collection,
`basic/profiles/<n>/basic.ini`, `basic/scenes/<n>.json`), diagnosed a real
oval-webcam bug from the scene file (1080×1080 square mask stretched onto a
1920×1080 camera), and verified the fix end-to-end with the mask generator. macOS/
Windows source ids + config paths are documented from OBS's standard layout (not
live-tested on this machine — flagged in Scope Limitations).

### Added

- `SKILL.md` — Phase 0 detect (per-OS config dir + webcam/screen source-id table),
  Phase 1 install (OBS + FFmpeg per OS), Phase 2 configure: generate a
  **camera-matched circular mask** (the fix for oval webcams), apply recording
  settings (Hybrid MP4 / HQ / 48 kHz / optional dual audio tracks), add the
  webcam-as-circle and screen-capture sources, mic noise suppression, verify.
- `scripts/make-circle-mask.sh` — FFmpeg generator: `make-circle-mask.sh W H [out]`
  → RGBA circle mask sized to the camera (smoke-tested at 1920×1080 and 1280×720;
  alpha verified as a true centered circle).
- `assets/recording-profile.basic.ini` — reference Simple-mode recording profile.
- `examples/walkthrough.md` — Linux-captured walkthrough incl. the live oval→circle fix.
- `CHANGELOG.md` — this file.

### Why

Packages a repeatable OBS recording config for workshop participants. A static
config can't be shipped (camera device IDs and mask aspect ratio are per-machine),
so this **adapts**: it generates the mask to each participant's exact camera
resolution and guides the one manual step (selecting their camera). It's the
**record** front-end of the video pipeline → `video-editor` (edit) →
`hyperframes`/`higgsfield-connector` (generate/caption).
