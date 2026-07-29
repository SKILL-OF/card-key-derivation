---
name: card-key-derivation
description: Derive account passwords from any physical card with words (game cards, business cards, playing cards, etc.) using steganographic emoji encoding — the physical card is required to reconstruct any password; no word material is stored digitally.
scope: vault operations for any account whose password is derived from a physical card as a key factor
trigger: when assembling a password for login, enrolling a new card into the vault, or enrolling an account-specific pattern
---

# card-key-derivation

Derive credentials from any physical card with words using steganographic emoji encoding.
No password is ever stored — only encrypted fragments that require the physical card to reconstruct.

Works with any card that has categorized word rows: board game cards (Pictionary, Taboo, etc.),
playing cards from themed decks, business cards with fields, any multi-row card with distinct word slots.

## Encoding scheme

Each card row is encoded as a single emoji carrying two dimensions of information:

| Dimension | Encoding | Example |
|---|---|---|
| Category | Color (P=yellow, O=blue, A=brown, D=green, AP=red) | 🟡=P, 🔵=O |
| Symbol (▶) | Shape (square=present, circle=absent) | 🟨=P+▶, 🟡=P+no▶ |

The ▶ symbol marks a "play" or emphasis indicator on the physical card (e.g. all-play, bold, starred).
Square has angles; triangles have angles. Parsimony: angles represent angles.

A full card in condensed form: `P2E.299/🟨UMPIRE🔵SPINNING WHEEL🟤DINE🟩MISMATCH🔴TRACK`

## Pattern format

Stored separately as an encrypted emoji sequence: `P2E.299/🟨/🔵/🟤/`

- Prefix before first `/` is the card ID (deck code + card number, e.g. `P2E.299`)
- Tokens are either emojis (resolved to card words with capitalization from ▶) or literals
- `#` is a special token: expands to the card number extracted from the card ID prefix
- Arbitrary order and repetition: `P2E.299/🟨/🔵/🟨/🟫/` is valid

## Category codes

| Code | Category | Pictionary equivalent |
|---|---|---|
| P | Primary / first category | Yellow row |
| O | Object / second category | Blue row |
| A | Action / third category | Brown/tan row |
| D | Difficult / fourth category | Green row |
| AP | All-Play / fifth category | Red row |

These codes are mnemonics only. Map them to whatever your card's actual categories mean.

## Enrollment

```bash
# From the skill's install directory, or via account wrappers:
bash scripts/enroll-card.sh     # enter card: P2E.299/>word/word/>word/word/word
bash scripts/enroll-pattern.sh  # store emoji pattern for this account
bash scripts/enroll-secret.sh gh-colors.age 'Paste colors JSON'
bash scripts/enroll-secret.sh gh-editions.age 'Paste editions JSON'
```

Environment variables (override defaults):
- `AGE_KEY` — path to age private key (default: `~/.aurora-agent/keys/totp-key.txt`)
- `VAULT_DIR` — path to vault directory (default: `~/.aurora-agent/secrets`)
- `PATTERN_VAULT` — filename in VAULT_DIR for the pattern (default: `gh-pattern.age`)
- `CARDS_SUBDIR` — subdirectory in VAULT_DIR for multi-card storage (default: `cards`)

## Usage

```bash
bash scripts/assemble-password.sh           # derive password → stdout
bash scripts/assemble-password.sh P2E.1.age # explicit card vault name
bash scripts/show-card.sh                   # render full markdown card table
```

## Security properties

- Physical card is required to derive any password — digital artifacts alone are insufficient
- No category names, letter codes, or ▶ markers appear in stored pattern
- Four independent encrypted secrets — none sufficient alone
- `assemble-password` pipes directly to stdout; full password never stored
- Compatible with `SKILL-OF/password-handling` vault conventions (age encryption)

## Local install (Claude Code on Linux)

Platform-verified 2026-07-16 on aurora@aurora.wordgarden.dev (Kali Linux, Claude Code):

```bash
# Clone scripts to lib directory
gh repo clone SKILL-OF/card-key-derivation ~/.local/lib/skills/card-key-derivation

# Install flat skill index file (the format Claude Code actually discovers)
cp ~/.local/lib/skills/card-key-derivation/SKILL.md \
   ~/.claude/skills/card-key-derivation.skill.md
```

Claude Code on this machine discovers `~/.claude/skills/*.skill.md` as flat files.
The subdirectory model (`~/.claude/skills/<name>/SKILL.md`) created by `skill-of/install.sh`
is **unverified** — Claude Code may or may not recurse into subdirectories.

## Color table (lookup/colors.json)

| Emoji | Category | ▶ |
|---|---|---|
| 🟡 | P | — |
| 🟨 | P | ▶ |
| 🔵 | O | — |
| 🟦 | O | ▶ |
| 🟤 | A | — |
| 🟫 | A | ▶ |
| 🟢 | D | — |
| 🟩 | D | ▶ |
| 🔴 | AP | — |
| 🟥 | AP | ▶ |
