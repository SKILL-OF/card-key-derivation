#!/usr/bin/env bash
# assemble-password.sh — derive password from encrypted pattern + card
#
# Usage: assemble-password.sh [CARD_VAULT_NAME]
#   CARD_VAULT_NAME: filename (no path) in VAULT_DIR  (overrides auto-resolve)
#
# Pattern format:  [CARDID/]TOKEN/TOKEN/...
#   CARDID prefix (e.g. P2E.299) resolves to VAULT_DIR/CARDS_SUBDIR/P2E.299.age
#   emoji token   -> look up word from card by category, capitalize if square emoji (has symbol)
#   #             -> card number extracted from CARDID prefix (e.g. P2E.299 -> 299)
#   anything else -> append as literal (e.g. .299, !, 42)
#
# Arbitrary order and repetition supported:
#   P2E.299/🟨/🔵/🟨/🟫/   — P-word, O-word, P-word again, A-word
#   P2E.299/🟫/#            — A-word + card number
#
# Environment:
#   AGE_KEY        path to age private key (default: ~/.aurora-agent/keys/totp-key.txt)
#   VAULT_DIR      path to vault directory  (default: ~/.aurora-agent/secrets)
#   PATTERN_VAULT  filename in VAULT_DIR for the pattern (default: gh-pattern.age)
#   CARDS_SUBDIR   subdirectory in VAULT_DIR for multi-card storage (default: cards)

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
AGE_KEY="${AGE_KEY:-$HOME/.aurora-agent/keys/totp-key.txt}"
VAULT_DIR="${VAULT_DIR:-$HOME/.aurora-agent/secrets}"
PATTERN_VAULT="${PATTERN_VAULT:-gh-pattern.age}"
CARDS_SUBDIR="${CARDS_SUBDIR:-cards}"
LOOKUP_DIR="$SCRIPT_DIR/../lookup"

PATTERN=$(age -d -i "$AGE_KEY" "$VAULT_DIR/$PATTERN_VAULT" 2>/dev/null)

# Extract card ID from pattern prefix (e.g. "P2E.299/🟨/..." -> "P2E.299")
CARD_ID=""
if [[ "$PATTERN" =~ ^([^/]+\.[^/]+)/ ]]; then
  CARD_ID="${BASH_REMATCH[1]}"
fi

# Resolve card vault: explicit arg > cards/CARDID.age > gh-card.age
if [[ -n "${1:-}" ]]; then
  CARD_VAULT="$VAULT_DIR/$1"
elif [[ -n "$CARD_ID" ]] && [[ -f "$VAULT_DIR/$CARDS_SUBDIR/$CARD_ID.age" ]]; then
  CARD_VAULT="$VAULT_DIR/$CARDS_SUBDIR/$CARD_ID.age"
else
  CARD_VAULT="$VAULT_DIR/gh-card.age"
fi

CARD=$(age -d -i "$AGE_KEY" "$CARD_VAULT" 2>/dev/null)

# Use encrypted colors if available, else fall back to lookup/
if [[ -f "$VAULT_DIR/gh-colors.age" ]]; then
  COLORS=$(age -d -i "$AGE_KEY" "$VAULT_DIR/gh-colors.age" 2>/dev/null)
else
  COLORS=$(cat "$LOOKUP_DIR/colors.json")
fi

echo "$PATTERN"$'\n'"$CARD" | python3 -c "
import sys, json, re

lines = sys.stdin.read().split('\n', 1)
raw_pattern = lines[0].strip()
card        = lines[1].strip()

# Strip optional card-ID prefix from pattern (e.g. 'P2E.299/🟨/...' -> '🟨/...')
card_num = ''
if re.match(r'^[^/]+\.[^/]+/', raw_pattern):
    card_id = raw_pattern.split('/', 1)[0]
    raw_pattern = raw_pattern.split('/', 1)[1]
    m = re.search(r'\.(\w+)$', card_id)
    if m:
        card_num = m.group(1)

pattern = raw_pattern.strip('/')
colors = json.loads('''$COLORS''')
emoji_set = set(colors.keys())

# Parse card into {category: (word, has_symbol)}
card_map = {}
if '/' in card:
    payload = card.split('/', 1)[1]
    current_emoji = None
    current_chars = []
    for ch in payload:
        if ch in emoji_set:
            if current_emoji:
                info = colors[current_emoji]
                card_map[info['category']] = (
                    ''.join(current_chars).strip(), info['symbol'])
            current_emoji = ch
            current_chars = []
        else:
            current_chars.append(ch)
    if current_emoji:
        info = colors[current_emoji]
        card_map[info['category']] = (
            ''.join(current_chars).strip(), info['symbol'])

# Assemble: iterate pattern tokens, repeated references supported
tokens = [t for t in pattern.split('/') if t]
result = []
for token in tokens:
    if token == '#':
        result.append(card_num)
    elif token in emoji_set:
        info = colors[token]
        word, _ = card_map[info['category']]
        result.append(word.capitalize() if info['symbol'] else word.lower())
    else:
        result.append(token)

sys.stdout.write(''.join(result))
"

unset PATTERN CARD COLORS CARD_VAULT CARD_ID
