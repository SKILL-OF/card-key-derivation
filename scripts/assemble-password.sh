#!/usr/bin/env bash
# assemble-password.sh — derive password from encrypted pattern + card
#
# Usage: assemble-password.sh [--env FILE] [--card CARD_ID]
#
#   --env FILE     load account context from FILE (default: .env in CWD if present)
#   --card CARD_ID override the card to use (e.g. P2E.1); overrides CARD_ID from env
#
# Context resolution order (highest priority first):
#   1. Flags passed to this script (--card)
#   2. Environment variables already set in the calling shell
#   3. --env FILE or .env in CWD
#   4. Built-in defaults (for vault paths; CARD_ID has no default and is required)
#
# Required in env / .env:
#   CARD_ID        card shortcode: DECK_CODE.CARD_NUM  e.g. P2E.1
#                  the account's FK to a specific card in a specific deck
#
# Optional in env / .env:
#   AGE_KEY        path to age private key
#                  default: ~/.aurora-agent/keys/totp-key.txt
#   VAULT_DIR      path to vault directory
#                  default: ~/.aurora-agent/secrets
#   PATTERN_VAULT  filename in VAULT_DIR for the pattern
#                  default: gh-pattern.age
#   CARDS_SUBDIR   subdirectory in VAULT_DIR for per-card vault files
#                  default: cards
#   TOKEN_SEP      separator between assembled tokens in output
#                  default: " " (space); set to "" for no separator
#
# Pattern format in vault: DECK_CODE/TOKEN/TOKEN/...
#   DECK_CODE  deck FK (e.g. P2E) — validated against CARD_ID's deck at run time
#   emoji      look up word from card row; ALL CAPS if square (▶), lowercase if circle
#   #          expands to the card number from CARD_ID (e.g. P2E.1 -> "1")
#   literal    any other token appended as-is (e.g. !, 42)
#
# Examples:
#   assemble-password.sh
#   assemble-password.sh --env ~/.AWG26/.AO/GitHub/auth/accounts/aurora-thesean/.env
#   assemble-password.sh --card P2E.299
#   cd ~/.AWG26/.AO/GitHub/auth/accounts/aurora-thesean && assemble-password.sh

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"

usage() {
  grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

ENV_FILE=""
CARD_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)  usage 0 ;;
    --env)      ENV_FILE="$2"; shift 2 ;;
    --card)     CARD_OVERRIDE="$2"; shift 2 ;;
    -*)         echo "unknown flag: $1" >&2; echo "run with --help for usage" >&2; exit 1 ;;
    *)          echo "unexpected argument: $1" >&2; echo "did you mean --card $1?" >&2; exit 1 ;;
  esac
done

load_env() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    local key="${line%%=*}"
    local val="${line#*=}"
    val="${val/#\~/$HOME}"
    case "$key" in
      CARD_ID|AGE_KEY|VAULT_DIR|PATTERN_VAULT|CARDS_SUBDIR|TOKEN_SEP)
        [[ -z "${!key:-}" ]] && export "$key"="$val" ;;
    esac
  done < "$file"
}

if [[ -n "$ENV_FILE" ]]; then
  [[ -f "$ENV_FILE" ]] || { echo "error: --env file not found: $ENV_FILE" >&2; exit 1; }
  load_env "$ENV_FILE"
elif [[ -f "$(pwd)/.env" ]]; then
  load_env "$(pwd)/.env"
fi

# --card flag wins over env
[[ -n "$CARD_OVERRIDE" ]] && CARD_ID="$CARD_OVERRIDE"

AGE_KEY="${AGE_KEY:-$HOME/.aurora-agent/keys/totp-key.txt}"
VAULT_DIR="${VAULT_DIR:-$HOME/.aurora-agent/secrets}"
PATTERN_VAULT="${PATTERN_VAULT:-gh-pattern.age}"
CARDS_SUBDIR="${CARDS_SUBDIR:-cards}"
TOKEN_SEP="${TOKEN_SEP:- }"
LOOKUP_DIR="$SCRIPT_DIR/../lookup"

# CARD_ID is required — it is the account's FK to a specific card
if [[ -z "${CARD_ID:-}" ]]; then
  echo "error: CARD_ID not set" >&2
  echo "  add CARD_ID=DECK.NUM (e.g. P2E.1) to your account .env" >&2
  echo "  or pass --card DECK.NUM" >&2
  exit 1
fi

# Parse CARD_ID into DECK_CODE and CARD_NUM
DECK_CODE="${CARD_ID%.*}"
CARD_NUM="${CARD_ID##*.}"
if [[ "$DECK_CODE" == "$CARD_ID" ]]; then
  echo "error: CARD_ID must be DECK_CODE.CARD_NUM (e.g. P2E.1), got: $CARD_ID" >&2
  exit 1
fi

[[ -f "$AGE_KEY" ]] || { echo "error: age key not found: $AGE_KEY" >&2; exit 1; }
[[ -f "$VAULT_DIR/$PATTERN_VAULT" ]] || {
  echo "error: pattern vault not found: $VAULT_DIR/$PATTERN_VAULT" >&2
  echo "  enroll a pattern first: enroll-pattern.sh" >&2
  exit 1
}

PATTERN=$(age -d -i "$AGE_KEY" "$VAULT_DIR/$PATTERN_VAULT" 2>/dev/null) || {
  echo "error: failed to decrypt pattern vault" >&2; exit 1
}

# Resolve card vault: cards/CARD_ID.age > legacy gh-card.age
if [[ -f "$VAULT_DIR/$CARDS_SUBDIR/$CARD_ID.age" ]]; then
  CARD_VAULT="$VAULT_DIR/$CARDS_SUBDIR/$CARD_ID.age"
elif [[ -f "$VAULT_DIR/gh-card.age" ]]; then
  echo "note: using legacy gh-card.age for CARD_ID=$CARD_ID (re-enroll with enroll-card.sh to assign card ID)" >&2
  CARD_VAULT="$VAULT_DIR/gh-card.age"
else
  echo "error: no card vault found for CARD_ID=$CARD_ID" >&2
  echo "  looked for: $VAULT_DIR/$CARDS_SUBDIR/$CARD_ID.age" >&2
  echo "  enroll the card first: enroll-card.sh" >&2
  exit 1
fi

CARD=$(age -d -i "$AGE_KEY" "$CARD_VAULT" 2>/dev/null) || {
  echo "error: failed to decrypt card vault: $CARD_VAULT" >&2; exit 1
}

if [[ -f "$VAULT_DIR/gh-colors.age" ]]; then
  COLORS=$(age -d -i "$AGE_KEY" "$VAULT_DIR/gh-colors.age" 2>/dev/null)
else
  COLORS=$(cat "$LOOKUP_DIR/colors.json")
fi

echo "$PATTERN"$'\n'"$CARD" | python3 -c "
import sys, json, re

lines = sys.stdin.read().split('\n', 1)
raw_pattern = lines[0].strip().lstrip('/')
card        = lines[1].strip()
sep         = '$TOKEN_SEP'
card_num    = '$CARD_NUM'
deck_code   = '$DECK_CODE'

# Strip deck/card prefix from pattern and optionally validate
pattern_deck = ''
first_slash = raw_pattern.find('/')
if first_slash > 0:
    first_token = raw_pattern[:first_slash]
    colors_check = json.loads('''$COLORS''')
    emoji_set_check = set(colors_check.keys())
    letter_codes = set(['P','p','O','o','A','a','D','d','AP','ap'])
    if not any(c in emoji_set_check for c in first_token) and first_token not in letter_codes:
        # It's a prefix (deck code or old card shortcode)
        if '.' in first_token:
            # Old format: card shortcode embedded in pattern (deprecated)
            pattern_deck = first_token.split('.')[0]
            print(f'warning: old pattern format detected (card shortcode in pattern)',
                  file=sys.stderr)
            print(f'  re-enroll pattern with enroll-pattern.sh to use new format',
                  file=sys.stderr)
        else:
            pattern_deck = first_token
        raw_pattern = raw_pattern[first_slash+1:]

if pattern_deck and pattern_deck != deck_code:
    print(f'warning: pattern deck ({pattern_deck}) does not match CARD_ID deck ({deck_code})',
          file=sys.stderr)
    print(f'  the pattern may not be compatible with this card', file=sys.stderr)

pattern = raw_pattern.strip('/')
colors = json.loads('''$COLORS''')
emoji_set = set(colors.keys())

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

tokens = [t for t in pattern.split('/') if t]
result = []
for token in tokens:
    if token == '#':
        result.append(card_num)
    elif token in emoji_set:
        info = colors[token]
        word, _ = card_map[info['category']]
        result.append(word.upper() if info['symbol'] else word.lower())
    else:
        result.append(token)

sys.stdout.write(sep.join(result))
"

unset PATTERN CARD COLORS CARD_VAULT DECK_CODE CARD_NUM
