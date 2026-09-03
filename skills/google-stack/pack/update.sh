#!/bin/bash
# Re-pull the vendored Google skill packs. Verbatim upstream trees, no local edits kept.
# Run from anywhere: the pack is the folder this script lives in.
set -euo pipefail
PACK="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "cloning upstream…"
git clone --depth 1 -q https://github.com/google/skills.git "$TMP/google-skills"
git clone --depth 1 -q https://github.com/google-gemini/gemini-skills.git "$TMP/gemini-skills"

GS=$(git -C "$TMP/google-skills" rev-parse HEAD); GD=$(git -C "$TMP/google-skills" log -1 --format=%cs)
MS=$(git -C "$TMP/gemini-skills" rev-parse HEAD); MD=$(git -C "$TMP/gemini-skills" log -1 --format=%cs)

for d in ads analytics cloud developers gemini; do
  [ -d "$PACK/$d" ] && rm -rf "${PACK:?}/$d"
done
for d in ads analytics cloud developers; do
  cp -R "$TMP/google-skills/skills/$d" "$PACK/$d"
done
mkdir -p "$PACK/gemini" && cp -R "$TMP/gemini-skills/skills/." "$PACK/gemini/"
cp "$TMP/google-skills/LICENSE" "$PACK/LICENSE"

GSN=$(find "$PACK/ads" "$PACK/analytics" "$PACK/cloud" "$PACK/developers" -name SKILL.md | wc -l | tr -d ' ')
MSN=$(find "$PACK/gemini" -name SKILL.md | wc -l | tr -d ' ')

python3 - "$PACK" "$GS" "$GD" "$GSN" "$MS" "$MD" "$MSN" <<'PY'
import re, sys, os
pack, gs, gd, gsn, ms, md, msn = sys.argv[1:8]
p = os.path.join(pack, "PROVENANCE.md")
t = open(p).read()
t = re.sub(r"(`github\.com/google/skills` \| )`[0-9a-f]+`( \| )[0-9-]+( \| )\d+",
           lambda m: f"{m.group(1)}`{gs}`{m.group(2)}{gd}{m.group(3)}{gsn}", t)
t = re.sub(r"(`github\.com/google-gemini/gemini-skills` \| )`[0-9a-f]+`( \| )[0-9-]+( \| )\d+",
           lambda m: f"{m.group(1)}`{ms}`{m.group(2)}{md}{m.group(3)}{msn}", t)
open(p, "w").write(t)
PY

echo "--- counts ---"
for d in ads analytics cloud developers gemini; do printf '%-11s %s\n' "$d" "$(find "$PACK/$d" -name SKILL.md | wc -l | tr -d ' ')"; done
printf '%-11s %s\n' TOTAL "$(find "$PACK" -name SKILL.md | wc -l | tr -d ' ')"
echo
echo "next: node scripts/audit-skills.mjs --write, review the diff, and update the lane tables in $PACK/../SKILL.md if counts or members changed."
