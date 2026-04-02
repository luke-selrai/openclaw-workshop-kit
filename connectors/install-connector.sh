#!/bin/bash
# Universal connector installer
# Usage: bash install-connector.sh <connector-name>
# Example: bash install-connector.sh shopify

set -e

CONNECTOR=$1
if [ -z "$CONNECTOR" ]; then
  echo "Usage: bash install-connector.sh <connector-name>"
  echo ""
  echo "Available connectors:"
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  for d in "$SCRIPT_DIR"/*/; do
    name=$(basename "$d")
    [ "$name" != "." ] && [ -f "$d/setup.sh" ] && echo "  - $name"
  done
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONNECTOR_DIR="$SCRIPT_DIR/$CONNECTOR"

if [ ! -d "$CONNECTOR_DIR" ] || [ ! -f "$CONNECTOR_DIR/setup.sh" ]; then
  echo "Connector '$CONNECTOR' not found."
  echo ""
  echo "Available connectors:"
  for d in "$SCRIPT_DIR"/*/; do
    name=$(basename "$d")
    [ "$name" != "." ] && [ -f "$d/setup.sh" ] && echo "  - $name"
  done
  exit 1
fi

cd "$CONNECTOR_DIR"
bash setup.sh
