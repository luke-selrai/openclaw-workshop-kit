#!/bin/sh
umask 077
[ "$#" -eq 1 ] || exit 64
case "${HIGGSFIELD_CAPTURE_URL_FILE:-}" in
  /*) ;;
  *) exit 64 ;;
esac
case "$1" in
  https://clerk.higgsfield.ai/oauth/authorize\?*)
    printf '%s\n' "$1" > "$HIGGSFIELD_CAPTURE_URL_FILE"
    ;;
  *) exit 64 ;;
esac
