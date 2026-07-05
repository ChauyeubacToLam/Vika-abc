# Decisions — append-only ledger

Rationale for calls that aren't obvious from the code. Append new entries at the top. Mark superseded
entries, never delete them. `git log` is the fine-grained history; this is the "why", not the "what".

Template:
```
## YYYY-MM-DD · <short title>
Status: active | superseded by <entry>
Decision: <what we chose>
Why: <the reasoning, incl. Vietnamese-market angle if relevant>
Alternatives considered: <what we rejected and why>
```

---

## 2026-07-05 · docs/agent-memory/ is the shared cross-agent memory
Status: active
Decision: Claude Code's private auto-memory dir is symlinked to `docs/agent-memory/`, so Claude's
automatic capture/recall now lands in the repo, in git, where Codex (and any future agent) reads it via
`docs/agent-memory/MEMORY.md`. Routing rule added to CLAUDE.md § "Agent memory". Personal/sensitive
facts go in `private-*.md` (gitignored).
Why: One brain for every agent on the repo without new infrastructure. Files-in-git beats tool-private
silos and MCP memory servers on auditability (diff/review/provenance) and cost for a solo dev. Keeps
"one fact, one place": structured knowledge stays in its owning docs/ file; agent-memory holds ambient
learnings + working prefs only.
Alternatives considered: (a) docs/-only routing without sharing the auto-memory — cleaner but loses
Claude's frictionless self-capture; (b) MCP memory server (MemPalace/engram) — right for teams of
agents, overkill + un-auditable for one dev now; (c) exposing the auto-memory at its home path —
machine-specific, breaks on clone. Revisit MCP if 3+ agents enter rotation.
