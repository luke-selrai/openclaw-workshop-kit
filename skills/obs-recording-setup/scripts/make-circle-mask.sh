#!/usr/bin/env bash
# make-circle-mask.sh — generate a perfect circular OBS webcam mask sized to the
# camera's CAPTURE resolution, so OBS's Image Mask/Blend stretches it 1:1 (no oval).
#
# Why this matters: OBS stretches the mask image to fill the webcam source's
# dimensions. A square (e.g. 1080x1080) mask on a 16:9 (1920x1080) camera becomes
# an OVAL. Matching the mask to the camera's exact W×H keeps the circle perfect.
#
# Usage:
#   make-circle-mask.sh <WIDTH> <HEIGHT> [OUTPUT.png]
#   make-circle-mask.sh 1920 1080
#   make-circle-mask.sh 1280 720 ~/Pictures/circle-mask.png
#
# Default OUTPUT: ~/Pictures/obs-circle-mask-<W>x<H>.png
# Requires: ffmpeg (cross-platform: brew/winget/apt/pacman).
set -euo pipefail

W="${1:-}"; H="${2:-}"
if [ -z "$W" ] || [ -z "$H" ]; then
  echo "usage: $0 <WIDTH> <HEIGHT> [OUTPUT.png]" >&2
  echo "tip — find your camera's capture resolution:" >&2
  echo "  Linux:   v4l2-ctl -d /dev/videoN --get-fmt-video   (or OBS → source Properties → Resolution)" >&2
  echo "  macOS:   OBS → Video Capture Device → Properties → Preset/Resolution" >&2
  echo "  Windows: OBS → Video Capture Device → Properties → Resolution" >&2
  exit 2
fi
case "$W$H" in *[!0-9]*) echo "WIDTH and HEIGHT must be integers" >&2; exit 2;; esac

OUT="${3:-$HOME/Pictures/obs-circle-mask-${W}x${H}.png}"
mkdir -p "$(dirname "$OUT")"
command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg not found — install it first" >&2; exit 3; }

# diameter = smaller dimension; centered; 2px inset so the rim isn't clipped.
D=$(( W < H ? W : H ))
CX=$(( W / 2 )); CY=$(( H / 2 )); R=$(( D / 2 - 2 ))

ffmpeg -nostdin -loglevel error -f lavfi -i "color=white:s=${W}x${H}" \
  -vf "format=rgba,geq=r='255':g='255':b='255':a='if(lte((X-${CX})*(X-${CX})+(Y-${CY})*(Y-${CY}),${R}*${R}),255,0)'" \
  -frames:v 1 -y "$OUT"

echo "$OUT"
echo "Created ${W}x${H} circular mask (diameter ${D}px, centered)."
echo "Point OBS → webcam → Image Mask/Blend → Alpha Mask (Alpha Channel) at this file."
