---
name: research-runs-use-sonnet
description: "Web research runs on a single capped Sonnet agent, never the multi-agent deep-research workflow"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ebc40088-f01d-40be-90cc-4f611d79bad5
---

Research/verification legwork goes to ONE background Agent with `model: sonnet` and a hard tool-call cap (~20 web ops, no subagents). Do not use the deep-research workflow or Fable-tier fan-outs for it.

**Why:** 2026-07-07 the deep-research workflow spawned 103 agents / 755k tokens and still died on a session limit; Nam: "you burning my token". The main model's job is synthesis and architecture, not fetching.

**How to apply:** Hand the Sonnet agent any already-extracted material so it only verifies and fills gaps; have it write results to a file and return bullets. Related: [[learning-docs-use-lavish-html]].
