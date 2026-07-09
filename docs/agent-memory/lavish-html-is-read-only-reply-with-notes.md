---
name: lavish-html-is-read-only-reply-with-notes
description: "Lavish review HTML is Nam's read-only surface; agent replies via notes (anchored highlights), never by editing the HTML, and never reads Nam's notes unless told"
metadata:
  node_type: memory
  type: feedback
---

The lavish review HTML is **Nam's review surface, treated as read-only by the agent.** Three rules,
learned the hard way on the glute-bridge×voice review (2026-07-08) after I edited the doc freely:

1. **Don't change the HTML without asking + a yes.** Content edits AND layout/warning fixes. The doc
   is for Nam to read and annotate; if something needs changing, ask first, wait for the go.
2. **Reply to a note by making a note.** The agent's channel back into the doc is the notepad, not
   the review body. Add a note (optionally anchor-highlight the exact sentence/code being answered to
   clarify). Never bake agent commentary as callouts interleaved into the review.
3. **Don't read Nam's notes unless he explicitly says so** ("read my notes", "reply to note X"). The
   poll DOM snapshot surfaces all his notes every time he sends feedback — leave them alone until told.
   His notes are his private thinking, not the agent's task queue. Act only on explicit instructions/prompts.

**One carve-out (Nam 2026-07-08): sync-to-code after landing.** A lavish doc is a walkthrough of how the
code works RIGHT NOW, so it goes stale when that code changes. The read-only rule covers review + decision
time (while Nam is reasoning over it). Once the CODE it explains actually LANDS, update the lavish HTML to
match the shipped behavior. Standing permission for that case only. Decisions alone (pre-code) never touch
the lavish doc; a code change does. This does not license content edits while a review is open.

**Why:** the review is HIS to read and reason over. Agent edits interleaved into it corrupt the reading
surface and pre-empt his thinking; auto-answering his margin notes hijacks his own annotation process.
Notes keep agent commentary as a separate, dismissable layer he pulls on when ready. But a walkthrough
that lies about the current code is exactly the stale-context rot we're killing, so post-landing sync wins.

**How to apply:** after publishing a lavish review, only run the poll listener (`lavish-axi poll`). On
feedback, `--agent-reply` is fine for a quick banner, but a real reply-to-a-note = POST an agent-authored
note to the notes-server (`.lavish/notes-server.js`, :4599, keyed by doc title) with a `quote` anchor so
the page's highlightFirst badges the sentence/code, then let lavish live-reload surface it. `lavish-axi`
has no native "post a note" command, so this goes through the notes-server directly. Ask before any HTML edit.

Related: [[lavish-review-workflow]], [[reveal-diff-after-edits]].
