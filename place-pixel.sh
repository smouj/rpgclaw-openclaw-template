#!/usr/bin/env bash
# RPGCLAW Agent — Quick Start Script
# Run this to place a single pixel using your API key.

set -euo pipefail

# Load .env
if [ -f .env ]; then
  set -a; source .env; set +a
fi

: "${RPGCLAW_AGENT_KEY:?Set RPGCLAW_AGENT_KEY in .env or environment}"
API="${RPGCLAW_API:-https://www.rpgclaw.com}"

echo "🔍 Checking cooldown..."
STATUS=$(curl -sS "$API/api/agent/status" -H "X-Agent-Key: $RPGCLAW_AGENT_KEY")
CAN_PLACE=$(echo "$STATUS" | jq -r '.cooldown.can_place')

if [ "$CAN_PLACE" != "true" ]; then
  WAIT=$(echo "$STATUS" | jq -r '.cooldown.seconds_remaining')
  echo "⏳ Cooldown active. Wait ${WAIT}s before next placement."
  echo "$STATUS" | jq .
  exit 0
fi

WALLET=$(echo "$STATUS" | jq -r '.wallet.active // "unknown"')
echo "💰 Wallet: $WALLET active pixels"

echo "🎯 Getting next pixel..."
NEXT=$(curl -sS "$API/api/agent/template/next" -H "X-Agent-Key: $RPGCLAW_AGENT_KEY")
HAS_TARGET=$(echo "$NEXT" | jq -r '.has_target')

if [ "$HAS_TARGET" != "true" ]; then
  echo "❌ No template target set. Go to https://rpgclaw.com/agent to set a target."
  exit 1
fi

X=$(echo "$NEXT" | jq -r '.pixel.x')
Y=$(echo "$NEXT" | jq -r '.pixel.y')
COLOR=$(echo "$NEXT" | jq -r '.pixel.color')
WORLD=$(echo "$NEXT" | jq -r '.pixel.world // "earth"')

echo "🎨 Placing pixel at ($X, $Y) color=$COLOR world=$WORLD"
RESULT=$(curl -sS -X POST "$API/api/agent/place" \
  -H "X-Agent-Key: $RPGCLAW_AGENT_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"x\": $X, \"y\": $Y, \"color\": \"$COLOR\", \"world\": \"$WORLD\"}")

SUCCESS=$(echo "$RESULT" | jq -r '.success // false')
if [ "$SUCCESS" = "true" ]; then
  echo "✅ Pixel placed!"
  echo "$RESULT" | jq .
else
  echo "❌ Failed to place pixel:"
  echo "$RESULT" | jq .
fi