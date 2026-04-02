#!/bin/bash
# Test that GHL Toolkit is installed and credentials work
# Run: bash test.sh

HOME_DIR="$HOME"
PROJECT_DIR="$HOME_DIR/.claude/projects/-Users-$(whoami)"
SECRETS="$PROJECT_DIR/secrets/ghl.env"
GHL_SCRIPT="$PROJECT_DIR/scripts/ghl"

echo ""
echo "=== GHL Toolkit Health Check ==="
echo ""

PASS=0
FAIL=0

# Check skills installed
if [ -f "$HOME_DIR/.claude/skills/ghl-crm/SKILL.md" ]; then
  echo "[pass] ghl-crm skill installed"
  PASS=$((PASS+1))
else
  echo "[FAIL] ghl-crm skill not found"
  FAIL=$((FAIL+1))
fi

if [ -f "$HOME_DIR/.claude/skills/ghl-browser/SKILL.md" ]; then
  echo "[pass] ghl-browser skill installed"
  PASS=$((PASS+1))
else
  echo "[FAIL] ghl-browser skill not found"
  FAIL=$((FAIL+1))
fi

# Check script installed
if [ -x "$GHL_SCRIPT" ]; then
  echo "[pass] ghl bash helper installed and executable"
  PASS=$((PASS+1))
else
  echo "[FAIL] ghl bash helper not found or not executable"
  FAIL=$((FAIL+1))
fi

# Check secrets file exists
if [ -f "$SECRETS" ]; then
  echo "[pass] ghl.env exists"
  PASS=$((PASS+1))
else
  echo "[FAIL] ghl.env not found at $SECRETS"
  echo "       Run: cp secrets/ghl.env.template $SECRETS"
  FAIL=$((FAIL+1))
fi

# Check credentials are filled in (not still placeholders)
if [ -f "$SECRETS" ]; then
  source "$SECRETS"

  if [ "$GHL_API_KEY" = "your_api_key_here" ] || [ -z "$GHL_API_KEY" ]; then
    echo "[FAIL] GHL_API_KEY not set in ghl.env"
    FAIL=$((FAIL+1))
  else
    echo "[pass] GHL_API_KEY is set"
    PASS=$((PASS+1))
  fi

  if [ "$GHL_LOCATION_ID" = "your_location_id_here" ] || [ -z "$GHL_LOCATION_ID" ]; then
    echo "[FAIL] GHL_LOCATION_ID not set in ghl.env"
    FAIL=$((FAIL+1))
  else
    echo "[pass] GHL_LOCATION_ID is set"
    PASS=$((PASS+1))
  fi

  # Test API connectivity
  if [ "$GHL_API_KEY" != "your_api_key_here" ] && [ -n "$GHL_API_KEY" ] && [ -n "$GHL_LOCATION_ID" ] && [ "$GHL_LOCATION_ID" != "your_location_id_here" ]; then
    echo ""
    echo "Testing API connection..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
      "$GHL_BASE_URL/contacts/?locationId=$GHL_LOCATION_ID&limit=1" \
      -H "Authorization: Bearer $GHL_API_KEY" \
      -H "Version: $GHL_API_VERSION" 2>/dev/null)

    if [ "$RESPONSE" = "200" ]; then
      echo "[pass] API connection successful (HTTP 200)"
      PASS=$((PASS+1))
    elif [ "$RESPONSE" = "401" ]; then
      echo "[FAIL] API returned 401 - check your GHL_API_KEY"
      FAIL=$((FAIL+1))
    elif [ "$RESPONSE" = "422" ]; then
      echo "[FAIL] API returned 422 - check your GHL_LOCATION_ID"
      FAIL=$((FAIL+1))
    elif [ "$RESPONSE" = "000" ]; then
      echo "[FAIL] Could not connect - check your internet connection"
      FAIL=$((FAIL+1))
    else
      echo "[FAIL] API returned HTTP $RESPONSE"
      FAIL=$((FAIL+1))
    fi
  fi
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ $FAIL -eq 0 ]; then
  echo ""
  echo "All good! Open Claude Code and try:"
  echo "  'Show me my GHL pipelines'"
  echo "  'Search contacts for John'"
  echo ""
else
  echo ""
  echo "Fix the issues above, then run this test again."
  echo ""
fi
