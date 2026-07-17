#!/usr/bin/env bash
# show-card.sh — decrypt card vault and render as markdown table
# Usage: show-card.sh [CARD_VAULT_NAME]
#   CARD_VAULT_NAME: filename (no path) in VAULT_DIR/CARDS_SUBDIR/
#                    default: resolved from PATTERN_VAULT prefix, or gh-card.age
#
# Environment:
#   AGE_KEY        path to age private key (default: ~/.aurora-agent/keys/totp-key.txt)
#   VAULT_DIR      path to vault directory  (default: ~/.aurora-agent/secrets)
#   PATTERN_VAULT  filename in VAULT_DIR to read card ID prefix from (default: gh-pattern.age)
#   CARDS_SUBDIR   subdirectory for multi-card storage (default: cards)

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
AGE_KEY="${AGE_KEY:-$HOME/.aurora-agent/keys/totp-key.txt}"
VAULT_DIR="${VAULT_DIR:-$HOME/.aurora-agent/secrets}"
PATTERN_VAULT="${PATTERN_VAULT:-gh-pattern.age}"
CARDS_SUBDIR="${CARDS_SUBDIR:-cards}"
LOOKUP_DIR="$SCRIPT_DIR/../lookup"

# Resolve card vault (same logic as assemble-password.sh)
if [[ -n "${1:-}" ]]; then
  CARD_VAULT="$VAULT_DIR/$1"
else
  PATTERN=$(age -d -i "$AGE_KEY" "$VAULT_DIR/$PATTERN_VAULT" 2>/dev/null || echo "")
  CARD_ID=""
  if [[ "$PATTERN" =~ ^([^/]+\.[^/]+)/ ]]; then
    CARD_ID="${BASH_REMATCH[1]}"
  fi
  if [[ -n "$CARD_ID" ]] && [[ -f "$VAULT_DIR/$CARDS_SUBDIR/$CARD_ID.age" ]]; then
    CARD_VAULT="$VAULT_DIR/$CARDS_SUBDIR/$CARD_ID.age"
  else
    CARD_VAULT="$VAULT_DIR/gh-card.age"
  fi
  unset PATTERN CARD_ID
fi

# Read card into variable to avoid pipe-vs-heredoc stdin conflict
CARD=$(age -d -i "$AGE_KEY" "$CARD_VAULT" 2>/dev/null)

echo "$CARD" | python3 -c "
import sys, json, os

lookup_dir = '$LOOKUP_DIR'
line = sys.stdin.read().strip()

with open(os.path.join(lookup_dir, 'colors.json')) as f:
    colors = json.load(f)

editions = {}
editions_path = os.path.join(lookup_dir, 'editions.json')
if os.path.exists(editions_path):
    with open(editions_path) as f:
        editions = json.load(f)

prefix, payload = line.split('/', 1)
dot_idx = prefix.rfind('.')
edition_code = prefix[:dot_idx] if dot_idx >= 0 else prefix
card_num     = prefix[dot_idx+1:] if dot_idx >= 0 else ''
title = editions.get(edition_code, edition_code)

emoji_set = set(colors.keys())
entries = []
current_emoji = None
current_chars = []

for ch in payload:
    if ch in emoji_set:
        if current_emoji is not None:
            entries.append((current_emoji, ''.join(current_chars).strip()))
        current_emoji = ch
        current_chars = []
    else:
        current_chars.append(ch)
if current_emoji is not None:
    entries.append((current_emoji, ''.join(current_chars).strip()))

print(f'**{title}**')
print()
print('| | | |')
print('|:--|:--|--:|')
for emoji, word in entries:
    info = colors[emoji]
    cat = info['category']
    cell = f'> {word}' if info['symbol'] else word
    print(f'| **{cat}** | {cell} | |')
print(f'| | | **{card_num}** |')
"

unset CARD CARD_VAULT
