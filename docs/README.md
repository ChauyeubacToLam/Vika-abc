# docs/

Map of Vika's knowledge base. The agent grounding rules in CLAUDE.md point here.

## Spine (read these)
- **state.md** — current status snapshot: focus, top todos, blockers. Living, rewritten at checkpoints,
  not appended. Currently overdue for a hygiene pass.
- **canonical-numbers.md** — single source of numeric truth (technical): thresholds, pose specs,
  anti-cheat, session/summary/progress, engine, ML. Read before quoting any number. Business/pricing
  numbers live in `~/vika-ops/`, not here.
- **decisions.md** — append-only decision ledger + rationale. `git log` is the fine-grained history;
  this holds the "why". Mark entries superseded, never delete.

## agent-memory/
Cross-agent memory store, read by every agent (Claude Code, Codex, …). `MEMORY.md` is a one-line index
over one-fact-per-file notes. Claude Code's private auto-memory dir is symlinked here, so its automatic
capture/recall lands in git for all agents. `private-*.md` notes are gitignored (personal/sensitive,
local only). Routing rules: CLAUDE.md § "Agent memory". This is ambient learnings + working prefs —
structured project knowledge still lives in its owning file above, not here.

## new-machine-setup.md
Fresh-MacBook runbook: toolchain (FVM/Flutter, Xcode, pods), clone, gitignored secrets to restore, and
the per-machine Claude Code agent-memory symlink. Plain markdown so it reads on a bare machine.

## reference/
Durable system-design docs, one folder per topic. Each folder holds that topic's markdown spec/report
and its lavish HTML explainer together (a spec and its walkthrough live side by side, not dumped flat).
Current folders: `agent-memory/`, `exercise-base/`, `presence-gate/` (spec + pipeline walkthrough),
`push-up/` (anti-cheat; also the first exercise-build skill exemplar), `recommendation-engine/`,
`scale-factor/`, `supabase-schema/`, `ui/` (Premium Ivory wiring + ui-real-logic spec). A new reference
doc goes in the matching topic folder — create one if none fits. Some are UNVERIFIED, confirm against
code before trusting.

**Scope — core/archetype references only, not every leaf feature.** Document the mechanics that
generalize, not one doc per instance. For exercises that means the *archetypes* — how a rep-based
exercise works, how a hold-based exercise works — NOT a reference doc for each individual exercise
(squat, glute bridge, …); those are leaves of an archetype already covered. Same test for any topic:
if a doc only re-describes one leaf of a pattern already documented here, it doesn't earn a folder.

## archive/
Superseded material kept for provenance, not active truth: old agent task reports, and the original
chat-era Project Instruction (superseded by CLAUDE.md).

## Not in docs/
- **CLAUDE.md** (repo root) — the agent manual: how we work (Part 1) + codebase map (Part 2).
  `AGENTS.md` is the same file for Codex.
- **~/vika-ops/** — business, compliance, vision, pricing. Outside the repo; devs never see it.

Precedence on conflict: canonical-numbers > state > reference. Flag conflicts, don't pick silently.
