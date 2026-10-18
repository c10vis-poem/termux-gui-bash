#!/data/data/com.termux/files/usr/bin/bash
# stt-doctor.sh — diagnose why termux-speech-to-text returns nothing.
# Run in Termux (NOT inside proot/Debian). Paste the whole output back.
#
#   bash stt-doctor.sh
#
# It only reads state and does one short live mic test at the end.
set +e

line() { printf '\n──────── %s ────────\n' "$*"; }

line "1. Termux:API binary present?"
command -v termux-speech-to-text && echo "  binary: OK" || echo "  MISSING: pkg install termux-api"
command -v termux-microphone-record >/dev/null && echo "  mic helper: OK" || echo "  mic helper MISSING"

line "2. Relevant apps installed (need Termux:API app + Whisper+)"
pm list packages 2>/dev/null | grep -iE 'termux|whisper|nekospeak|sherpa' || echo "  pm not available"

line "3. System voice-recognition service (THIS is the router)"
echo "  voice_recognition_service = $(settings get secure voice_recognition_service 2>/dev/null)"
echo "  voice_interaction_service = $(settings get secure voice_interaction_service 2>/dev/null)"
echo "  assistant                 = $(settings get secure assistant 2>/dev/null)"
echo "  -> for offline Whisper+, the recognition_service should point at"
echo "     org.woheller69.whisperplus/...  (null or a Google component = not routed)"

line "4. Mic permission for Termux:API (1s record probe)"
out="$HOME/.stt-doctor-probe.wav"
rm -f "$out"
termux-microphone-record -f "$out" -l 1 2>&1
sleep 2
termux-microphone-record -q 2>&1
if [ -s "$out" ]; then
  echo "  recorded $(wc -c < "$out") bytes -> mic permission OK"
else
  echo "  NO audio captured -> grant Microphone to the Termux:API app in"
  echo "     Android Settings > Apps > Termux:API > Permissions"
fi
rm -f "$out"

line "5. Live STT test (speak a short sentence now, ~5s)"
echo "  calling termux-speech-to-text ..."
result="$(termux-speech-to-text 2>&1)"
rc=$?
echo "  exit code : $rc"
echo "  transcript: '${result}'"
[ -z "$result" ] && echo "  EMPTY -> see section 3 (recognizer) / section 4 (mic)"

line "done — paste everything above"
