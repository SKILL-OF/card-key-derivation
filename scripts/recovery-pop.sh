#!/usr/bin/env bash
# recovery-pop.sh — pop one recovery code from the encrypted vault (stack discipline)
#
# Prints the first unused code to stdout and re-encrypts the remainder.
# Each code is single-use; this enforces that by removing it after printing.
#
# Environment:
#   AGE_KEY          path to age private key
#                    default: ~/.aurora-agent/keys/totp-key.txt
#   RECOVERY_VAULT   path to encrypted recovery codes file
#                    default: ~/.aurora-agent/secrets/github-recovery-codes.age

set -euo pipefail

AGE_KEY="${AGE_KEY:-$HOME/.aurora-agent/keys/totp-key.txt}"
RECOVERY_VAULT="${RECOVERY_VAULT:-$HOME/.aurora-agent/secrets/github-recovery-codes.age}"

[[ -f "$AGE_KEY" ]]        || { echo "error: age key not found: $AGE_KEY" >&2; exit 1; }
[[ -f "$RECOVERY_VAULT" ]] || { echo "error: no recovery codes vault: $RECOVERY_VAULT" >&2; exit 1; }

PUBKEY=$(age-keygen -y "$AGE_KEY")
CODES=$(age -d -i "$AGE_KEY" "$RECOVERY_VAULT" 2>/dev/null)
COUNT=$(printf '%s\n' "$CODES" | grep -c '\S' || true)

if [[ "$COUNT" -eq 0 ]]; then
  echo "error: no recovery codes remaining" >&2
  exit 1
fi

FIRST=$(printf '%s\n' "$CODES" | grep '\S' | head -1)
REST=$(printf '%s\n' "$CODES" | grep '\S' | tail -n +2 || true)

printf '%s\n' "$FIRST"

printf '%s\n' "$REST" | age -r "$PUBKEY" > "${RECOVERY_VAULT}.new"
mv "${RECOVERY_VAULT}.new" "$RECOVERY_VAULT"

REMAINING=$(( COUNT - 1 ))
printf '%d codes remaining\n' "$REMAINING" >&2

unset CODES FIRST REST PUBKEY
