#!/usr/bin/env bash
# enroll-card.sh — store a card in the vault from flexible human input
# Accepts any of:
#   P2E.299/>word1/word2/>word3/word4/word5
#   P2E.299/>word1,word2,>word3,word4,word5
#   P2E.299/🟨UMPIRE🔵SPINNING WHEEL🟤DINE🟩MISMATCH🔴TRACK  (pass-through)
#   Multiline: prefix on first line, one word per subsequent line
# Symbol prefix: > or ▶ means ▶ present (square emoji); no prefix = circle emoji

set -euo pipefail

KEY="$HOME/.aurora-agent/keys/totp-key.txt"
VAULT="$HOME/.aurora-agent/secrets/gh-card.age"
LOOKUP_DIR="$(dirname "$0")/../lookup"
CATEGORY_ORDER=("P" "O" "A" "D" "AP")

# Emoji map: category+symbol -> emoji
declare -A EMOJI
EMOJI[P:0]="🟡"; EMOJI[P:1]="🟨"
EMOJI[O:0]="🔵"; EMOJI[O:1]="🟦"
EMOJI[A:0]="🟤"; EMOJI[A:1]="🟫"
EMOJI[D:0]="🟢"; EMOJI[D:1]="🟩"
EMOJI[AP:0]="🔴"; EMOJI[AP:1]="🟥"

echo "Paste card line (P2E.NNN/>word1/word2/...) then press Enter:" >&2
read -r INPUT

# Split prefix from payload on first /
PREFIX="${INPUT%%/*}"
PAYLOAD="${INPUT#*/}"

# If payload contains any of our emoji, pass through as-is
if echo "$PAYLOAD" | grep -qP '[\x{1F7E0}-\x{1F7EB}\x{1F534}\x{1F535}\x{1F7E2}\x{1F7E3}\x{1F7E4}]' 2>/dev/null \
   || python3 -c "
import sys
emojis = set('🟡🟨🔵🟦🟤🟫🟢🟩🔴🟥')
sys.exit(0 if any(c in emojis for c in sys.argv[1]) else 1)
" "$PAYLOAD" 2>/dev/null; then
  CANONICAL="$PREFIX/$PAYLOAD"
else
  # Tokenize: split on / , or newline, strip whitespace
  TOKENS=$(echo "$PAYLOAD" | python3 -c "
import sys, re
raw = sys.stdin.read().strip()
tokens = [t.strip() for t in re.split(r'[/,\n]+', raw) if t.strip()]
print('\n'.join(tokens))
")

  CANONICAL="$PREFIX/"
  IDX=0
  while IFS= read -r TOKEN && [ $IDX -lt 5 ]; do
    CAT="${CATEGORY_ORDER[$IDX]}"
    if [[ "$TOKEN" == ">"* ]] || [[ "$TOKEN" == "▶"* ]]; then
      SYM=1
      WORD="${TOKEN#>}"; WORD="${WORD#▶}"; WORD="${WORD# }"
    else
      SYM=0
      WORD="$TOKEN"
    fi
    CANONICAL+="${EMOJI[$CAT:$SYM]}${WORD}"
    IDX=$(( IDX + 1 ))
  done <<< "$TOKENS"
fi

# Encrypt and store
PUBKEY=$(age-keygen -y "$KEY")
printf '%s' "$CANONICAL" | age -r "$PUBKEY" > "$VAULT"
chmod 0600 "$VAULT"
echo "Card enrolled." >&2
unset CANONICAL PUBKEY
