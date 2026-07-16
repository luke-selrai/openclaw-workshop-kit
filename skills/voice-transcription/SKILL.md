---
name: voice-transcription
description: "Transcribe local audio files into text using a self-hosted Whisper model - no audio leaves the user's machine, no API key, no per-minute cost. Use this skill when the user asks to transcribe a voice memo, dictate notes from an interview recording, get text out of an `.m4a` / `.mp3` / `.ogg` / `.oga` / `.wav` / `.webm` audio file, or says things like 'transcribe this for me', 'turn this voice note into text', 'I have a recording I need typed up', or 'install Whisper'. On first use, walk the user through the one-time install (whisper.cpp + ffmpeg + a Whisper model). After install, they can run `voice-transcribe <audio-file>` from a terminal or ask Claude to transcribe a path."
allowed-tools: Bash, Read, Write, Edit
metadata:
  category: Productivity & Integrations
  tags:
    - whisper
    - speech-to-text
    - transcription
    - audio
    - self-hosted
    - voice
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting whisper.cpp build or model-download failures
    - skill: first-run-setup
      reason: Same one-time-setup-then-use pattern; aimed at non-technical users
---

# Voice Transcription

## Overview

This skill installs a self-hosted speech-to-text tool on the user's laptop using **whisper.cpp** (the C++ port of OpenAI's Whisper model). After install, a single command turns audio files into text - locally, no internet round-trip, no API costs.

It has **one phase**: the install walkthrough. After install, the user runs `voice-transcribe <audio-file>` from any terminal, or asks Claude to transcribe a path. There's no MCP server, no Phase 2 - just a CLI tool the user (or any Claude session) can invoke whenever audio needs to become text.

**Which platforms** - macOS and Linux are first-class. Windows users should run this from WSL2 (Windows Subsystem for Linux) since whisper.cpp's build relies on standard POSIX tooling (`bash`, `cmake`, `apt` or `brew`).

### What this skill does

- Installs the build dependencies (`cmake`, `ffmpeg`, `git`, a C++ compiler)
- Clones and builds whisper.cpp into `/opt/whisper.cpp` (Linux) or `~/whisper.cpp` (macOS, since `/opt` typically isn't writable on Mac)
- Downloads a Whisper model (default: `base.en` - ~150 MB, English-only, good accuracy, real-time-ish on most laptops)
- Installs a small CLI wrapper at `/usr/local/bin/voice-transcribe` so the user can call it from anywhere

### What this skill does NOT do

- **Doesn't send audio to OpenAI, Anthropic, or any cloud API.** Everything runs on-device.
- **Doesn't do TTS (text-to-speech).** That's a different toolchain entirely.
- **Doesn't transcribe in real time** as audio is being recorded. It works on existing audio files.
- **Doesn't perform speaker diarisation** ("Speaker 1 said... Speaker 2 said..."). Single-speaker model.
- **Doesn't translate** - it transcribes audio in its source language. (For multilingual content, swap the model: use `base` instead of `base.en`.)

## When to trigger

- "Transcribe this voice note for me"
- "I have an interview recording I need typed up"
- "Get the text out of this `.m4a` / `.mp3` / `.ogg` / `.wav` / `.webm`"
- "Install Whisper on my laptop"
- "Set up local speech-to-text"

Do NOT trigger for:
- Live dictation while the user speaks (this skill works on existing files only)
- TTS / making the computer talk (different skill)
- Translation between languages (different toolchain)

## Phase 1 - Install (first-run only)

Skip this phase if `voice-transcribe` is already on `PATH` (run `which voice-transcribe`; if a path comes back, the user already installed it - go to "Use" below).

### Step 1 - Confirm platform

Detect the user's OS:

- **macOS** (Darwin) → use Homebrew. If `brew` isn't installed, point them at https://brew.sh and stop.
- **Linux** (Ubuntu/Debian) → use `apt`. The user will need `sudo` once.
- **Windows** → tell them: "Whisper's build needs Linux-style tooling. Open WSL2 (the Ubuntu app from the Microsoft Store), then run this skill again from there. Your Windows files are reachable from WSL at `/mnt/c/...`."

### Step 2 - Run the installer

From inside the kit:

```bash
cd ~/.loup/selr-ai/workshop-kit/skills/voice-transcription   # or wherever they cloned the kit
./install.sh                                   # macOS - runs as the user
sudo ./install.sh                              # Linux - needs root for /opt + apt
```

The installer:
1. Installs `cmake`, `ffmpeg`, `git`, and a C++ compiler (apt on Linux, brew on macOS).
2. Clones whisper.cpp.
3. Builds it (cmake; takes 2-5 minutes on a typical laptop).
4. Downloads the `base.en` model (~150 MB) into the build dir.
5. Installs the `voice-transcribe` wrapper at `/usr/local/bin/`.
6. Runs a 2-second sine-wave smoke test (Whisper outputs `(eerie music)` or similar - that's expected for pure tones, not a bug).

Pick a different model with `--model`:

```bash
./install.sh --model small.en      # ~470 MB, more accurate, slower
./install.sh --model tiny.en       # ~75 MB, less accurate, fastest
./install.sh --model medium.en     # ~1.5 GB, near-state-of-the-art, slowest
./install.sh --model base          # ~150 MB, multilingual (no .en suffix)
```

### Step 3 - Verify

```bash
which voice-transcribe                 # → /usr/local/bin/voice-transcribe
voice-transcribe --help                # (the wrapper prints its usage line)
```

If `voice-transcribe` isn't found, the user's `PATH` likely doesn't include `/usr/local/bin/`. Tell them to open a fresh terminal (most shells re-read PATH on new sessions).

## Use (everyday)

Once installed, the wrapper accepts any audio format ffmpeg understands:

```bash
voice-transcribe ~/Downloads/voice-memo.m4a
voice-transcribe interview.mp3
voice-transcribe team-call.webm > transcript.txt
```

It prints the transcribed text to stdout. Pipe it, redirect it, copy it - whatever the user needs.

To pick a different model at call time (without reinstalling):

```bash
WHISPER_MODEL=small.en voice-transcribe ~/Downloads/quiet-recording.m4a
```

For Claude to transcribe a file the user mentions, run the wrapper via the Bash tool and capture stdout.

## What can go wrong

| Symptom | Likely cause | Fix |
|---|---|---|
| `voice-transcribe: command not found` | `/usr/local/bin/` not on `PATH`, or installer didn't complete | Open a fresh terminal; re-run `which voice-transcribe`. If still missing, re-run `./install.sh`. |
| Empty transcription on an audio with clear speech | Wrong language for the model (e.g. Spanish through `base.en`) | Re-install with `--model base` (multilingual) or `--model small`. Or set `WHISPER_MODEL=base` at call time. |
| `(eerie music)` or other phantom output | Whisper falls back to descriptive guesses on near-silent audio | Check the audio actually has speech: `ffplay <file>` or open in QuickTime / VLC. |
| `apt-get install` fails on Linux: `libavcodec-extra` missing | Some Ubuntu minimal images strip codecs | `sudo apt install ffmpeg libavcodec-extra` then re-run installer. |
| Build fails on macOS: `xcrun: error: invalid active developer path` | Xcode Command Line Tools not installed | `xcode-select --install`, then re-run installer. |
| Long-running installer hangs at "Build whisper.cpp" | cmake compiling on slower laptops takes 5+ min, especially first run | Wait. The build is single-threaded by default; it will finish. Subsequent installs are no-ops if the binary already exists. |
| User on Windows running `./install.sh` directly | Windows shell can't run bash + cmake/apt-style installs | "You're on Windows - open WSL2 (Ubuntu from the Microsoft Store), then re-run this from inside it." |

## Uninstall

```bash
sudo rm -f /usr/local/bin/voice-transcribe   # (no sudo on macOS if installed without it)
sudo rm -rf /opt/whisper.cpp                 # Linux
rm -rf ~/whisper.cpp                          # macOS
# Don't auto-remove apt/brew packages - they may be used by other things.
```

## Tone for the user

Plain English on first install. The user has likely never heard of "whisper.cpp", "ffmpeg", "cmake", or "MCP". You're installing a thing that lets them say "transcribe this" and get text. Use those words when explaining what's happening:

- ❌ "I'll clone whisper.cpp from GitHub, build it with CMake, and download the ggml-base.en.bin model weights."
- ✅ "I'm going to install a transcription tool on your laptop. It runs locally - no audio gets sent to anyone. The whole install takes about 5 minutes; most of that's the build step. I'll let you know when it's ready."

Once it's working:

- ❌ "Run `voice-transcribe /path/to/audio` to invoke whisper-cli on a 16kHz-resampled WAV."
- ✅ "All set. To transcribe an audio file, just say 'transcribe this voice memo' and tell me the path - or run `voice-transcribe <filename>` in a terminal. It'll print the text right back to you."
