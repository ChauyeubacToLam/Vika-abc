# docs/

Map of Vika's knowledge base. The agent grounding rules in CLAUDE.md point here.

## Spine (read these)
- **state.md** — current status snapshot: focus, top todos, blockers. Living, rewritten at checkpoints,
  not appended. Currently overdue for a hygiene pass.
- **canonical-numbers.md** — single source of numeric truth (technical): thresholds, pose specs,
  anti-cheat, session/summary/progress, engine, ML. Read before quoting any number. Business/pricing
  numbers live in `~/vika-ops/`, not here.
- **decisions.md** — append-only decision ledger + rationale. `git log` is the append history now. Mark
  entries superseded, never delete.

## reference/
Durable system-design docs, kept next to the code they describe. Current set: Supabase schema, push-up
anti-cheat (also the first exercise-build skill exemplar), recommendation engine, ui-real-logic spec,
Premium Ivory wiring. Some are UNVERIFIED, confirm against code before trusting.

## archive/
Superseded material kept for provenance, not active truth: old agent task reports, and the original
chat-era Project Instruction (superseded by CLAUDE.md).

## Not in docs/
- **CLAUDE.md** (repo root) — the agent manual: how we work (Part 1) + codebase map (Part 2).
  `AGENTS.md` is the same file for Codex.
- **~/vika-ops/** — business, compliance, vision, pricing. Outside the repo; devs never see it.

Precedence on conflict: canonical-numbers > state > reference. Flag conflicts, don't pick silently.
