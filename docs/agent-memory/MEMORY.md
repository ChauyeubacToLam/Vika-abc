# Memory index

Shared cross-agent memory. Every agent reads this at session start, then opens only the note it needs.
One line per memory below (no note bodies here). Notes named `private-*.md` are gitignored — local only.
Routing + conventions: see CLAUDE.md § "Agent memory".

- [Learning docs use lavish HTML](learning-docs-use-lavish-html.md) — plans / reports / codebase walkthroughs go to lavish HTML (verbatim code + ELI5 + suggestions), not MD
- [Lavish review workflow](lavish-review-workflow.md) — launch session+chat+notepad cleanly first try; notes-server on :4599; the FAB-outside-body corruption gotcha
- [Reveal diff after edits](reveal-diff-after-edits.md) — after every editing turn, hand Nam a clean isolated diff + a "Changes this turn" changelog; raw git diff is contaminated by prior WIP
