# Memory index

Shared cross-agent memory. Every agent reads this at session start, then opens only the note it needs.
One line per memory below (no note bodies here). Notes named `private-*.md` are gitignored — local only.
Routing + conventions: see CLAUDE.md § "Agent memory".

- [Learning docs use lavish HTML](learning-docs-use-lavish-html.md) — plans / reports / codebase walkthroughs go to lavish HTML (verbatim code + ELI5 + suggestions), not MD
- [Lavish review workflow](lavish-review-workflow.md) — launch session+chat+notepad cleanly first try; notes-server on :4599; the FAB-outside-body corruption gotcha
- [Reveal diff after edits](reveal-diff-after-edits.md) — after every editing turn, hand Nam a clean isolated diff + a "Changes this turn" changelog; raw git diff is contaminated by prior WIP
- [Research runs use Sonnet](research-runs-use-sonnet.md) — web research = one capped background Sonnet agent, never the deep-research workflow / Fable fan-outs
- [Humanlike cadence is stochastic](humanlike-cadence-is-stochastic.md) — no fixed-interval cooldowns for user-facing behavior; probability + hunger shaping, deterministic only for causality/structure/safety
- [Model division of labor](delegate-coding-codex-tokens.md) — Fable thinks "what", Opus designs "how" in lavish, Codex implements; Opus never drafts code (tokens tight)
- [Small fixes do yourself](small-fixes-do-yourself.md) — small/surgical code fixes (one-line bug, typo): edit directly + verify, don't route to Codex; the split is for non-trivial work
- [Search reference docs first](search-reference-docs-first.md) — before Vika implementation work, search the relevant docs/reference topic folder, including paired md/html artifacts
- [References are system knowledge, not specs](references-are-system-knowledge-not-specs.md) — docs/reference/ is durable topic knowledge for future models; transient Codex specs/prompts go inline or a scratch spot, never there
- [Voice audio TTS tool](voice-audio-tts-tool.md) — any agent generates/downloads coaching audio via tools/voice_tts/generate.py (vclip Chi Mai, key auto-loads from .env)
- [Catalog regen tool crashes](catalog-regen-tool-crashes.md) — generate_exercise_catalog.dart FFI-crashes in this env; regen by patching the JSON from prod via Supabase MCP
