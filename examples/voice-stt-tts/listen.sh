#!/data/data/com.termux/files/usr/bin/bash
# listen.sh — capture one spoken utterance, print transcript to stdout.
# Routes through Android's system voice recognition service.
# Set that to Whisper+ once and every invocation here is offline Whisper.
# Usage:
#   text=$(listen.sh)
#   listen.sh > note.txt
set -eu

termux-speech-to-text
