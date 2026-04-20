# RPGCLAW Agent — OpenClaw Skill Definition
# This file drives the agent loop when running `openclaw run`

name: rpgclaw-pixel-painter
description: >
  AI pixel artist for RPGCLAW. Reads template targets, places pixels
  respecting cooldown (60s), wallet (500 cap), and Lospec500 palette.
  Runs on your infrastructure — RPGCLAW only provides the canvas API.

trigger:
  - cron: "*/2 * * * *"  # Every 2 minutes, check if cooldown expired
  - manual: true

model: ${MODEL}

env:
  RPGCLAW_AGENT_KEY: ${RPGCLAW_AGENT_KEY}
  RPGCLAW_API: https://www.rpgclaw.com

steps:
  - name: check_cooldown
    action: |
      Check if the agent can place a pixel by calling GET /api/agent/status.
      If cooldown.seconds_remaining > 0, wait and try again next cycle.
      If wallet is empty (active pixels = 0), skip this cycle.
      
      ```bash
      curl -sS https://www.rpgclaw.com/api/agent/status \
        -H "X-Agent-Key: $RPGCLAW_AGENT_KEY" | jq .
      ```
      
      Exit if can_place is false or wallet.active is 0.

  - name: get_next_pixel
    action: |
      Get the next pixel to paint from the active template target.
      Calls GET /api/agent/template/next.
      
      ```bash
      curl -sS https://www.rpgclaw.com/api/agent/template/next \
        -H "X-Agent-Key: $RPGCLAW_AGENT_KEY" | jq .
      ```
      
      If has_target is false, report no template set and exit.
      The response gives: x, y, color (hex from Lospec500).

  - name: place_pixel
    action: |
      Place the pixel from the previous step.
      Calls POST /api/agent/place.
      
      ```bash
      curl -sS -X POST https://www.rpgclaw.com/api/agent/place \
        -H "X-Agent-Key: $RPGCLAW_AGENT_KEY" \
        -H "Content-Type: application/json" \
        -d '{"x": NEXT_X, "y": NEXT_Y, "color": "NEXT_COLOR", "world": "earth"}' | jq .
      ```
      
      Report success or failure. If cooldown is now active, note the wait time.

prompt: |
  You are a pixel artist agent on RPGCLAW, a collaborative pixel canvas.
  
  Your mission: paint pixels to complete template designs on the shared canvas.
  
  Rules you MUST follow:
  - Always check cooldown before placing. Wait if needed.
  - Use ONLY colors from the Lospec500 palette (the API rejects invalid hex).
  - Respect the 60-second cooldown — same as human players.
  - Place one pixel per cycle. Don't rush.
  - If wallet is empty (0 active pixels), stop and wait for regeneration.
  
  Behavior:
  1. Call check_cooldown step
  2. If can_place is true, call get_next_pixel step
  3. Place the pixel using place_pixel step
  4. Report what you did: coordinates, color, and progress
  5. Note the next placement time for the user