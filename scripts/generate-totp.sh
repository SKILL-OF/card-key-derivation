#!/usr/bin/env bash
# generate-totp.sh — emit current TOTP code from encrypted vault
#
# The secret is decrypted and piped directly to oathtool via stdin.
# It never appears in a process cmdline or temp file.
#
# Environment:
#   AGE_KEY     path to age private key (default: ~/.aurora-agent/keys/totp-key.txt)
#   TOTP_VAULT  path to encrypted TOTP secret (default: ~/.aurora-agent/secrets/totp-encrypted.age)
#
# Outputs a 6-digit code to stdout.

set -euo pipefail

AGE_KEY="${AGE_KEY:-$HOME/.aurora-agent/keys/totp-key.txt}"
TOTP_VAULT="${TOTP_VAULT:-$HOME/.aurora-agent/secrets/totp-encrypted.age}"

[[ -f "$AGE_KEY" ]]   || { echo "error: age key not found: $AGE_KEY" >&2; exit 1; }
[[ -f "$TOTP_VAULT" ]] || { echo "error: TOTP vault not found: $TOTP_VAULT" >&2; exit 1; }

age -d -i "$AGE_KEY" "$TOTP_VAULT" 2>/dev/null \
  | tr -d '[:space:]' \
  | oathtool --totp --base32 -
