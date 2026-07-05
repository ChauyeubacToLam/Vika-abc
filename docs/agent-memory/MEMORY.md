# Memory index

Shared cross-agent memory. Every agent reads this at session start, then opens only the note it needs.
One line per memory below (no note bodies here). Notes named `private-*.md` are gitignored — local only.
Routing + conventions: see CLAUDE.md § "Agent memory".

- [Learning docs use lavish HTML](learning-docs-use-lavish-html.md) — plans / reports / codebase walkthroughs go to lavish HTML (verbatim code + ELI5 + suggestions), not MD
