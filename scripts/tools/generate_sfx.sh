#!/usr/bin/env bash
# Generate placeholder SFX using the ElevenLabs Sound Effects API.
# Usage: bash scripts/tools/generate_sfx.sh
# Requires: curl, an ElevenLabs API key with Sound Effects access.

set -euo pipefail

AUDIO_DIR="$(cd "$(dirname "$0")/../.." && pwd)/assets/audio"
API_URL="https://api.elevenlabs.io/v1/sound-generation"

# Prompt for API key
read -rsp "ElevenLabs API key: " API_KEY
echo

mkdir -p "$AUDIO_DIR"

# name|duration|prompt
SOUNDS=(
  "hit|0.5|Short melee impact, sword hitting armor, fantasy game"
  "crit|0.5|Heavy critical strike impact, powerful slash, fantasy game"
  "miss|0.5|Quick whoosh, sword swing miss, fantasy game"
  "death|1.0|Fantasy unit death, short collapse groan"
  "ability|1.0|Magic ability activation, short arcane power-up"
  "heal|1.0|Gentle healing chime, holy magic restoration"
  "poison|1.0|Bubbling poison splash, toxic liquid effect"
  "curse|1.0|Dark curse cast, ominous magic debuff"
  "summon|1.0|Magical summoning portal, mystical appearance"
  "buy|0.5|Coin purchase, short register cha-ching"
  "sell|0.5|Coins dropping, selling item sound"
  "reroll|0.5|Dice rolling on wood table, short shuffle"
  "upgrade|0.8|Positive power-up chime, item enchant sparkle"
  "warning|0.5|Short error buzz, UI warning beep"
  "round_start|1.5|Battle horn, war drums begin, fantasy combat start"
  "victory|2.0|Triumphant fanfare, short victory jingle, fantasy game"
  "defeat|2.0|Somber defeat sound, low brass, fantasy game loss"
  "game_over|2.5|Dramatic game over, deep ominous tone fading out"
)

TOTAL=${#SOUNDS[@]}
CURRENT=0

for entry in "${SOUNDS[@]}"; do
  IFS='|' read -r name duration prompt <<< "$entry"
  CURRENT=$((CURRENT + 1))
  OUTFILE="$AUDIO_DIR/${name}.mp3"

  if [[ -f "$OUTFILE" ]]; then
    echo "[$CURRENT/$TOTAL] Skipping $name (already exists)"
    continue
  fi

  echo "[$CURRENT/$TOTAL] Generating $name ($duration s)..."

  HTTP_CODE=$(curl -s -o "$OUTFILE" -w "%{http_code}" \
    -X POST "$API_URL" \
    -H "xi-api-key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(printf '{"text":"%s","duration_seconds":%s,"prompt_influence":0.3}' "$prompt" "$duration")" \
    --query-arg "output_format=mp3_44100_128" 2>/dev/null) || true

  # --query-arg may not be available; fall back to URL param
  if [[ "$HTTP_CODE" != "200" ]]; then
    rm -f "$OUTFILE"
    HTTP_CODE=$(curl -s -o "$OUTFILE" -w "%{http_code}" \
      -X POST "${API_URL}?output_format=mp3_44100_128" \
      -H "xi-api-key: $API_KEY" \
      -H "Content-Type: application/json" \
      -d "$(printf '{"text":"%s","duration_seconds":%s,"prompt_influence":0.3}' "$prompt" "$duration")")
  fi

  if [[ "$HTTP_CODE" != "200" ]]; then
    echo "  ERROR: API returned HTTP $HTTP_CODE for $name"
    rm -f "$OUTFILE"
  else
    SIZE=$(stat --printf="%s" "$OUTFILE" 2>/dev/null || stat -f%z "$OUTFILE" 2>/dev/null || echo "?")
    echo "  Saved $OUTFILE ($SIZE bytes)"
  fi

  # Brief pause to avoid rate limits
  sleep 1
done

echo ""
echo "Done. Generated files in $AUDIO_DIR:"
ls -lh "$AUDIO_DIR"/*.mp3 2>/dev/null || echo "(no files found)"
