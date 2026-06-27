#!/data/data/com.termux/files/usr/bin/bash
# dictate.sh — continuously listen, appending each utterance to stdout (or a file).
# Press Ctrl-C to stop. Each iteration is one utterance.
# Usage:
#   dictate.sh                  # to stdout
#   dictate.sh > journal.md
#   dictate.sh | tee journal.md
set -eu

trap 'exit 0' INT

while :; do
  line=$(termux-speech-to-text || true)
  [ -z "$line" ] && continue
  printf '%s\n' "$line"
done
