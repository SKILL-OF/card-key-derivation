#!/usr/bin/env bash
# enroll-secret.sh — generic: read a value silently, encrypt to named vault file
# Usage: enroll-secret.sh <vault-filename> <prompt>
# Example: enroll-secret.sh gh-pattern.age "Paste PASSCODE_PATTERN value"

set -euo pipefail

KEY="$HOME/.aurora-agent/keys/totp-key.txt"
VAULT="$HOME/.aurora-agent/secrets/$1"
PROMPT="${2:-Paste value}"

echo "$PROMPT then press Enter:" >&2
read -rs VALUE
PUBKEY=$(age-keygen -y "$KEY")
printf '%s' "$VALUE" | age -r "$PUBKEY" > "$VAULT"
chmod 0600 "$VAULT"
echo "Stored." >&2
unset VALUE PUBKEY
