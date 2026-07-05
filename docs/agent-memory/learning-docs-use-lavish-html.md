---
name: learning-docs-use-lavish-html
description: "Deliver plans, reports, and codebase-learning docs as lavish HTML artifacts, not markdown"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b0c914cf-1697-4e59-820e-b392fdae187b
---

When Nam asks for a plan, a report, or help learning the codebase, produce a rich HTML artifact via the lavish skill (installed at `~/.agents/skills/lavish`, CLI `npx -y lavish-axi <file>`) — not a markdown file.

**Why:** He reviews visually and wants to annotate the page and send feedback through lavish's review loop; MD reports don't support that.

**How to apply:** Build the HTML at `.lavish/<name>.html`. Match the subject project's design system — for Vika that's Premium Ivory (ink #1F1812, ivory #FBF7EE, yellow #FFB701 accent-only, single font Be Vietnam Pro). For codebase-learning docs he wants VERBATIM code blocks reviewable line-by-line (exact code with real line numbers), ELI5 explanations, and improvement suggestions — not just prose ideas. Note: `npx lavish-axi` needs Bash permission (external package, denied in auto mode); surface that and let him approve or run it himself. Related: [[[exercise-base-refactor]]].
