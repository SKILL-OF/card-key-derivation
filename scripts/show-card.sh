#!/usr/bin/env bash
# show-card.sh — decrypt card vault and render as markdown table
set -euo pipefail

KEY="$HOME/.aurora-agent/keys/totp-key.txt"
VAULT="$HOME/.aurora-agent/secrets/gh-card.age"
LOOKUP_DIR="$(dirname "$0")/../lookup"

age -d -i "$KEY" "$VAULT" 2>/dev/null | python3 - "$LOOKUP_DIR" << 'PYEOF'
import sys, json, os

lookup_dir = sys.argv[1]
line = sys.stdin.read().strip()

with open(os.path.join(lookup_dir, 'colors.json')) as f:
    colors = json.load(f)
with open(os.path.join(lookup_dir, 'editions.json')) as f:
    editions = json.load(f)

prefix, payload = line.split('/', 1)
edition_code, card_num = prefix.split('.')
title = editions.get(edition_code, edition_code)

# Parse emoji-delimited entries
emoji_set = set(colors.keys())
entries = []
current_emoji = None
current_chars = []

for ch in payload:
    if ch in emoji_set:
        if current_emoji is not None:
            entries.append((current_emoji, ''.join(current_chars).strip()))
        current_emoji = ch
        current_chars = []
    else:
        current_chars.append(ch)
if current_emoji is not None:
    entries.append((current_emoji, ''.join(current_chars).strip()))

print(f'**{title}**')
print()
print('| | | |')
print('|:--|:--|--:|')
for emoji, word in entries:
    info = colors[emoji]
    cat = info['category']
    cell = f'▶ {word}' if info['symbol'] else word
    print(f'| **{cat}** | {cell} | |')
print(f'| | | **{card_num}** |')
PYEOF
