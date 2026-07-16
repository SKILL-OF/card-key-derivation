#!/usr/bin/env bash
# assemble-password.sh — derive full password from encrypted pattern + card
# Reads: gh-pattern.age, gh-card.age, gh-colors.age (optional, falls back to lookup/)
# Outputs: assembled password to stdout (pipe directly to login tool, never echo)

set -euo pipefail

KEY="$HOME/.aurora-agent/keys/totp-key.txt"
SECRETS="$HOME/.aurora-agent/secrets"
LOOKUP_DIR="$(dirname "$0")/../lookup"

PATTERN=$(age -d -i "$KEY" "$SECRETS/gh-pattern.age" 2>/dev/null)
CARD=$(age -d -i "$KEY" "$SECRETS/gh-card.age" 2>/dev/null)

# Use encrypted colors if available, else fall back to lookup/
if [[ -f "$SECRETS/gh-colors.age" ]]; then
  COLORS=$(age -d -i "$KEY" "$SECRETS/gh-colors.age" 2>/dev/null)
else
  COLORS=$(cat "$LOOKUP_DIR/colors.json")
fi

python3 - "$PATTERN" "$CARD" << PYEOF
import sys, json, re

pattern = sys.argv[1]  # e.g. 🟨/🔵/🟤/.299/
card    = sys.argv[2]  # e.g. P2E.1/🟨UMPIRE🔵SPINNING WHEEL...

colors_raw = """$COLORS"""
colors = json.loads(colors_raw)

# Parse card into {category: (word, has_symbol)}
prefix, payload = card.split('/', 1)
emoji_set = set(colors.keys())
card_map = {}
current_emoji = None
current_chars = []
for ch in payload:
    if ch in emoji_set:
        if current_emoji:
            info = colors[current_emoji]
            card_map[info['category']] = (''.join(current_chars).strip(), info['symbol'])
        current_emoji = ch
        current_chars = []
    else:
        current_chars.append(ch)
if current_emoji:
    info = colors[current_emoji]
    card_map[info['category']] = (''.join(current_chars).strip(), info['symbol'])

# Parse pattern tokens (emoji or literal)
tokens = [t for t in re.split(r'/', pattern) if t]
result = []
for token in tokens:
    if token in emoji_set:
        info = colors[token]
        word, has_symbol = card_map[info['category']]
        result.append(word.capitalize() if info['symbol'] else word.lower())
    else:
        result.append(token)

sys.stdout.write(''.join(result))
PYEOF

unset PATTERN CARD COLORS
