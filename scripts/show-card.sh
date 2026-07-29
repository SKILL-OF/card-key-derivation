#!/usr/bin/env bash
# show-card.sh — decrypt a card vault and render as markdown table
#
# Usage: show-card.sh <CARD_ID>
#   CARD_ID  card identifier, e.g. P2E.1 or P2E.299
#            resolves to VAULT_DIR/CARDS_SUBDIR/CARD_ID.age
#            falls back to VAULT_DIR/gh-card.age if that file doesn't exist
#
# Environment (all optional, override defaults):
#   AGE_KEY      — path to age private key
#                  default: ~/.aurora-agent/keys/totp-key.txt
#   VAULT_DIR    — path to vault directory
#                  default: ~/.aurora-agent/secrets
#   CARDS_SUBDIR — subdirectory within VAULT_DIR for per-card files
#                  default: cards
#
# Examples:
#   show-card.sh P2E.1
#   show-card.sh P2E.299
#   VAULT_DIR=/mnt/other/secrets show-card.sh P2E.1

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
AGE_KEY="${AGE_KEY:-$HOME/.aurora-agent/keys/totp-key.txt}"
VAULT_DIR="${VAULT_DIR:-$HOME/.aurora-agent/secrets}"
CARDS_SUBDIR="${CARDS_SUBDIR:-cards}"
LOOKUP_DIR="$SCRIPT_DIR/../lookup"

usage() {
  grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && usage 0

CARD_ID="${1:-${CARD_ID:-}}"

if [[ -z "$CARD_ID" ]]; then
  echo "error: no card ID specified" >&2
  echo "" >&2
  echo "usage: show-card.sh <CARD_ID>   (e.g. P2E.1, P2E.299)" >&2
  echo "       or set CARD_ID in your account .env" >&2
  echo "" >&2
  echo "available cards:" >&2
  if ls "$VAULT_DIR/$CARDS_SUBDIR/"*.age 2>/dev/null | grep -q .; then
    ls "$VAULT_DIR/$CARDS_SUBDIR/"*.age | xargs -n1 basename | sed 's/\.age$//' | sed 's/^/  /' >&2
  else
    echo "  (none in $VAULT_DIR/$CARDS_SUBDIR/)" >&2
    [[ -f "$VAULT_DIR/gh-card.age" ]] && echo "  gh-card.age  (legacy flat location — re-enroll to assign an ID)" >&2
  fi
  exit 1
fi

# Resolve vault path
if [[ -f "$VAULT_DIR/$CARDS_SUBDIR/$CARD_ID.age" ]]; then
  CARD_VAULT="$VAULT_DIR/$CARDS_SUBDIR/$CARD_ID.age"
elif [[ -f "$VAULT_DIR/gh-card.age" ]]; then
  echo "note: $VAULT_DIR/$CARDS_SUBDIR/$CARD_ID.age not found; falling back to gh-card.age" >&2
  CARD_VAULT="$VAULT_DIR/gh-card.age"
else
  echo "error: no vault found for card '$CARD_ID'" >&2
  echo "  looked for: $VAULT_DIR/$CARDS_SUBDIR/$CARD_ID.age" >&2
  echo "  fallback:   $VAULT_DIR/gh-card.age (also missing)" >&2
  exit 1
fi

CARD=$(age -d -i "$AGE_KEY" "$CARD_VAULT" 2>/dev/null) || {
  echo "error: failed to decrypt $CARD_VAULT" >&2
  exit 1
}

echo "$CARD" | python3 -c "
import sys, json, os

lookup_dir = '$LOOKUP_DIR'
line = sys.stdin.read().strip()

if not line:
    print('error: decrypted card is empty', file=sys.stderr)
    sys.exit(1)

with open(os.path.join(lookup_dir, 'colors.json')) as f:
    colors = json.load(f)

editions = {}
editions_path = os.path.join(lookup_dir, 'editions.json')
if os.path.exists(editions_path):
    with open(editions_path) as f:
        editions = json.load(f)

if '/' not in line:
    print(f'error: card data has unexpected format (no / separator)', file=sys.stderr)
    sys.exit(1)

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
