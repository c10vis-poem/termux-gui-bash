#!/data/data/com.termux/files/usr/bin/bash
# say.sh — speak its argument (or stdin) via the system TTS engine.
# Usage:
#   say.sh "text to speak"
#   echo "text from stdin" | say.sh
#   say.sh -e com.github.sivasub.nekospeak "force NekoSpeak"
set -eu

if [ $# -gt 0 ] && [ "$1" = "-e" ]; then
  engine="$2"
  shift 2
  if [ $# -gt 0 ]; then
    termux-tts-speak -e "$engine" -- "$*"
  else
    termux-tts-speak -e "$engine"
  fi
  exit
fi

if [ $# -gt 0 ]; then
  termux-tts-speak -- "$*"
else
  termux-tts-speak
fi
