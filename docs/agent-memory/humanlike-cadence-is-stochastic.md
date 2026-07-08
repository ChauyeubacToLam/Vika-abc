---
name: humanlike-cadence-is-stochastic
description: "Vika design principle: no user-facing cadence may be a fixed counter — use probability draws with hunger shaping"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ebc40088-f01d-40be-90cc-4f611d79bad5
---

Anything in Vika that mimics human behavior (voice cues, coaching cadence, encouragement) must never fire on a fixed interval ("every 3 reps", "every 5s"). Use a probability draw per eligible event, shaped by hunger (chance rises the longer the cue has been silent) with a relief valve near certainty. Deterministic is reserved for causality (reacting to a user's action) and structure (setup, completion, safety).

**Why:** Nam, 2026-07-07, on the voice-coach cooldowns: "nothing in real life is predictive as cooldown every 3 reps" — fixed counters read as robotic; real PTs are random with soft bounds.

**How to apply:** When specifying any recurring user-facing behavior, define base chance + hunger bonus + hard rules, not cooldown constants. First applied in docs/reference/voice-coach/voice-behavior-spec.md.
