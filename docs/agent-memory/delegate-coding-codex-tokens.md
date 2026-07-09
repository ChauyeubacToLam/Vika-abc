---
name: delegate-coding-codex-tokens
description: "Model division of labor — Fable thinks \"what\", Opus designs \"how\" in lavish, Codex implements; Opus never drafts code (tokens tight)"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c850c97d-4be2-47b3-87f6-f0d3f651280d
---

From 2026-07-08: Nam's standing division of labor across models. Opus's value is design
judgment, not typing — so Opus stops drafting code.

**The three tiers:**
- **Fable** = thinking / *what should we do* — plain-English ideas, options, brainstorming.
- **Opus (me)** = *how should we do it* — the design/spec, written in lavish HTML (per
  [[learning-docs-use-lavish-html]]). This is my main output for a build task, not code.
- **Codex** = implementation — writes the actual code from the spec.

**Why:** Opus tokens are tight and Opus's leverage is the "how" (architecture, tradeoffs,
review), not producing keystrokes. Nam still reviews every line regardless — his correctness
ownership is unchanged.

**How to apply:**
- Don't draft non-trivial code with Opus. For a build task, produce the lavish "how" doc.
- "What"/ideation → spawn a Fable subagent (Agent tool, model: fable) for plain-English options.
- Implementation → Codex. Codex is a VS Code extension Nam runs; there is no Codex tool in the
  Claude Code session, so I hand off the spec and he runs it in the extension. Deliver the spec
  inline in chat (or a scratch spot Nam names) — NOT `docs/reference/`, which is durable system
  knowledge, not a spec store (see [[references-are-system-knowledge-not-specs]]).
  Sonnet is the fallback drafter (model-pinned subagent) if Codex is unavailable.
- Trivial one-line edits / doc tweaks are still fine inline — the point is token cost.
- Overrides CLAUDE.md Part 1 "Delegation" ("You write all code"). Fold into CLAUDE.md once Nam
  confirms the workflow is stable.
