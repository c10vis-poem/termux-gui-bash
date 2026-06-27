# Android STT/TTS System — Session Handoff

> Living state doc for the Termux + proot-Ubuntu voice/agent stack on phone (and
> later tablet). Update the checklists at the end of each session.

Last updated: 2026-06-27 · Branch: `claude/android-stt-tts-system-9vb7do`

## Platform

- **Termux** (native Android) + **proot-distro Ubuntu** for the heavy userland.
- **TTS:** NekoSpeak (default engine).
- **STT:** Whisper+ installed.
- **Agent:** `openclaude` via OpenRouter, default model `openai/gpt-oss-120b`.

### Aliases (`~/.zshrc`)

```sh
tts='termux-tts-speak -e com.nekospeak.tts'
listen='termux-speech-to-text'
```

> ⚠️ **Likely root cause of the TTS bug:** this alias uses `com.nekospeak.tts`,
> but `examples/voice-stt-tts/say.sh` on this branch uses
> `com.github.sivasub.nekospeak`. At least one is wrong. Confirm the real id
> with `termux-tts-engines` (see TTS section) and fix the alias to match.

> Ready-made wrappers already live in `examples/voice-stt-tts/` on this branch:
> `say.sh` (TTS), `listen.sh` (STT), `dictate.sh`, and `voiceloop.sh`
> (listen → pipe to a command → speak the reply). The XFCE launchers are in
> `examples/xfce-x11-launcher/` (chroot `start-xfce.sh` + proot fallback).

## Status

### Working ✓
- `openclaude /status` shows the **live** session model (not stale env).
- `openclaude /model` lists live OpenRouter models (30+).
- `openclaude` survives reboot.
- XFCE helper scripts present: `~/scripts/start-xfce.sh`, `stop-xfce.sh`, etc.

### Broken ✗
- **STT:** `termux-speech-to-text` runs but returns nothing (Whisper+ not routed).
- **TTS:** speaks, but wrong voice; `-e` engine flag has no effect.
- **XFCE:** desktop never launched/tested (`start-xfce-proot.sh` untested).
- **openclaude:** no `/listen` or `/tts` commands yet (need to add + rebuild).

---

## 1. Fix STT routing (Whisper+)

`termux-speech-to-text` (Termux:API) drives Android's `SpeechRecognizer`, which
uses the **system default recognition service** — it does NOT auto-pick Whisper+.
Empty output almost always means one of: mic permission, no default recognizer,
or the recognizer needs the foreground.

Diagnostic order:

```sh
# 1. Termux:API app actually installed and matching Termux version?
termux-info | grep -i api          # or: pm list packages | grep termux.api

# 2. Mic permission granted to Termux:API?
#    Android Settings → Apps → Termux:API → Permissions → Microphone = Allow

# 3. What recognizer is the system using?
#    Settings → Apps → Default apps → Digital assistant app  (set to Whisper+),
#    AND/OR Settings → System → Languages & input → On-device recognition.

# 4. Raw test with verbose, speak immediately:
termux-speech-to-text          # then talk; expect transcript on stdout
```

Notes:
- If Whisper+ exposes a `RecognitionService`, selecting it as the assistant /
  voice-input app is what makes `termux-speech-to-text` route to it.
- If it does NOT expose a system RecognitionService, `termux-speech-to-text`
  cannot reach it — fall back to calling Whisper+ via its own intent/share
  target, or run on-device whisper (whisper.cpp / kokoro pipeline) directly in
  proot and skip Termux:API for STT.
- Last resort that always works: record with `termux-microphone-record` then
  pipe the WAV to a local whisper.cpp binary.

```sh
termux-microphone-record -f /sdcard/stt.wav -l 8   # 8s clip
termux-microphone-record -q
# then: whisper-cli -m models/ggml-base.en.bin -f /sdcard/stt.wav
```

## 2. Fix TTS routing (NekoSpeak voice + `-e`)

```sh
# Authoritative list of engine package ids + voices:
termux-tts-engines      # copy the exact NAME for NekoSpeak
termux-tts-speak -e <EXACT_NAME> "engine test"
```

If `-e` still has no effect (known to be flaky in some Termux:API builds), set
NekoSpeak **system-wide** instead and drop the flag:

- Settings → Accessibility → Text-to-speech output → Preferred engine = NekoSpeak
- Pick the desired voice there too (fixes "wrong voice").

Then simplify the alias:

```sh
tts='termux-tts-speak'   # uses system default engine/voice
```

## 3. Add `/listen` and `/tts` to openclaude

**Shortcut:** `examples/voice-stt-tts/voiceloop.sh` already wires
listen → command → speak today (`voiceloop.sh openclaude --print`). Use it to
get a working voice loop before native `/listen` `/tts` land in openclaude.

`openclaude` is a separate repo (not in scope of tmux / termux-gui-bash). Plan:

1. Locate the slash-command dispatch (search for where `/status` and `/model`
   are registered).
2. Add two commands that shell out to the verified aliases/commands:
   - `/listen` → run `termux-speech-to-text`, capture stdout, inject as the next
     user prompt.
   - `/tts <text>` (and an auto-speak toggle) → pipe assistant text to
     `termux-tts-speak`.
3. Keep them thin wrappers so they work whether STT/TTS is Termux:API or a local
   whisper/kokoro binary (make the backend a configurable command string).
4. Rebuild, smoke-test `/listen` and `/tts`, push.

## 4. XFCE desktop — real stack is TigerVNC + Debian + AVNC

Actual stack in use: `Termux → tmux → proot Debian → TigerVNC (X11) → XFCE`,
viewed in the **AVNC** app on `127.0.0.1`:
- `:1 → 5901` gui · `:2 → 5902` portrait · `:3 → 5903` landscape

Launcher lives at `examples/tigervnc-debian/vnc.sh`:

```sh
./vnc.sh start gui          # :1 -> 5901
./vnc.sh start portrait     # :2 -> 5902  (geometry 500x1280)
./vnc.sh start landscape    # :3 -> 5903  (geometry 1280x500)
./vnc.sh status
```

Geometry defaults are ~half native (≈`1280x500` / flipped `500x1280`);
override with `GEOM_*` env vars. See `examples/tigervnc-debian/README.md`.

> The earlier `examples/xfce-x11-launcher/` (Termux:X11 + Ubuntu chroot) is a
> *different* approach, kept only as an alternative — not the live stack.

## 5. Task 6 — kokoro-onnx Android arm64 build docs

Goal: on-device, offline TTS (and STT pairing) via ONNX Runtime on arm64.
- Pull `onnxruntime` arm64 (aarch64) — prebuilt wheels exist for Linux aarch64;
  install inside **proot Ubuntu** (`pip install onnxruntime kokoro-onnx`).
- Fetch kokoro model + voices (`kokoro-v*.onnx`, `voices*.bin`) from HF.
- Verify it runs under proot; document model paths, sample rate, latency.
- This is the durable fix for both "wrong voice" and offline operation.

---

## Resume checklist (do these first next session)

- [ ] `termux-tts-engines` → record exact NekoSpeak id; reconcile alias
      (`com.nekospeak.tts`) vs `say.sh` (`com.github.sivasub.nekospeak`).
- [ ] Verify Termux:API mic permission; set Whisper+ as assistant; retest STT.
- [ ] If STT still empty → switch to `termux-microphone-record` + local whisper.
- [ ] Run XFCE script, capture working command + port.
- [ ] Add `/listen` + `/tts` to openclaude, rebuild, push.
- [ ] Start kokoro-onnx arm64 build notes under this dir.
- [ ] Replicate setup on tablet.

## Branch / repo notes

- This session: `claude/android-stt-tts-system-9vb7do`.
- Prior work tracked on `claude/android-stt-tts-system-8rjddg`.
- In-scope repos: `c10vis-poem/tmux`, `c10vis-poem/termux-gui-bash`.
- openclaude source is **out of scope here** — clone separately for §3.
