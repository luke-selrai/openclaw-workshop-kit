---
name: voice-transcription
description: Self-hosted speech-to-text via whisper.cpp + ffmpeg. Synchronised from the canonical implementation at https://github.com/selrai-company/rodolfo-cloudkit-research/tree/main/skills/voice-transcription. Use to add voice-message support to any chat channel (Telegram/Discord/Slack), or to transcribe local audio files. Default model `base.en` (~150 MB; ~250 MB RAM during inference; ~real-time on a t4g.small ARM VM).
---

# voice-transcription

> **Canonical source:** [`selrai-company/rodolfo-cloudkit-research/skills/voice-transcription/`](https://github.com/selrai-company/rodolfo-cloudkit-research/tree/main/skills/voice-transcription)
> Future improvements should land there first and be backported. This file is a synchronised copy.

## When to enable

- Team members want to talk to the bot from a phone (faster than typing on a small keyboard)
- Voice memos as a quicker capture mechanism for thoughts/notes ("ask orchestrator: what was that idea I left on Tuesday?")
- Privacy-sensitive contexts where audio cannot be uploaded to a third-party API

Don't enable if:
- VM has <2 GB RAM AND you also want medium/large models. base.en fits in <300 MB resident; medium needs ~1.5 GB.
- You only need to handle text. Adding whisper.cpp + ffmpeg + 150 MB model is wasted disk if voice isn't used.

## Architecture

```
[Telegram voice note]
  ↓ getFile API
[handler.py downloads .oga file to /tmp]
  ↓ /usr/local/bin/cloudkit-transcribe <audio>
[ffmpeg → 16kHz mono WAV] → [whisper-cli + ggml-base.en.bin] → stdout: transcript
  ↓
[handler.py uses transcript as the prompt for claude]
```

`cloudkit-transcribe` is a thin shell wrapper. Inputs any audio format ffmpeg understands (.oga / .ogg / .mp3 / .m4a / .wav / .webm / .opus). Outputs plain text on stdout.

## Whisper model choices

| Model | Disk | RAM (inference) | Speed (t4g.small) | Accuracy |
|---|---|---|---|---|
| `tiny.en` | ~75 MB | ~125 MB | very fast | ok-ish |
| `base.en` (default) | ~150 MB | ~250 MB | ~real-time | good |
| `small.en` | ~470 MB | ~600 MB | 0.5x real-time | very good |
| `medium.en` | ~1.5 GB | ~1.7 GB | 0.2x real-time | excellent |

For a 2 GB VM running Postgres + Claude bursts, `base.en` is the sweet spot. Switch to `small.en` if you have headroom and care about accuracy on accented speech.

The install script accepts `--model <name>` (defaults to `base.en`). Multiple models can coexist; `cloudkit-transcribe` uses the one named in `~/.cloudkit/voice.env` (or `WHISPER_MODEL` env, or the install-time default).

## What this skill provisions

```
/opt/whisper.cpp/                      # built-from-source, ARM-NEON
  ├── build/bin/whisper-cli
  └── models/ggml-base.en.bin          # ~150 MB (or whichever --model was chosen)
/usr/local/bin/cloudkit-transcribe     # the wrapper script
```

Plus apt packages: `build-essential`, `cmake`, `ffmpeg`, `git`. Total disk overhead: ~250 MB.

## Usage

### From the channel handler (Telegram path, automated)

The `channel-setup` v0 handler detects `msg["voice"]` and calls the wrapper. No user-facing intervention required.

### Standalone (CLI testing)

```bash
cloudkit-transcribe /tmp/somefile.ogg
# → "Hey, I was thinking about the Acme deal..."
```

### Different model (if installed)

```bash
WHISPER_MODEL=small.en cloudkit-transcribe /tmp/somefile.ogg
```

## Pitfalls

- **Empty audio / pure tones** — whisper.cpp returns descriptive guesses (`(soft music)`, `(eerie tones)`) rather than blank. The handler should accept these gracefully; for a strictly-empty input, treat the response as "no speech detected" and reply with a hint instead of feeding to Claude.
- **Long audio (>5 min)** — base.en transcription is real-time-ish on t4g.small; a 5-minute voice note takes ~5 minutes wall-clock. The handler's CLAUDE_TIMEOUT applies AFTER transcription, so total budget = transcribe time + claude time. Bump `CLAUDE_TIMEOUT` if users send long notes.
- **Multilingual users** — `base.en` is English-only. For mixed-language teams, swap to `base` (no `.en` suffix; multilingual). Trades a small accuracy hit on English for any-language coverage.
- **Telegram voice notes are .oga (Ogg Opus)** — ffmpeg handles these natively. If you ever see "no decoder for opus", the apt-installed ffmpeg is missing libopus; fix with `apt install ffmpeg libavcodec-extra`.
- **Audio uploads from non-microphone sources** — Telegram message types: `voice` (microphone-recorded ogg), `audio` (uploaded files like .mp3), `video_note` (round videos with audio). v0 handles `voice` only; `audio` + `video_note` are roadmap (same wrapper, different download path).

## What this skill does NOT do

- **Doesn't do TTS (text-to-speech)** — that's a separate skill (Coqui TTS, Piper, or 11labs API).
- **Doesn't do speaker diarisation** — single speaker assumed.
- **Doesn't translate** — `cloudkit-transcribe` only transcribes. For translate-then-transcribe, swap whisper-cli args.
- **Doesn't auto-improve over time** — whisper.cpp is a static model. If you need fine-tuning, that's a different toolchain entirely.
- **Doesn't cache transcripts** — every call re-transcribes. For idempotency, the channel handler could hash audio and check Postgres first; not implemented in v0.

## Roadmap

- **Voice-out / TTS** — once we have voice-in working, the natural follow-on is TTS replies for hands-free use
- **`audio` + `video_note` Telegram message types** — handler hooks for non-voice audio uploads
- **Discord voice channels** — Discord's voice protocol is different; needs the Discord adapter from `channel-setup` to also handle voice channels
- **Caching** — content-hash → transcript map in Postgres so repeated audio doesn't re-transcribe
- **Live transcription** (streaming whisper) — for "hold to talk" interfaces with real-time feedback
- **Larger models on larger VMs** — `medium.en`/`large-v3` are dramatically better; the cost is 4-8 GB RAM and longer inference. Recommend bumping VM tier before installing.


## Related

- **Canonical source**: [selrai-company/rodolfo-cloudkit-research/skills/voice-transcription/](https://github.com/selrai-company/rodolfo-cloudkit-research/tree/main/skills/voice-transcription)
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) — upstream
- [Whisper paper / models](https://github.com/openai/whisper) — OpenAI's original; whisper.cpp is the C++ port we use
