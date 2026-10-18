# Voice (STT + TTS) helpers for Termux

System-wide offline voice in and out on Android, callable from any shell.

## Stack

- **STT**: Whisper+ (`org.woheller69.whisperplus`) set as the system voice recognition service.
  Triggered from Termux via `termux-speech-to-text`.
- **TTS**: Kokoro via NekoSpeak or Sherpa-ONNX TTS engine APK set as the default Android TTS engine.
  Triggered from Termux via `termux-tts-speak`.

Neither requires an accessibility service. Both work in every Android app for system-level voice features (typing, reading) and in any shell process via the wrapper scripts here.

## One-time setup

On the Android device:

1. Install the Termux:API APK from F-Droid: https://f-droid.org/packages/com.termux.api/
2. In Termux: `pkg install termux-api pulseaudio`
3. **STT** — Install Whisper+:
   - https://f-droid.org/packages/org.woheller69.whisperplus/
   - Open the app, download the Whisper ONNX model.
   - Set as system voice service: **Settings → System → Languages → Speech → Voice Input → Whisper+**, OR via ADB:
     ```sh
     adb shell settings put secure voice_recognition_service \
       org.woheller69.whisperplus/com.whisperonnx.WhisperRecognitionService
     ```
4. **TTS** — Install NekoSpeak (or Sherpa-ONNX TTS engine):
   - NekoSpeak v1.4.2 APK: https://github.com/siva-sub/NekoSpeak/releases/tag/v1.4.2
     (pick `app-arm64-v8a-release.apk`)
   - Open the app, download Kokoro v1.0 (~115 MB).
   - **Settings → General Management → Language & Input → Text-to-Speech → Preferred engine → NekoSpeak**.

## Scripts

| File           | What it does                                                |
|----------------|-------------------------------------------------------------|
| `say.sh`       | Speaks its argument (or stdin) via system TTS engine.       |
| `listen.sh`    | Captures one utterance and prints it.                       |
| `dictate.sh`   | Loops listen → write to a file or pipe.                     |
| `voiceloop.sh` | Listen → run a command with the transcript → speak result.  |

Install:
```sh
chmod +x *.sh
cp say.sh listen.sh dictate.sh voiceloop.sh "$PREFIX/bin/"
```

Use:
```sh
say.sh "good morning"
echo "this came from stdin" | say.sh

text=$(listen.sh)
echo "heard: $text"

voiceloop.sh openclaude --print
```

## Choosing the TTS engine explicitly

`termux-tts-speak -e <package>` forces a specific engine. Useful packages:

- `com.github.sivasub.nekospeak` — NekoSpeak
- `com.k2fsa.sherpa.onnx.tts.engine.kokoro` — Sherpa-ONNX Kokoro EN
- `com.k2fsa.sherpa.onnx.tts.engine.kokoro.multilang` — Sherpa-ONNX Kokoro multi-lang

(verify exact package id by running `termux-tts-engines`)
