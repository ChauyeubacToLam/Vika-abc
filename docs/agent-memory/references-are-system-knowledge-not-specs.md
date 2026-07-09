---
name: references-are-system-knowledge-not-specs
description: "docs/reference/ is durable MD topic knowledge for future models — NOT a dump for transient specs, Codex prompts, or one-off handoffs"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c850c97d-4be2-47b3-87f6-f0d3f651280d
---

From 2026-07-08 (Nam correction): I dropped a Codex handoff spec into
`docs/reference/voice-coach/`. Wrong — that folder is not a spec/prompt store.

**Why:** `docs/reference/` exists so a future model can reach in and understand how a specific
subsystem actually works — it's canonical, durable system knowledge. Mixing transient work
orders (specs, prompts, handoffs, one-off plans) into it pollutes that context and rots the
signal. A spec is a throwaway work artifact; reference docs are the system's description.

**How to apply:**
- `docs/reference/<topic>/` holds durable knowledge a future model reads to understand the topic:
  how the system works AND the research/evidence backing it (e.g. voice-research-rules.md lives
  there correctly). MD (± paired html). It maps to a subsystem/topic, not to a task.
- Transient Codex specs / prompts / handoff plans → hand inline in chat for Nam to paste into
  Codex, OR a scratch location Nam designates (docs/scratch/, gitignored). Never `docs/reference/`.
- The test before writing ANY file into `docs/reference/`: "would a future model read this to learn
  the topic (system design OR its research), or is it a one-off work order?" One-off → scratch, not
  reference. Durable topic knowledge, including research → reference is right.

Related: [[search-reference-docs-first]] (reading references), [[delegate-coding-codex-tokens]]
(the Codex handoff flow that produced this miss).
