# card-key-derivation

Derive credentials from physical board game cards using steganographic emoji encoding. No password is ever stored — only encrypted fragments that require the physical card to reconstruct.

## Encoding scheme

Each card row is encoded as a single emoji carrying two dimensions of information:

| Dimension | Encoding | Example |
|---|---|---|
| Category | Color (P=yellow, O=blue, A=brown, D=green, AP=red) | 🟡=P, 🔵=O |
| ▶ symbol | Shape (square=present, circle=absent) | 🟨=P+▶, 🟡=P+no▶ |

A full card in condensed form: `P2E.299/🟨UMPIRE🔵SPINNING WHEEL🟤DINE🟩MISMATCH🔴TRACK`

## Passcode pattern

Stored separately as an encrypted emoji sequence: `🟨/🔵/🟤/.299/`

Pattern tokens are either emojis (resolved to card words with capitalization from ▶) or literals (appended as-is).

## Enrollment

```bash
npm run enroll-card      # enter card: P2E.299/>word/word/>word/word/word
npm run enroll-pattern   # store emoji pattern
npm run enroll-colors    # store color→category lookup (encrypted)
npm run enroll-editions  # store edition nicknames (encrypted)
```

## Usage

```bash
npm run show-card          # render full markdown card table
npm run assemble-password  # derive password → stdout (pipe to login tool)
```

## Security properties

- Physical card is required to derive any password — digital artifacts alone are insufficient
- No category names, letter codes, or ▶ markers appear in stored pattern
- Four independent encrypted secrets — none sufficient alone
- `assemble-password` pipes directly to stdout; full password never stored
- Compatible with `SKILL-OF/password-handling` vault conventions (age encryption)

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
