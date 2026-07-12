---
name: voice-audio-tts-tool
description: "How any agent generates/downloads Vika coaching audio — tools/voice_tts/generate.py (vclip Chi Mai)"
metadata:
  node_type: memory
  type: reference
---

To generate or (re-)download ANY Vika voice line, call **`tools/voice_tts/generate.py`**. It speaks
each line through vclip TTS (Chi Mai voice), converts to the fleet mp3 spec (64k/24kHz/mono), and
writes it to its exact `assets/audio/<relpath>`. Zero setup: the API key auto-loads from the
gitignored repo-root `.env` (`VCLIP_KEY`).

One-off new line(s):
```
python3 tools/voice_tts/generate.py --go --line 'squat/heel.mp3=Bạn đạp gót chân xuống sàn nhé.'
```
Whole fleet / a gap, from the canonical wordings in
`docs/reference/voice-coach/missing-audio.md` (MASTER RECORD LIST table):
```
python3 tools/voice_tts/generate.py --go           # all; add --only <slug> to scope; --force to overwrite
```
Drop `--go` for a dry run (prints, calls nothing). Existing files are skipped unless `--force`; a
missing file is a safe no-op in-app, so partial batches are fine. Requires `ffmpeg` on PATH. Full
docs: `tools/voice_tts/README.md`. Wordings follow the [[voice-copy skill]] persona + copy craft.
Supersedes the dead `tools/download_tts.dart` (Viettel, service removed).
