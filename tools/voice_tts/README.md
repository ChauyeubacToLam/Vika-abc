# Voice TTS generator

`generate.py` is the one tool for producing Vika coaching audio — downloading a
whole fleet re-record or making a single new recording. It uses **vclip TTS
(Chi Mai voice)**, converts the result to the fleet mp3 spec, and drops each
file at its exact `assets/audio/<path>`.

Replaces the dead `tools/download_tts.dart` (Viettel, service removed).

## Setup (once)

```bash
brew install ffmpeg          # or your platform's ffmpeg
export VCLIP_KEY='sk_live_...'   # your vclip API key — NEVER commit it
```

The Chi Mai voice id is the default. Override per run with `VCLIP_VOICE_ID=...`
(or `VCLIP_SPEED=1.1`).

## The two ways to use it

### 1. Re-record / fill the fleet from the master table

The wordings live in
[`docs/reference/voice-coach/missing-audio.md`](../../docs/reference/voice-coach/missing-audio.md)
— the **MASTER RECORD LIST** table, one row per file:
`| # | <path> | <Vietnamese line> | <status> |`.

Edit a line there (or add a row), then:

```bash
# dry run first — prints every (path, text), calls nothing:
python3 tools/voice_tts/generate.py

python3 tools/voice_tts/generate.py --go                 # generate all
python3 tools/voice_tts/generate.py --go --only squat    # one exercise
python3 tools/voice_tts/generate.py --go --force         # overwrite existing
```

It **skips files that already exist** (so re-running only fills gaps) unless
`--force`. A missing file is a safe no-op in-app, so a partial batch is fine.

### 2. One-off new recording(s)

For a line not (yet) in the table:

```bash
python3 tools/voice_tts/generate.py --go \
  --line 'squat/trunk_reminder.mp3=Lần này bạn nhớ hướng ngực lên nhé.' \
  --line 'v_up/knee_reminder.mp3=Lần này bạn nhớ giữ chân thẳng gối nhé.'
```

`relpath` is relative to `assets/audio/`. Note the odd folder mappings baked
into paths (e.g. `mc_gill_curl_up/`, `jump_squat/set_up position.mp3`).

## Output spec

64 kbps / 24 kHz / mono mp3 — matches every existing recording, keeps the app
bundle small. Set by `MP3_BITRATE` / `MP3_RATE` / `MP3_CHANNELS` in the script.

## Recording conventions

Wordings follow the persona + copy craft: coach = **Vika**, user = **bạn**;
external-focus phrasing (verb + concrete target), positive framing, `nhé`
softening. Fixed patterns — soft: `Tốt, bạn [action] chút nữa là đẹp.`;
reminder: `Lần này bạn nhớ [action] nhé.` See
[`voice-research-rules.md` §3d](../../docs/reference/voice-coach/voice-research-rules.md)
and the [`voice-copy` skill](../../.agents/skills/voice-copy/SKILL.md).
