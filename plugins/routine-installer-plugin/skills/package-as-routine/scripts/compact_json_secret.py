#!/usr/bin/env python3
"""Compact a JSON value from stdin into a single-line string on stdout.

Routine-environment env-var UIs silently truncate values at the first newline,
which corrupts any JSON credential pasted in pretty-printed form. This script
is the canonical de-newline pass that every JSON secret runs through before
`pbcopy` hands it to the user.

Usage:
    cat ~/.config/gws/credentials.json | python3 compact_json_secret.py
"""
import json
import sys


def main():
    raw = sys.stdin.read()
    if not raw.strip():
        print("compact_json_secret: empty input", file=sys.stderr)
        sys.exit(1)
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"compact_json_secret: invalid JSON ({e})", file=sys.stderr)
        sys.exit(1)
    sys.stdout.write(json.dumps(parsed, separators=(",", ":"), ensure_ascii=False))
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
