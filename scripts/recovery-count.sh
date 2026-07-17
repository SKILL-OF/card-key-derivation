#!/usr/bin/env bash
# recovery-count.sh — report how many recovery codes remain in the vault
#
# Environment:
#   AGE_KEY          path to age private key
#                    default: ~/.aurora-agent/keys/totp-key.txt
#   RECOVERY_VAULT   path to encrypted recovery codes file
#                    default: ~/.aurora-agent/secrets/github-recovery-codes.age

set -euo pipefail

AGE_KEY="${AGE_KEY:-$HOME/.aurora-agent/keys/totp-key.txt}"
RECOVERY_VAULT="${RECOVERY_VAULT:-$HOME/.aurora-agent/secrets/github-recovery-codes.age}"

if [[ ! -f "$RECOVERY_VAULT" ]]; then
  echo "0 codes remaining"
  exit 0
fi

COUNT=$(age -d -i "$AGE_KEY" "$RECOVERY_VAULT" 2>/dev/null | grep -c '\S' || true)
printf '%d codes remaining\n' "$COUNT"
