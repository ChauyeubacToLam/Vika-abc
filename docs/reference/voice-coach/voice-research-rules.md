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

## 3. Hustle/encouragement deep-dive (2026-07-09 run)

Targeted follow-up run for the hustle-cue redesign (the once-per-set final-rep push was rejected
2026-07-08 as robotic; see decisions.md). Single-pass capped Sonnet run, ~10 searches / 9 fetches;
claims carry the run's own confidence tags and were NOT independently re-verified — treat High tags
here as "peer-reviewed source fetched by the agent", one notch below §4's confirmed claims.

### Efficacy + mechanism of verbal encouragement

- Verbal feedback beats no feedback in acute resistance-exercise performance: Hedges' g = 0.47
  (95% CI 0.22–0.71) across 13 studies; combined (visual+verbal) feedback ≈ 8.4% barbell-velocity
  improvement. High — 2023 systematic review/meta-analysis, PMC10432365.
- The effect is in-the-moment, not learned: "when feedback is taken away, performance immediately
  returns to non-feedback levels." Per-rep feedback beats end-of-set feedback. High — same review.
- Frequency floor: encouragement every 20s and 60s improved all outcomes in a treadmill-to-exhaustion
  test (VO2max, time-to-exhaustion, lactate, RER, RPE); every 180s was statistically indistinguishable
  from no encouragement. No within-session habituation observed. High for the finding, caveat: single-
  session endurance protocol, not resistance training — PubMed 12003280.
- Peer encouragement outperformed coach encouragement in a CrossFit study (+3–6.7% on 1RMs and time
  trials, r=0.64–0.84) — supports "training partner" register over "drill sergeant". Med — single
  study, PMC10975230.
- Within-set PLACEMENT (near-failure vs spread) is unstudied — the literature covers presence and
  frequency only. The grind-trigger hypothesis is coherent with practitioner cueing norms (Med) but
  is not itself an effect-size-backed finding.

### Grind detection via rep slowdown (VBT proxy)

- Within-set barbell velocity loss by proximity to failure (bench press): to-failure −22%,
  1-RIR −9%, 3-RIR −6% from first to final rep. High — PMC9908800.
- Absolute velocity-at-RIR benchmarks exist (~0.27 m/s ≈ 2 RIR bench) but are lift- and load-specific;
  authors explicitly flag non-generalizability. High for bench, not portable — PMC11934800.
- Velocity-loss failure proxies are noisy even with a transducer: one secondary-source claim that 40%
  VL reached true failure only ~56% of the time. Low — not independently verified.
- DERIVED, PROVISIONAL (ours, not a citation): treating pose-derived rep duration as inverse velocity,
  the numbers translate to roughly +6–10% longer rep ≈ 3 RIR, +10–15% ≈ 1 RIR, +25–30% ≈ near-failure.
  No study measured rep-duration slowdown from pose/bodyweight data; for bodyweight moves (glute
  bridge) "failure" is closer to form breakdown than bar-speed collapse. Calibrate against our own
  ExerciseLogger rep durations before encoding any threshold. Low.

### Phrasing + escalation near failure

- Practitioner consensus (Starting Strength / NSCA coaching-education): grind-rep cues must be short,
  loud, imperative — "the heavier the weight, the louder the cue"; long phrasing doesn't get processed
  under load. Med — coaching-education sources, not controlled studies.
- Selective delivery is the mark of skilled coaching: "great coaches don't react to every rep";
  one cue at a time. Low-Med — practitioner opinion.
- Countdown framing ("two more, last one") is recognized practice for final reps but overuse pulls
  attention into anxious counting. Low-Med.
- No controlled study isolates escalation mechanics (loudness, name-use, imperative form) — inherited
  coaching craft, don't present as evidence-backed.

### Vietnamese / SEA coaching style

Nothing found (two targeted searches). Only generic SEA communication-style literature (indirectness,
face-saving — not fitness-specific). Stays a design judgment under the existing warm-encouraging
guardrail; no evidence base exists to cite.

### Detection limits (pose-only, no bar velocity / HR)

- CAN honor: per-grinding-rep firing frequency; relative rep-duration slowdown as a grind proxy
  (direction well-established); short/imperative/escalating phrasing.
- CANNOT honor: validated duration thresholds (all numbers are loaded-barbell LPT data); within-set
  placement evidence (doesn't exist); physiological corroboration of effort — any grind threshold is
  a proxy with unknown false-positive/negative rate.

## 4. Verification notes

- Claim 1 (silent monitoring 21.99%, most frequent behavior) — **confirmed**, exact figure matches source (PubMed 12173963).
- Claim 2 (hustle 11.12%, 3rd most frequent) — **confirmed** in the same fetch; management/organization was actually 2nd (14.62%), ahead of hustle.
- Claim 3 (Winstein & Schmidt 1990, faded 50% KR → 35% less error, p<.01) — **partially confirmed**. The source PDF's text layer wouldn't extract cleanly (raw compressed streams, textutil/WebFetch both failed to decode it), so the exact "35%"/p<.01 figures could not be independently re-read. Secondary sources (ResearchGate, ScienceDirect citations, Frontiers) consistently corroborate the core finding — reduced/faded KR relative frequency improved retention vs. 100% KR, at the cost of acquisition-phase performance — so the direction and existence of the effect is solid; treat the precise percentage as unverified-but-plausible.
- Claim 8 (bandwidth feedback: cue only past threshold, silence = implicit success signal) — **confirmed in substance** via secondary sources (ScienceDirect/Atlantis Press summaries state explicitly that "missing augmented feedback acts as reinforcement"), though the original Springer review (10.3758/s13423-012-0333-8) was paywalled and could not be fetched directly.
- Claim 10 (PMC6698475: faded 100→75→50→25% KR only condition with significant 1-2wk retention, p=.045/.039; 100% KR worst) — **confirmed**, quotes matched almost verbatim on direct fetch of the PMC article.
- Claim 11 (5-trial summary-KR inverted-U vs 1/10/15) — **confirmed** via search corroboration of the Schmidt et al. summary-KR studies.
- Truncated claim 12 items (bandwidth, self-controlled feedback, Wulf external focus, Confucian Heritage Culture praise norms, CBAS/coach-praise-rate observation) — re-found and summarized in the table/narrative above; none contradicted the prior run's characterization.
