#!/usr/bin/env bash
# enroll-pattern.sh — translate a pattern into canonical emoji form and encrypt
#
# The pattern stored is: DECK_CODE/TOKEN/TOKEN/...
#   DECK_CODE  identifies which deck's category mapping applies (e.g. P2E)
#              this is the FK to Deck, NOT the full card shortcode
#   TOKEN      emoji (canonical) or literal; no card number here
#
# The card FK (which specific card) lives in the account .env as CARD_ID.
# The pattern does not embed a card number — patterns are reusable across
# cards of the same deck type.
#
# Input formats accepted (all equivalent):
#   P2E/P/o/A/         deck prefix + letter codes
#   P/o/A              no deck prefix (DECK_CODE env var used, or prompted)
#   P2E/🟨/🔵/🟫/     deck prefix + emoji (pass-through)
#   🟨/🔵/🟫/         emoji only, no deck prefix
#
# Letter codes:
#   Uppercase = square emoji (symbol/▶ present) = word will be ALL CAPS
#   Lowercase = circle emoji (no symbol)        = word will be lowercase
#   P/p  O/o  A/a  D/d  AP/ap
#
# WARNING: if you type a card shortcode (e.g. P2E.1) as the prefix,
# the card number will be stripped and a warning shown. The card number
# belongs in CARD_ID in your account .env, not in the pattern.
#
# Environment:
#   AGE_KEY       path to age private key (default: ~/.aurora-agent/keys/totp-key.txt)
#   VAULT_DIR     path to vault directory  (default: ~/.aurora-agent/secrets)
#   PATTERN_VAULT filename in VAULT_DIR to store the pattern (default: gh-pattern.age)
#   DECK_CODE     deck code if not embedded in input (e.g. P2E)

set -euo pipefail

AGE_KEY="${AGE_KEY:-$HOME/.aurora-agent/keys/totp-key.txt}"
VAULT_DIR="${VAULT_DIR:-$HOME/.aurora-agent/secrets}"
PATTERN_VAULT="${PATTERN_VAULT:-gh-pattern.age}"

DECK_CODE="${DECK_CODE:-}"

echo "Paste pattern then press Enter:" >&2
read -r RAW_PATTERN

TRANSLATED=$(echo "$RAW_PATTERN" | python3 -c "
import sys, re

letter_map = {
    'P':  '🟨', 'p':  '🟡',
    'O':  '🟦', 'o':  '🔵',
    'A':  '🟫', 'a':  '🟤',
    'D':  '🟩', 'd':  '🟢',
    'AP': '🟥', 'ap': '🔴',
}
emojis = set('🟡🟨🔵🟦🟤🟫🟢🟩🔴🟥')

env_deck = '$DECK_CODE' if '$DECK_CODE' else ''

raw = sys.stdin.read().strip().strip('/')
tokens = [t for t in raw.split('/') if t]

deck_code = env_deck
start = 0

if tokens:
    first = tokens[0]
    if any(c in emojis for c in first) or first in letter_map:
        # First token is a category token — no prefix in input
        deck_code = deck_code or ''
    elif '.' in first:
        # Old card shortcode format (e.g. P2E.1) — strip card num, warn
        parts = first.rsplit('.', 1)
        deck_code = deck_code or parts[0]
        print(f'WARNING: card number stripped from pattern prefix', file=__import__('sys').stderr)
        print(f'  got: {first}  ->  using deck: {deck_code}', file=__import__('sys').stderr)
        print(f'  put card number in CARD_ID in your account .env instead', file=__import__('sys').stderr)
        start = 1
    else:
        # Bare deck code (e.g. P2E)
        deck_code = deck_code or first
        start = 1

result = []
if deck_code:
    result.append(deck_code)

for t in tokens[start:]:
    result.append(letter_map.get(t, t))

print('/' + '/'.join(result) + '/')
") || exit 1

PUBKEY=$(age-keygen -y "$AGE_KEY")
printf '%s' "$TRANSLATED" | age -r "$PUBKEY" > "$VAULT_DIR/$PATTERN_VAULT"
chmod 0600 "$VAULT_DIR/$PATTERN_VAULT"
echo "Stored as: $TRANSLATED" >&2
unset TRANSLATED PUBKEY RAW_PATTERN
