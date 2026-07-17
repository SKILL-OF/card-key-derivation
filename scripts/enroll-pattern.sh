#!/usr/bin/env bash
# enroll-pattern.sh — accept letter or emoji pattern, translate to emoji, encrypt
# Supports arbitrary order, any subset of categories, repeated references
# Letter case = capitalization: uppercase -> square emoji (▶ present), lowercase -> circle
#
# Examples:
#   P2E.299/P/o/A/       -> P2E.299/🟨/🔵/🟫/
#   P2E.299/A/O/AP/#/    -> P2E.299/🟫/🟦/🟥/299/    (# expands to card number)
#   P2E.299/P/D/A/P/P    -> P2E.299/🟨/🟩/🟫/🟨/🟨
#   P2E.299/🟨/🔵/🟤/   -> pass-through unchanged (emoji already)
#
# NOTE: Do not use .NNN literals when a card ID prefix is present.
#   The card number is already encoded in the prefix — use # to reference it.
#   P2E.299/A/o/#        is correct (card number at end)
#   P2E.299/A/o/.299     is undefined (which card number does .299 belong to?)
#
# Pattern format:
#   Optional CARDID prefix (must contain a dot) is preserved unchanged.
#   Remaining tokens are translated: uppercase letter -> square emoji, lowercase -> circle.
#   Unknown tokens (literals like .001 or #) are preserved as-is.
#
# Environment:
#   AGE_KEY        path to age private key (default: ~/.aurora-agent/keys/totp-key.txt)
#   VAULT_DIR      path to vault directory  (default: ~/.aurora-agent/secrets)
#   PATTERN_VAULT  filename in VAULT_DIR to store the pattern (default: gh-pattern.age)

set -euo pipefail

AGE_KEY="${AGE_KEY:-$HOME/.aurora-agent/keys/totp-key.txt}"
VAULT_DIR="${VAULT_DIR:-$HOME/.aurora-agent/secrets}"
PATTERN_VAULT="${PATTERN_VAULT:-gh-pattern.age}"

echo "Paste pattern then press Enter:" >&2
read -r PATTERN

TRANSLATED=$(echo "$PATTERN" | python3 -c "
import sys, re

letter_map = {
    'P':  '🟨', 'p':  '🟡',
    'O':  '🟦', 'o':  '🔵',
    'A':  '🟫', 'a':  '🟤',
    'D':  '🟩', 'd':  '🟢',
    'AP': '🟥', 'ap': '🔴',
}

raw = sys.stdin.read().strip().strip('/')
tokens = [t for t in raw.split('/') if t]

# Check if first token looks like a card ID (contains a dot, no emoji)
result = []
start = 0
emojis = set('🟡🟨🔵🟦🟤🟫🟢🟩🔴🟥')
if tokens and '.' in tokens[0] and not any(c in emojis for c in tokens[0]):
    result.append(tokens[0])  # preserve card ID prefix unchanged
    start = 1

for t in tokens[start:]:
    result.append(letter_map.get(t, t))

print('/' + '/'.join(result) + '/')
")

PUBKEY=$(age-keygen -y "$AGE_KEY")
printf '%s' "$TRANSLATED" | age -r "$PUBKEY" > "$VAULT_DIR/$PATTERN_VAULT"
chmod 0600 "$VAULT_DIR/$PATTERN_VAULT"
echo "Stored as: $TRANSLATED" >&2
unset TRANSLATED PUBKEY
