#!/usr/bin/env python3
"""Generate Vika voice audio via vclip TTS (Chi Mai) → the fleet mp3 spec.

FOR AN AGENT (zero setup — the key auto-loads from the gitignored .env):
    # generate one or more new lines, each written to assets/audio/<relpath>:
    python3 tools/voice_tts/generate.py --go \\
        --line 'squat/heel.mp3=Bạn đạp gót chân xuống sàn nhé.'
    # or (re-)generate everything listed in missing-audio.md's master table:
    python3 tools/voice_tts/generate.py --go            # add --only <slug> to scope
    # drop --go for a dry run (prints what it WOULD do, calls nothing).
Existing files are skipped unless --force. See `--help`.

The single tool for downloading / (re-)recording coaching lines. It speaks
each line through vclip's async JSON-RPC API, converts the returned WAV to the
fleet's mp3 spec (64 kbps / 24 kHz / mono, matching every existing recording),
and writes it to its exact assets/audio/<path>. Re-runnable: skips files that
already exist unless --force. A missing file is a safe logged no-op in-app, so
partial batches are fine.

TWO SOURCES OF LINES
  1. The MASTER RECORD LIST table in
     docs/reference/voice-coach/missing-audio.md  (the canonical wordings).
     Every row `| N | <path> | <line> | <status> |` is generated. This is how
     you re-record the fleet or fill a gap: edit the table, run the tool.
  2. Ad-hoc one-offs via --line 'relpath=Vietnamese text' (repeatable), for a
     new line not yet in the table.

REQUIREMENTS
  - python3, ffmpeg on PATH
  - VCLIP_KEY env var = your vclip API key (NEVER commit it):
        export VCLIP_KEY='sk_live_...'
  - Chi Mai voice id defaults below; override with VCLIP_VOICE_ID.

USAGE
  python3 tools/voice_tts/generate.py                 # DRY RUN — print (path,text), call nothing
  python3 tools/voice_tts/generate.py --go            # generate everything in the table
  python3 tools/voice_tts/generate.py --go --only squat        # one exercise slug
  python3 tools/voice_tts/generate.py --go --force             # overwrite existing
  python3 tools/voice_tts/generate.py --go \
      --line 'squat/trunk_reminder.mp3=Lần này bạn nhớ hướng ngực lên nhé.'   # one-off(s)

Design notes: docs/reference/voice-coach/audio-naming-convention.md (paths),
missing-audio.md (wordings), voice-research-rules.md §3d (copy craft).
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time
import urllib.request
import urllib.error

# Repo root = two levels up from this file (tools/voice_tts/generate.py).
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MD = os.path.join(REPO, "docs/reference/voice-coach/missing-audio.md")
AUDIO = os.path.join(REPO, "assets/audio")


def _load_dotenv():
    """Populate os.environ from the repo-root .env (gitignored) so callers —
    including other agents — need zero setup. A real environment variable
    always wins; .env only fills what's unset. Silent if .env is absent."""
    path = os.path.join(REPO, ".env")
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))
    except FileNotFoundError:
        pass


_load_dotenv()

API_URL = "https://api-tts.vclip.io/json-rpc"
VOICE_ID = os.environ.get("VCLIP_VOICE_ID", "cLZiqtzLcKYqwYrWJemAJH")  # Chi Mai
KEY = os.environ.get("VCLIP_KEY", "")
SPEED = float(os.environ.get("VCLIP_SPEED", "1.0"))

# Fleet mp3 spec — matches every existing recording in assets/audio/.
MP3_BITRATE = "64k"
MP3_RATE = "24000"
MP3_CHANNELS = "1"

RATE_LIMIT_S = 1.0     # pause between calls (be nice to the API)
POLL_EVERY_S = 3
POLL_TIMEOUT_S = 180
RETRIES = 3


def rpc(method, inp):
    body = json.dumps({"method": method, "input": inp}).encode()
    req = urllib.request.Request(
        API_URL, data=body, method="POST",
        headers={"Authorization": f"Bearer {KEY}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = json.loads(r.read().decode())
    if "error" in data:
        raise RuntimeError(data["error"].get("message", str(data["error"])))
    return data["result"]


def to_mp3(wav_bytes):
    """vclip returns WAV; convert to the fleet mp3 spec so the .mp3 filename
    isn't a lie and bundle size stays small."""
    p = subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "wav", "-i", "pipe:0",
         "-codec:a", "libmp3lame", "-b:a", MP3_BITRATE, "-ar", MP3_RATE,
         "-ac", MP3_CHANNELS, "-f", "mp3", "pipe:1"],
        input=wav_bytes, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode != 0 or not p.stdout:
        raise RuntimeError(f"ffmpeg failed: {p.stderr.decode()[:200]}")
    return p.stdout


def synth(text):
    """Full async vclip flow (ttsLongText → poll → download) → mp3 bytes."""
    started = rpc("ttsLongText", {"text": text, "userVoiceId": VOICE_ID, "speed": SPEED})
    export_id = started.get("projectExportId") or started.get("id")
    if not export_id:
        raise RuntimeError(f"no projectExportId in: {str(started)[:200]}")
    waited = 0
    while waited < POLL_TIMEOUT_S:
        time.sleep(POLL_EVERY_S)
        waited += POLL_EVERY_S
        st = rpc("getExportStatus", {"projectExportId": export_id})
        state = (st.get("state") or st.get("status") or "").lower()
        if state == "completed":
            url = st.get("url") or st.get("audioUrl") or st.get("downloadUrl")
            if not url:
                raise RuntimeError(f"completed but no url: {str(st)[:200]}")
            return to_mp3(urllib.request.urlopen(url, timeout=90).read())
        if state in ("failed", "error"):
            raise RuntimeError(f"export {state}: {str(st)[:200]}")
    raise RuntimeError(f"poll timeout after {POLL_TIMEOUT_S}s")


def table_rows():
    """Parse the MASTER RECORD LIST → [(path, text), ...]."""
    txt = open(MD, encoding="utf-8").read()
    start = txt.index("| # | File")
    end = txt.index("### DO NOT record", start)
    out = []
    for line in txt[start:end].splitlines():
        m = re.match(r"\|\s*\d+\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|", line)
        if m:
            out.append((m.group(1).strip(), m.group(2).strip()))
    return out


def main():
    ap = argparse.ArgumentParser(description="Generate Vika voice audio via vclip (Chi Mai).")
    ap.add_argument("--go", action="store_true", help="actually synthesize (default is a dry run)")
    ap.add_argument("--force", action="store_true", help="overwrite files that already exist")
    ap.add_argument("--only", metavar="SLUG", help="limit table rows to one exercise slug")
    ap.add_argument("--line", action="append", default=[], metavar="relpath=TEXT",
                    help="one-off line, repeatable; bypasses the table")
    args = ap.parse_args()

    if args.line:
        rows = []
        for spec in args.line:
            if "=" not in spec:
                sys.exit(f"--line needs 'relpath=TEXT', got: {spec}")
            path, text = spec.split("=", 1)
            rows.append((path.strip(), text.strip()))
    else:
        rows = table_rows()
        if args.only:
            rows = [r for r in rows if r[0].startswith(args.only + "/")]

    if args.go and not KEY:
        sys.exit("No VCLIP_KEY. Add it to the repo-root .env (VCLIP_KEY=sk_live_...) "
                 "or export it. It auto-loads from .env — normally zero setup.")

    print(f"{len(rows)} line(s). mode={'SYNTH' if args.go else 'DRY-RUN'} "
          f"force={args.force} voice={VOICE_ID}\n")
    done = skip = fail = 0
    for i, (path, text) in enumerate(rows, 1):
        dest = os.path.join(AUDIO, path)
        if os.path.exists(dest) and not args.force:
            print(f"[{i:3}] skip (exists)  {path}"); skip += 1; continue
        if not args.go:
            print(f"[{i:3}] {path}\n        {text}"); continue
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        for attempt in range(1, RETRIES + 1):
            try:
                audio = synth(text)
                with open(dest, "wb") as f:
                    f.write(audio)
                print(f"[{i:3}] OK {len(audio):>7}B  {path}"); done += 1
                time.sleep(RATE_LIMIT_S)
                break
            except Exception as e:  # noqa: BLE001 — batch tool, keep going on any failure
                print(f"[{i:3}] try {attempt}/{RETRIES} FAIL {path}: {e}")
                if attempt == RETRIES:
                    fail += 1
                else:
                    time.sleep(2 * attempt)
    print(f"\ndone={done} skipped={skip} failed={fail}")
    if fail:
        sys.exit(1)


if __name__ == "__main__":
    main()
