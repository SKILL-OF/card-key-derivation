#!/usr/bin/env bash
# enroll-secret.sh — generic: read a value silently, encrypt to named vault file
# Usage: enroll-secret.sh <vault-filename> <prompt>
# Example: enroll-secret.sh gh-pattern.age "Paste PASSCODE_PATTERN value"
#
# Environment:
#   AGE_KEY    path to age private key (default: ~/.aurora-agent/keys/totp-key.txt)
#   VAULT_DIR  path to vault directory  (default: ~/.aurora-agent/secrets)

set -euo pipefail

AGE_KEY="${AGE_KEY:-$HOME/.aurora-agent/keys/totp-key.txt}"
VAULT_DIR="${VAULT_DIR:-$HOME/.aurora-agent/secrets}"
VAULT="$VAULT_DIR/$1"
PROMPT="${2:-Paste value}"

echo "$PROMPT then press Enter:" >&2
read -rs VALUE
PUBKEY=$(age-keygen -y "$AGE_KEY")
printf '%s' "$VALUE" | age -r "$PUBKEY" > "$VAULT"
chmod 0600 "$VAULT"
echo "Stored." >&2
unset VALUE PUBKEY
