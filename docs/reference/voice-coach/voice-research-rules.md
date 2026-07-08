# Voice coach feedback-schedule research

## 1. How a real PT behaves rep-by-rep

Silence is the default state, not a gap to fill. Observational studies of elite strength & conditioning
coaches show the single most common behavior during a weight-room session is silent monitoring
(~22% of coded time) — more than any verbal category. The next most common behavior is
organizational/management talk (running the session), and only in third place is a verbal
"hustle" cue ("push", "one more", "let's go") at ~11%. Actual technical correction is a minority
slice of total behavior, not a per-rep event. When a coach does speak mid-set, it's for one of a
few narrow reasons: a short intensity cue during a grinding rep; a correction when a fault crosses
a visible threshold (they don't comment on every minor wobble, only once it matters — "bandwidth"
feedback); or a confirmation after a clean rep ("there it is"), which coaches give more readily than
they correct bad ones, since confirming success is more motivating and doesn't create dependency.
Coaches also front-load their talking: more cueing early while a lifter is learning a new pattern or
early in a session, tapering off as the set or program progresses and reps groove — silence itself
becomes the "you're doing it right" signal. They rarely repeat the identical correction rep after
rep; they cue once, watch for compliance, and only re-cue if the fault persists. The richest,
most information-dense feedback a real PT gives is the between-set or end-of-set comment, not a
running commentary — this mirrors lab findings that terminal/summary feedback beats constant
per-trial feedback for retention. And real coaches under-praise relative to a "cheer every rep" bot:
praise that isn't guaranteed sustains effort-seeking longer than praise you can predict.

## 2. Design-rules table

| Rule | Value to encode | Confidence | Citation |
|---|---|---|---|
| Default state | Silence/monitoring is the default; no voice cue unless a specific trigger fires (fault crosses threshold, milestone rep, or set end) | High | Elite S&C coach observation, silent monitoring 21.99% of coded behavior, most frequent single behavior (Miller & Berry-type ASU coaching-observation study), PubMed 12173963 |
| Hustle/general-encouragement cues | Reserve short intensity cues ("push", "one more") for genuinely effortful reps (e.g. last 1-2 reps of a set); don't use them as filler | High | Same source: "hustle" (verbal intensify-effort statements) = 11.12% of coded behavior, 3rd most frequent overall |
| Corrective cooldown, same fault | Don't re-cue the identical fault on the very next rep. Cue once, then hold; only re-cue if the fault is still present after 1 full rep of "wait and see" (bandwidth logic — only escalate if error is still outside tolerance) | Med | Bandwidth-feedback literature: missing/absent feedback functions as implicit reinforcement when performance is within tolerance (bandwidth-KR reviews, ScienceDirect/Atlantis Press summaries); guidance hypothesis (Salmoni et al. 1984) against constant correction |
| Praise probability per clean rep | Intermittent, not guaranteed — target roughly 30-50% of clean reps, on an unpredictable (variable-ratio) schedule rather than fixed interval | Med (mechanism) / Low (the exact %, which is a product default, not from a sport-specific study) | Variable-ratio reinforcement produces the highest, most persistent response rates vs. continuous reinforcement (behavioral-psych + habit-app design literature); caveat: don't let it become the sole motivator (overjustification risk) |
| Min spacing between praise | Never praise two consecutive reps; leave at least 1 silent rep between any two voice cues of either kind | Low (practical default; literature gives direction — silence dominates — not this exact spacing number) | Extrapolated from silence-dominance finding above |
| Fade schedule across a set/session/program | Highest cue rate when a movement is new to the user; taper over the set and further over subsequent sessions/weeks as competence rises, similar in shape to a 100%→75%→50%→25% fade curve | High (direction) / Med (adopting the exact lab percentages for a weight-room app) | Winstein & Schmidt 1990 (reduced/faded KR frequency beats 100% KR for retention); PMC6698475 (faded 100→75→50→25% KR was the only condition with significant 1-2 week retention, p=.045/.039; 100% KR was worst, no significant gain even at posttest) |
| Priority ordering when >1 thing could be said | Safety alert > threshold-crossing technical correction > praise/confirmation > general hustle/filler. Never stack more than one cue on a single rep | Med (synthesized — not one single source) | Vika product guardrail (real-time alerts reserved for safety) + bandwidth/guidance-hypothesis literature (correct sparingly) |
| Count every rep aloud? | No. Don't voice-count or comment on every rep; a non-verbal tick (or nothing) can mark reps, reserving voice for milestone reps (last rep, halfway, PR) and trigger-based cues | Med | Guidance hypothesis: constant augmented feedback blocks intrinsic error-detection and creates feedback dependency |
| Feedback valence / framing | When correcting, pair it with what to do (external-focus cue), not just what's wrong; prefer confirming good reps over dwelling on faults | Med-High | Wulf et al. external-focus-of-attention meta-analyses (external cues outperform internal/anatomical cues, consistent across skill levels); Chiviacowsky & Wulf self-controlled feedback work (learners request feedback mostly after good trials, use it to confirm success) |
| Self-controlled option | Where the UI allows it, let the user pull extra feedback on demand rather than always pushing it | Med | Chiviacowsky & Wulf: learner-controlled feedback schedules outperform imposed ones |
| Post-set summary content | Concentrate the densest, most specific feedback at set-end: the single dominant fault to fix next set + a rep-count/highlight, not a recitation of every issue from every rep | High | Summary-KR literature: 5-trial summary block outperformed 1/10/15-trial blocks (inverted-U), and summary/terminal feedback beat per-trial feedback in the same retention studies above |
| Tone / cultural calibration | Warm, encouraging phrasing always; avoid direct/blunt criticism, especially of a "you failed" framing | Low-Med (no sport-specific Vietnamese study found; extrapolated from general workplace/communication research) | General literature on Vietnamese/high-context communication favoring indirectness and face-saving; matches existing Vika product voice guideline (never drill-sergeant) |

## 3. Verification notes

- Claim 1 (silent monitoring 21.99%, most frequent behavior) — **confirmed**, exact figure matches source (PubMed 12173963).
- Claim 2 (hustle 11.12%, 3rd most frequent) — **confirmed** in the same fetch; management/organization was actually 2nd (14.62%), ahead of hustle.
- Claim 3 (Winstein & Schmidt 1990, faded 50% KR → 35% less error, p<.01) — **partially confirmed**. The source PDF's text layer wouldn't extract cleanly (raw compressed streams, textutil/WebFetch both failed to decode it), so the exact "35%"/p<.01 figures could not be independently re-read. Secondary sources (ResearchGate, ScienceDirect citations, Frontiers) consistently corroborate the core finding — reduced/faded KR relative frequency improved retention vs. 100% KR, at the cost of acquisition-phase performance — so the direction and existence of the effect is solid; treat the precise percentage as unverified-but-plausible.
- Claim 8 (bandwidth feedback: cue only past threshold, silence = implicit success signal) — **confirmed in substance** via secondary sources (ScienceDirect/Atlantis Press summaries state explicitly that "missing augmented feedback acts as reinforcement"), though the original Springer review (10.3758/s13423-012-0333-8) was paywalled and could not be fetched directly.
- Claim 10 (PMC6698475: faded 100→75→50→25% KR only condition with significant 1-2wk retention, p=.045/.039; 100% KR worst) — **confirmed**, quotes matched almost verbatim on direct fetch of the PMC article.
- Claim 11 (5-trial summary-KR inverted-U vs 1/10/15) — **confirmed** via search corroboration of the Schmidt et al. summary-KR studies.
- Truncated claim 12 items (bandwidth, self-controlled feedback, Wulf external focus, Confucian Heritage Culture praise norms, CBAS/coach-praise-rate observation) — re-found and summarized in the table/narrative above; none contradicted the prior run's characterization.
