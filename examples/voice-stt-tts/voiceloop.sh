#!/data/data/com.termux/files/usr/bin/bash
# voiceloop.sh — full voice loop:
#   1. listen for one utterance (Whisper+)
#   2. pipe transcript to the given command on stdin
#   3. speak the command's stdout back via TTS
#
# Usage:
#   voiceloop.sh openclaude --print
#   voiceloop.sh -- llm chat            # everything after -- is the command
#   voiceloop.sh -n 3 openclaude --print  # 3 turns, then exit
#
# Press Ctrl-C to stop early.
set -eu

turns=0
while [ $# -gt 0 ]; do
  case "$1" in
    -n) turns="$2"; shift 2 ;;
    --) shift; break ;;
    *)  break ;;
  esac
done

if [ $# -eq 0 ]; then
  echo "usage: voiceloop.sh [-n turns] [--] command [args...]" >&2
  exit 2
fi

trap 'exit 0' INT

count=0
while :; do
  termux-toast -s "listening…" 2>/dev/null || true
  text=$(termux-speech-to-text || true)
  if [ -z "$text" ]; then
    continue
  fi
  printf '> %s\n' "$text"
  reply=$(printf '%s\n' "$text" | "$@" 2>/dev/null || true)
  if [ -n "$reply" ]; then
    printf '%s\n' "$reply"
    printf '%s\n' "$reply" | termux-tts-speak
  fi
  count=$((count + 1))
  if [ "$turns" -gt 0 ] && [ "$count" -ge "$turns" ]; then
    break
  fi
done
