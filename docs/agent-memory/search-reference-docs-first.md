---
name: search-reference-docs-first
description: "Before Vika implementation work, search the relevant docs/reference topic folder, including paired md/html artifacts"
---

# Search Reference Docs First

For Vika work, default to searching the relevant `docs/reference/` topic folder before changing code, especially when the user mentions that context lives in docs or HTML artifacts.

**Why:** Nam keeps implementation context, review notes, and evolving specs in paired `.md` and `.html` files under `docs/reference/`; those folders update constantly and often contain fresher intent than memory or code comments.

**How to apply:** Start with `rg` over `docs/reference/<topic>/` plus nearby owning docs (`docs/decisions.md`, `docs/state.md`, `docs/canonical-numbers.md` when numbers are involved). Prefer `.md` for source-of-truth text, use `.html` lavish artifacts for review context and annotated implementation guidance.
