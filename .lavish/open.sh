#!/usr/bin/env bash
# HUMAN side of a lavish review: start the disk notes-server, open/resume the
# session, and launch the real /session/<key> URL in the browser.
#
# This does NOT run `lavish-axi poll`. poll is the AGENT's listening loop — it
# hands your queued browser messages to whatever process reads its output. Run
# in your terminal, nothing reads it, so messages hang. The agent (Claude Code /
# Codex) must run `lavish-axi poll <file>` in ITS OWN session to listen + reply.
#
# Usage:  .lavish/open.sh <path-to-html>          (run from anywhere)
# e.g.    .lavish/open.sh docs/reference/presence-gate/presence-pipeline-explained.html
#
# Then tell the agent: "listen on <file>" so it starts the poll on its side.
set -euo pipefail

F="${1:?usage: open.sh <path-to-html>}"
ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

# npx-cached lavish CLI (not on PATH; hash dir varies so glob it)
CLI="$(ls ~/.npm/_npx/*/node_modules/lavish-axi/dist/cli.mjs 2>/dev/null | head -1)"
[ -n "$CLI" ] || { echo "lavish-axi not found in npx cache"; exit 1; }

# Disk notes-server on :4599 — start only if it isn't already listening.
if ! lsof -iTCP:4599 -sTCP:LISTEN >/dev/null 2>&1; then
  node "$ROOT/.lavish/notes-server.js" >/dev/null 2>&1 &
  echo "[open] started notes-server on :4599"
fi

# Open/resume the session and launch the real /session/<key> URL (not file://).
# CLI emits the URL quoted (url: "http://..."); [^ "] stops the match before the
# trailing quote so `xargs open` doesn't die on an unterminated quote.
node "$CLI" "$F" | grep -oE 'http://127\.0\.0\.1:[0-9]+/session/[^ "]+' | head -1 | xargs open

echo "[open] session open. Now tell your agent: listen on $F  (it runs 'lavish-axi poll')"
