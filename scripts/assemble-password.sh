#!/usr/bin/env bash
# assemble-password.sh — derive password from encrypted pattern + card
#
# Usage: assemble-password.sh [--env FILE] [CARD_VAULT_NAME]
#
#   --env FILE       load vault context from FILE (default: .env in CWD if present)
#   CARD_VAULT_NAME  filename (no path) in VAULT_DIR — overrides pattern-derived card
#
# Context resolution order (highest priority first):
#   1. Environment variables already set in the calling shell
#   2. --env FILE argument
#   3. .env file in the current working directory
#   4. Built-in defaults
#
# .env / environment variables:
#   AGE_KEY        path to age private key
#                  default: ~/.aurora-agent/keys/totp-key.txt
#   VAULT_DIR      path to vault directory
#                  default: ~/.aurora-agent/secrets
#   PATTERN_VAULT  filename in VAULT_DIR for the pattern
#                  default: gh-pattern.age
#   CARDS_SUBDIR   subdirectory in VAULT_DIR for multi-card storage
#                  default: cards
#
# Pattern format:  [CARDID/]TOKEN/TOKEN/...
#   CARDID prefix (e.g. P2E.1) resolves to VAULT_DIR/CARDS_SUBDIR/P2E.1.age
#   emoji token   -> look up word from card; capitalize if square emoji (symbol present)
#   #             -> card number extracted from CARDID (e.g. P2E.1 -> 1)
#   anything else -> literal (e.g. !, 42)
#
# Examples:
#   assemble-password.sh
#   assemble-password.sh --env ~/.AWG26/.AO/GitHub/auth/accounts/aurora-thesean/.env
#   cd ~/.AWG26/.AO/GitHub/auth/accounts/aurora-thesean && assemble-password.sh

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"

usage() {
  grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

# Parse flags
ENV_FILE=""
CARD_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage 0 ;;
    --env)     ENV_FILE="$2"; shift 2 ;;
    -*)        echo "unknown flag: $1" >&2; echo "run with --help for usage" >&2; exit 1 ;;
    *)         CARD_ARG="$1"; shift ;;
  esac
done

# Load .env: --env arg > CWD .env > nothing
load_env() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    local key="${line%%=*}"
    local val="${line#*=}"
    val="${val/#\~/$HOME}"  # expand leading ~
    # Only set if not already in environment (env vars take priority over .env)
    case "$key" in
      AGE_KEY|VAULT_DIR|PATTERN_VAULT|CARDS_SUBDIR)
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

AGE_KEY="${AGE_KEY:-$HOME/.aurora-agent/keys/totp-key.txt}"
VAULT_DIR="${VAULT_DIR:-$HOME/.aurora-agent/secrets}"
PATTERN_VAULT="${PATTERN_VAULT:-gh-pattern.age}"
CARDS_SUBDIR="${CARDS_SUBDIR:-cards}"
LOOKUP_DIR="$SCRIPT_DIR/../lookup"

[[ -f "$AGE_KEY" ]] || { echo "error: age key not found: $AGE_KEY" >&2; exit 1; }
[[ -f "$VAULT_DIR/$PATTERN_VAULT" ]] || {
  echo "error: pattern vault not found: $VAULT_DIR/$PATTERN_VAULT" >&2
  echo "  enroll a pattern first: enroll-pattern.sh" >&2
  exit 1
}

PATTERN=$(age -d -i "$AGE_KEY" "$VAULT_DIR/$PATTERN_VAULT" 2>/dev/null) || {
  echo "error: failed to decrypt pattern vault" >&2; exit 1
}

# Extract card ID from pattern prefix (e.g. "P2E.1/🟨/..." -> "P2E.1")
CARD_ID=""
if [[ "$PATTERN" =~ ^([^/]+\.[^/]+)/ ]]; then
  CARD_ID="${BASH_REMATCH[1]}"
fi

# Resolve card vault: explicit arg > cards/CARDID.age > gh-card.age
if [[ -n "$CARD_ARG" ]]; then
  CARD_VAULT="$VAULT_DIR/$CARD_ARG"
  [[ -f "$CARD_VAULT" ]] || { echo "error: card vault not found: $CARD_VAULT" >&2; exit 1; }
elif [[ -n "$CARD_ID" ]] && [[ -f "$VAULT_DIR/$CARDS_SUBDIR/$CARD_ID.age" ]]; then
  CARD_VAULT="$VAULT_DIR/$CARDS_SUBDIR/$CARD_ID.age"
elif [[ -f "$VAULT_DIR/gh-card.age" ]]; then
  CARD_VAULT="$VAULT_DIR/gh-card.age"
else
  echo "error: no card vault found" >&2
  if [[ -n "$CARD_ID" ]]; then
    echo "  pattern references card: $CARD_ID" >&2
    echo "  looked for: $VAULT_DIR/$CARDS_SUBDIR/$CARD_ID.age" >&2
  fi
  echo "  enroll a card first: enroll-card.sh" >&2
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
raw_pattern = lines[0].strip()
card        = lines[1].strip()

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
        result.append(word.capitalize() if info['symbol'] else word.lower())
    else:
        result.append(token)

sys.stdout.write(''.join(result))
"

unset PATTERN CARD COLORS CARD_VAULT CARD_ID
