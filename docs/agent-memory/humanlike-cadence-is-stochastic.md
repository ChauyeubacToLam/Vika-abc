---
name: humanlike-cadence-is-stochastic
description: "Vika design principle: no user-facing cadence may be a fixed counter — use probability draws with hunger shaping"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ebc40088-f01d-40be-90cc-4f611d79bad5
---

Anything in Vika that mimics human behavior (voice cues, coaching cadence, encouragement) must never fire on a fixed interval ("every 3 reps", "every 5s"). Use a probability draw per eligible event, shaped by hunger (chance rises the longer the cue has been silent) with a relief valve near certainty. Deterministic is reserved for causality (reacting to a user's action) and structure (setup, completion, safety).

Corollary (Nam, 2026-07-08): hard floors/caps/relief valves on stochastic behavior are **saturation guards, not schedulers**. Size them at the degenerate edge — the pathological case they exist to prevent (a whole set uncounted, a cue on every rep) — never tight enough to bind on a typical run. A guard that binds every time IS a fixed counter: the voice-coach count roll capped at 1.0 forced a count after only 2 skips and produced an audible alternating even-number rhythm. Fix: keep every draw a real draw (probability cap < 1.0) and put the guarantee only in a loose relief valve (count: forced after 6 straight silent counts).

**Why:** Nam, 2026-07-07, on the voice-coach cooldowns: "nothing in real life is predictive as cooldown every 3 reps" — fixed counters read as robotic; real PTs are random with soft bounds. Corollary 2026-07-08: a cap "shouldn't be so small it makes it predictable — just enough to prevent the degenerate case, keep the randomness."

**How to apply:** When specifying any recurring user-facing behavior, define base chance + hunger bonus + hard rules, not cooldown constants; size any hard bound so it almost never triggers on a typical run. First applied in docs/reference/voice-coach/voice-behavior-spec.md (principle 2 + corollary).
