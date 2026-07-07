---
name: reveal-diff-after-edits
description: After any code change, make it reviewable in Nam's VS Code Source Control — native diffs, never pasted into chat
metadata:
  type: feedback
---

Nam's workflow rule (CLAUDE.md § Delegation): he reads and signs off on *every line* an agent
writes. He reviews **in the VS Code IDE** (Source Control panel + editor gutter bars), NOT by reading
diffs pasted into chat. Do not dump big diffs into the reply — set up the IDE to show them.

**Why it isn't automatic here:** VS Code shows a diff only when git has a baseline. Two gaps:
untracked new files show no diff, and edits made on top of pre-existing uncommitted WIP can't be told
apart from that earlier work.

**Confirmed default (2026-07-06):** don't do per-turn baseline staging. Just `git add -N` new files
and let him review the whole uncommitted diff vs HEAD — the tree is one feature at a time, and he
reviews before committing anyway. The stricter per-turn isolation (step 2) is opt-in on request.

**How to apply — every time I change code:**
1. **New / untracked files → `git add -N <file>`** (intent-to-add). Makes them appear in Source
   Control with a real diff. Never changes file contents; `git reset -- <file>` undoes it. This is the
   default, do it every time.
2. **Opt-in only (he asks for it): per-turn isolation** — separate *this turn's* edits from earlier
   uncommitted work by running `git add -A` to stage a baseline **before** editing. Then this turn's
   edits are the unstaged "Changes" group + gutter bars. (Must be done *before* editing; can't isolate
   retroactively.)
3. **Offer a checkpoint commit** at the start of a code task when the tree is dirty — a clean tree
   makes `git diff HEAD` = exactly my delta. Commits need Nam's ok (CLAUDE.md § Ask first).
4. **Tell him where to look**, and flag honestly: if some edits landed in an already-dirty tracked
   file (this repo often has WIP in `person_detector.dart`, `decisions.md`), say those show *mixed*
   with prior work; untracked-new and clean-since-HEAD files show cleanly.

Fallback only when git genuinely can't isolate: a compact per-file `path:line → purpose` changelog.
Never a giant pasted diff. Related: [[lavish-review-workflow]] (lavish HTML for annotated walkthroughs).
