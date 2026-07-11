---
name: lavish-review-workflow
description: "How to launch a lavish review HTML cleanly (session + chat + notepad first try) and run its disk notes-server"
metadata:
  node_type: memory
  type: reference
---

Launching a lavish review doc so Nam gets the full surface (agent chat + in-page notepad) on the first try:

1. Do NOT `open` the raw HTML file. A bare `file://` page has no lavish chrome (so no agent chat) and does not run the review loop.
2. `lavish-axi <file>` opens/resumes a session and prints a `http://127.0.0.1:<port>/session/<key>` URL. The lavish server runs persistently — find it with `lsof -iTCP:<port> -sTCP:LISTEN` (it was :4387). If `lavish-axi` isn't on PATH, invoke the npx-cached CLI directly: `node ~/.npm/_npx/*/node_modules/lavish-axi/dist/cli.mjs <file>`.
3. `open` that `/session/<key>` URL. The chat is lavish's right-side chrome; the artifact + notepad render in a sandboxed iframe (`sandbox="allow-scripts allow-forms allow-popups allow-downloads"`, no allow-same-origin).
4. Run `lavish-axi poll <file>` in the background so browser feedback reaches the agent. Leave it running.

TWO ACTORS, don't conflate them (this bit us): `lavish-axi poll` is the AGENT's listening loop, not
a relay you can run in the human's terminal. poll long-polls the server and hands each queued browser
message to whatever process reads its STDOUT — and it REMOVES the message from the queue on handoff.
Run poll in the human's shell and the message is delivered to that shell (a dead end) and lost; the
human sees no answer. The agent (Claude Code / Codex) must run `lavish-axi poll <file>` inside ITS OWN
session (background task) so messages reach it, then reply here and re-poll.

Split accordingly:
- Human side: `.lavish/open.sh <file>` (globs the npx-cached CLI not on PATH, starts notes-server on
  :4599 if down, opens the real `/session/<key>` URL). It does NOT run poll.
- Agent side: run `lavish-axi poll <file>` as a background task and read its output.
Only one poller per doc — a second poll steals messages from the first.

Nam's one-word trigger: he opens the HTML in his IDE, then says `lavish` (or `/lavish`). The
`/lavish` slash command (.claude/commands/lavish.md) encodes the whole flow: resolve the target
(=$ARGUMENTS, else the file open in the IDE via the latest `<ide_opened_file>` signal), run open.sh
for the human side, then start the poll in the AGENT's own session (background) and answer here. So
"everything set up" is one message to the agent, not a shell command — the agent that runs poll IS
the reviewer.

Notepad = the 🖊 Notes FAB, bottom-right of the iframe. It's self-contained JS baked into each HTML and needs no server to appear. Disk persistence is optional: `node .lavish/notes-server.js` (port 4599, run in background). The server now keys notes by doc title into one `.lavish/lavish-notes.json`; the old version wrote a single flat array that got clobbered when a second doc was opened.

GOTCHA that makes the FAB never appear: the notepad snippet ships wrapped in an install-comment ("1. paste inside `<style>` … 3. paste just before `</body>`"). If the leading `<!--` is lost when the snippet is pasted into a doc, that instruction text (including literal `<style>` and `</body>`) leaks as real markup and shoves the NP:MARKUP/NP:SCRIPT blocks *outside* `<body>`, so the button never mounts. Fix: keep the install-comment intact and confirm the notepad markup + script sit inside `<body>` (one `</body>`, at the very end). Hit once in `presence-pipeline-explained.html`.

AUTHORING A NEW doc from scratch (2026-07-09): lavish-axi does NOT inject the notepad — you must embed it, or Nam can't save notes (he'll say the notes won't save / can't upload "inside the files"). Simplest: splice the notes-layer CSS block (insert before `</style>`) plus the markup+script (insert before `</body>`) from a working doc like `glute-bridge-voice-review.html` — a `python` line that finds the `/* ===== personal notes layer` and `<!-- ===== personal notes layer` markers and splices is clean and byte-exact. Then rename that script's `KEY` / `NAMEKEY` localStorage constants to be doc-specific so `window.name` can't cross-contaminate notes between docs (disk persistence already isolates by `document.title`). Verify end-to-end: `curl :4599/notes?doc=<url-encoded document.title>` should round-trip. AND: when Nam says "fix the overflow," fix the overflow — do NOT delete the notepad (I over-corrected and removed his whole notes layer chasing a phantom conflict; the real issue was just a CSS overflow).

Related: [[learning-docs-use-lavish-html]].
