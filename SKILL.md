---
name: card-key-derivation
description: Derive a password or passcode from a physical board-game card via steganographic emoji encoding, so digital artifacts alone (the stored pattern, the color lookup) are insufficient to reconstruct it without the physical card in hand.
scope: any agent enrolling or assembling a credential that is deliberately split between digital secrets and a physical card artifact, including skills that depend on this one for that split (see Compatibility below)
trigger: asked to enroll a new card-derived credential (npm run enroll-*), or to assemble/retrieve a password that depends on this card-based scheme
---

# Card Key Derivation

See `README.md` for the full encoding scheme, enrollment/usage commands, and security properties. This file exists so the harness can discover and index the skill (`name`/`description` are read directly into the skill manifest); the README remains the source of truth for how the scheme actually works.

## Compatibility

Real scripts here: `enroll-card.sh`, `enroll-secret.sh`, `show-card.sh`, `assemble-password.sh`. All operate on the card→password derivation scheme described in the README. This repo has no TOTP/2FA code generation under any script name — `skill-of/github-headless-login`'s dependency on a `generate-totp.sh` here is tracked separately as a real gap in `card-key-derivation#3`, not resolved by this file.
