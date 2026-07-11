---
name: small-fixes-do-yourself
description: "Small/surgical code fixes — do them yourself, don't route to Codex"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 65dccdc3-3077-477a-bd30-9084edc76863
---

Nam (2026-07-10): "if it's small enough you can fix it yourself, you don't need Codex — that's the rules."
The Codex-writes-code / Opus-designs split ([[delegate-coding-codex-tokens]]) is about NON-trivial
production work; a small surgical fix (a one-line message/direction bug, a typo, an obvious off-by-one)
you just make directly.

**Why:** routing a one-liner through a Codex spec is pure overhead — slower, more tokens, no added
correctness on something this small. The delegation rule exists to conserve tokens on big work and keep
review legible, not to forbid Claude from ever touching Dart.

**How to apply:** if the fix is small, unambiguous, and low-risk, edit the code yourself and verify
(analyze/test). Still surface 2+ interpretations if the fix is ambiguous, and still hand Codex the
larger changes. Example: fixed the glute_bridge knee_angle >140° branch (feet-too-far told the user to
move feet further — wrong direction) directly instead of spec'ing it.
