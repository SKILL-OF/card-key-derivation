#!/usr/bin/env bash
# enroll-card.sh — store a card in vault keyed by card ID (e.g. P2E.299)
# Accepts any of:
#   P2E.299/>word1/word2/>word3/word4/word5
#   P2E.299/>word1,word2,>word3,word4,word5
#   P2E.299/🟨UMPIRE🔵SPINNING WHEEL🟤DINE🟩MISMATCH🔴TRACK  (pass-through)
#   Multiline: prefix on first line, one word per subsequent line
# Symbol prefix: > or ▶ means ▶ present (square emoji); no prefix = circle emoji
#
# Card ID (prefix before first /) must contain a dot (e.g. P2E.299, MTG.001, BC.42).
# Works with any physical card: game cards, playing cards, business cards, etc.
#
# Environment:
#   AGE_KEY      path to age private key (default: ~/.aurora-agent/keys/totp-key.txt)
#   VAULT_DIR    path to vault directory  (default: ~/.aurora-agent/secrets)
#   CARDS_SUBDIR subdirectory for multi-card storage (default: cards)

set -euo pipefail

AGE_KEY="${AGE_KEY:-$HOME/.aurora-agent/keys/totp-key.txt}"
VAULT_DIR="${VAULT_DIR:-$HOME/.aurora-agent/secrets}"
CARDS_SUBDIR="${CARDS_SUBDIR:-cards}"
CATEGORY_ORDER=("P" "O" "A" "D" "AP")

declare -A EMOJI
EMOJI[P:0]="🟡"; EMOJI[P:1]="🟨"
EMOJI[O:0]="🔵"; EMOJI[O:1]="🟦"
EMOJI[A:0]="🟤"; EMOJI[A:1]="🟫"
EMOJI[D:0]="🟢"; EMOJI[D:1]="🟩"
EMOJI[AP:0]="🔴"; EMOJI[AP:1]="🟥"

echo "Paste card line (e.g. P2E.299/>word/word/>word/word/word) then press Enter:" >&2
read -r INPUT

PREFIX="${INPUT%%/*}"
PAYLOAD="${INPUT#*/}"

if [[ ! "$PREFIX" =~ \. ]]; then
  echo "ERROR: prefix must include card ID with a dot, e.g. P2E.299 or MTG.001" >&2
  exit 1
fi

CARD_ID="$PREFIX"
mkdir -p "$VAULT_DIR/$CARDS_SUBDIR"
VAULT="$VAULT_DIR/$CARDS_SUBDIR/${CARD_ID}.age"

if python3 -c "
import sys
emojis = set('🟡🟨🔵🟦🟤🟫🟢🟩🔴🟥')
sys.exit(0 if any(c in emojis for c in sys.argv[1]) else 1)
" "$PAYLOAD" 2>/dev/null; then
  CANONICAL="$CARD_ID/$PAYLOAD"
else
  TOKENS=$(echo "$PAYLOAD" | python3 -c "
import sys, re
raw = sys.stdin.read().strip()
tokens = [t.strip() for t in re.split(r'[/,\n]+', raw) if t.strip()]
print('\n'.join(tokens))
")
  CANONICAL="$CARD_ID/"
  IDX=0
  while IFS= read -r TOKEN && [ $IDX -lt 5 ]; do
    CAT="${CATEGORY_ORDER[$IDX]}"
    if [[ "$TOKEN" == ">"* ]] || [[ "$TOKEN" == "▶"* ]]; then
      SYM=1; WORD="${TOKEN#>}"; WORD="${WORD#▶}"; WORD="${WORD# }"
    else
      SYM=0; WORD="$TOKEN"
    fi
    CANONICAL+="${EMOJI[$CAT:$SYM]}${WORD}"
    IDX=$(( IDX + 1 ))
  done <<< "$TOKENS"
fi

PUBKEY=$(age-keygen -y "$AGE_KEY")
printf '%s' "$CANONICAL" | age -r "$PUBKEY" > "$VAULT"
chmod 0600 "$VAULT"
echo "Card enrolled: $VAULT" >&2
unset CANONICAL PUBKEY
