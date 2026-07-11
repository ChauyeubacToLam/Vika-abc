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

### Inter-rep pause as a grind signal (2026-07-09 follow-up run)

Second capped Sonnet run (~7 searches / 6 fetches) checking whether the spontaneous pause BETWEEN
reps is a documented proximity-to-failure signal, as a candidate primary trigger over rep-duration
slowdown. Same verification caveat as §3's intro.

- Direct evidence: none. No study measures whether spontaneous inter-rep pauses lengthen as a
  self-paced set approaches failure. Unstudied, not refuted.
- Mechanism is real at higher doses: imposed inter-rep rests of ~10s+ (cluster sets) demonstrably
  reduce velocity loss / lactate / muscle damage (PCr resynthesis). High — PMC11667556, PMC6257924.
  But imposed pauses of 0-5s showed NO effect on RIR-estimation validity (PubMed 38662926, Med) —
  the casual between-rep pause range buys little physiological recovery.
- Where the literature DOES localize near-failure slowdown, it's the concentric phase / sticking
  region (rep duration), not pause growth. Med — PMC12521083 + squat kinematics studies. A
  purpose-built wearable RIR-detection paper (arXiv 2512.11854) engineers time-in-rep features and
  ignores inter-rep pause entirely (Low, absence-of-evidence).
- Bodyweight/untrained pacing near failure: nothing found.

Design reading (ours, provisional): gap-stretch is a BEHAVIORAL hesitation signal (deciding whether
to attempt the next rep), not a physiological fatigue meter; rep-duration slowdown is the
literature-backed physiological proxy. Neither has validated thresholds for pose-derived bodyweight
data, so per-exercise weighting of the two signals must come from our own ExerciseLogger timestamp
calibration, not citations.

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

## 3b. Next-rep carryover deep-dive (2026-07-09 run)

Targeted follow-up run for the parked post-rep/next-rep reminder design (state.md "instruction/structure
cluster"). Single-pass capped Sonnet run, ~27 tool calls; claims carry the run's own confidence tags and
were NOT independently re-verified — same trust level as §3. Overlapping ground (bandwidth, faded KR,
silence-default, summary-KR) already lives in §1/§2 and is not repeated here.

### Carryover / anticipatory cueing (the target behavior)

- **No controlled study observes the exact behavior** (a cue on rep N explicitly referencing rep N+1).
  Everything below is practitioner consensus + inference from cue-timing/brevity literature. Med at best.
- Timing rule: a cue must arrive BEFORE the joint position it targets — "a cue for the knees at the
  bottom of the squat must be given before the bar starts down." Cueing is reaction-triggering, not
  analysis; late feedback is wasted. Med — Starting Strength / PTDC practitioner consensus.
- Anticipatory pre-cues are phrased as forward instruction, not diagnosis: "this one, deeper" / "drive
  the knees out this time", never a restatement of what went wrong. Low-Med — consistent across cue-brevity
  sources, but the specific next-rep phrasing pattern itself is thinly evidenced.
- One correction per rep, max — "two cues per rep is too much information; fix the second problem during
  the next set" (Rippetoe lineage; independently echoed by Rearick "10 things → nothing"). Med-High.
- Deliberate silence FIRST: "let the first rep(s) suck" — watch several reps, let the client self-organize,
  then one specific note. Silence is a behavior, not a gap. Med — single strong source (Rearick), aligns
  with self-controlled-feedback literature.

### Decay: what happens when a cue doesn't work

- **If the cue fails, change the cue — don't repeat it louder.** Switch image, switch internal↔external,
  or simplify wording before concluding the client can't do it. Med-High — PTDC, Barbell Logic, Cressey
  converge independently.
- After cue-switching fails (~2 attempts), regress the exercise or table it for after the set — a third
  identical real-time repetition reads as nagging in every source reviewed. No quantified attempt-count
  threshold exists; "2" is the converging practitioner shape, not a measured number. Med.
- If the client fixes it: go silent or downgrade to a generic acknowledgment — don't keep narrating a
  solved problem (bandwidth logic: in-band = generic success signal only). Med-High.
- Exception sanctioned by the literature: genuine safety faults (joint-risk positions) may be cued every
  instance until fixed — the only case where repeat-every-rep is endorsed. Med.

### End-of-set behavior

- In the final 1–2 reps, verbal behavior shifts from technique correction to short encouragement
  ("you've got it", "one more"); technique correction is largely abandoned past technical failure — the
  set is stopped, not corrected. Med — converging industry sources, not framed as a speech study.

### Phrasing

- Positive/target framing over negation: "chest up" not "don't round your back" — negation doesn't
  suppress the image of the wrong movement. Low-Med — practitioner blogs; the external-focus mechanism
  underneath is high-confidence (Wulf).
- **External focus × frequency interaction (new vs §2):** in Wulf's soccer throw-in study, 100% feedback
  beat 33% under EXTERNAL-focus framing, but 33% beat 100% under INTERNAL-focus framing. An external-cue
  voice coach can afford a higher cue rate than an internal-cue one. High — Frontiers 2010 / PMC3153799.
- Praise > correction directionally always; named ratios (3:1–12:1) have no empirical convergence —
  treat any specific ratio as folklore. Low for any number.

### Closest analog to Vika

- Kaushik & Simmons, robot exercise coach for older adults (arXiv:2601.08819): feedback cadence directly
  shapes perceived helpfulness, and changing one modality's cadence changes perception of the other.
  Only found study of an AUTOMATED real-time exercise voice coach; specifics beyond the abstract not
  verified, population may not generalize. Med, directional only.

### Gaps (searched, not found)

- No observational study of PT speech across consecutive reps; no quantified regress-after-N-attempts
  threshold; no praise-ratio consensus; nothing on Vietnamese/non-Western coaching norms (two targeted
  searches in §3, again here) — stays a design judgment under the warm-encouraging guardrail.

### Second same-day run (independent capped Sonnet run — deltas only)

A second capped run (13 searches / 6 fetches; only 2 fetches succeeded, startingstrength.com 403'd
twice) independently converged on the §3b core: cue lands before the phase it fixes, feedforward
phrasing, one fault per cue, brevity, taper-don't-repeat. Convergence is snippet-level on both sides
(mostly non-shared sources) — mild corroboration, not proof. New findings this run:

- **Placement made concrete: start-of-rise of the NEXT rep.** A peak/end-measured fault fires its
  reminder at the start-of-raise boundary of the following rep, not at rep-end of the flawed one
  ("a hips-up cue must be given before the bottom is reached" — Rippetoe, snippet only). For
  continuous-tempo exercises (glute bridge) same placement: no source names a mid-eccentric reminder
  technique; start-of-raise is the evidence-consistent choice, not directly sourced. Med.
- **Line cap ~5–7 words, one fault — directly read:** "if you can't yell it during a rep, it's too
  long"; "one cue at a time, two max" (rypenfitness "The Art (and Science) of Cueing", the run's one
  confirmed fetch besides PMC6698475). High for the craft rule.
- **Reminder cadence once a fault is intermittent: ~1 per 3 reps, never every rep.** Rippetoe snippet
  only. Med. (Safety faults exempt per §3b — repeat-every-instance is sanctioned there.)
- **Confirm-after-fix: one short warm line when the reminded fault is fixed on the very next rep**
  ("đó, đúng rồi" territory). General immediate-specific-praise literature; the exact rep-to-rep moment
  is unobserved in any strength study. Med/Low. Reconciled with §3b's "go silent / downgrade to generic
  acknowledgment once fixed": confirm ONCE on the first fixed rep, then silence owns it.
- **Dependency risk of pre-rep reminders:** plausibly lower than concurrent feedback (guidance-
  hypothesis dependency is driven by concurrent high-frequency KR) but not exempt — the taper still
  applies. Reasoned synthesis, no direct study. Med.
- Faded-KR anchor (PMC6698475) re-confirmed by direct fetch, same as §1/§2.

## 3c. Breathing cues deep-dive (2026-07-11 run)

Triggered by Nam's PT saying trainers cue breathing "most of the time". Single-pass capped Sonnet run
(~15 tool calls); claims carry the run's own confidence tags and were NOT independently re-verified —
same trust level as §3. Decision status: OPEN, awaiting Nam's call (see decisions.md once ruled).

### Efficacy — exhale-on-exertion is real physiology, not just tradition

- Bench-press within-subject study (n=12 trained males, PMC12801646): inhale-during-lift produced
  lower set completion, less volume, highest RPE; breath-hold (Valsalva) lowered RPE but showed HRV
  stress markers; authors call exhale-on-exertion the "safest strategy". Med — small n, heavy barbell,
  not bodyweight core.
- Most Vika-relevant finding: breath-holding during SIT-UPS raised mean BP +22.2±16.4 mmHg vs free
  breathing (n=14 healthy adults, ScienceDirect S0003999303000492, snippet only). Establishes
  breath-hold as a measurable physiological event even at bodyweight trunk-work intensity. Med.
- The scary Valsalva numbers (300+/200+ mmHg) are all from near-maximal barbell lifting; applying
  them to glute bridge/plank intensity is extrapolation, not measured risk. High that the extreme
  literature doesn't transfer.

### Observed PT behavior — the "most of the time" claim doesn't hold for S&C

- The one controlled coach-observation study (PubMed 12173963, same source as §1) does not code
  breathing as a behavior category at all — no empirical support for breathing cues being a large
  chunk of real S&C coach speech. High for absence-of-category; full-text percentages unconfirmed
  (abstract only this run).
- Pilates/group-fitness pedagogy IS an every-rep breath metronome ("inhale to prepare, exhale on the
  effort" — STOTT/Merrithew et al.), never faded. Med, practitioner consensus. The PT's claim reads
  as Pilates/physio norm-bleed into a general-PT statement, not general strength practice.

### Attentional cost — breathing is the canonical harmful internal cue

- Wulf-lineage running-economy study: breath-focus condition had measurably worse economy (higher O2,
  higher lactate) than external focus. Directly on point: making breath a salient real-time
  attentional target degrades performance. High.

### Timing/phrasing (practitioner consensus only)

- Pilates convention: exhale completes at peak exertion, inhale on the return; short rhythmic
  phrasing, cued every rep. Med. No source describes tapering breathing cues — the per-rep metronome
  directly conflicts with our faded/bandwidth design rules (§1/§2).

### Automated coaches

- Virtual breathing-exercise coach ≈ human-equivalent for dedicated breathing exercises (Sci Reports
  2026, Aston) — different product category, limited transfer. Med. No outcome data on breathing cues
  inside any rep-counting fitness app. Gap.

### Detection limits (pose-only, no breath sensing)

- CAN honor: phase-timed open-loop INSTRUCTION ("thở ra khi nâng lên" fired at concentric start or in
  setup) — an instruction, not a feedback claim, so it doesn't violate data honesty.
- CANNOT honor: anything phrased as feedback ("you're holding your breath", "good breathing") —
  unverifiable, violates the never-say-what-we-didn't-measure guardrail. Compliance is never known.

### Gaps (searched, not found)

- No trial on breathing-cue timing/taper in strength training; no frequency data for breathing cues
  in general PT sessions; no Vietnam/SEA PT breathing-norm data (yoga marketing only, two searches).

## 4. Verification notes

- Claim 1 (silent monitoring 21.99%, most frequent behavior) — **confirmed**, exact figure matches source (PubMed 12173963).
- Claim 2 (hustle 11.12%, 3rd most frequent) — **confirmed** in the same fetch; management/organization was actually 2nd (14.62%), ahead of hustle.
- Claim 3 (Winstein & Schmidt 1990, faded 50% KR → 35% less error, p<.01) — **partially confirmed**. The source PDF's text layer wouldn't extract cleanly (raw compressed streams, textutil/WebFetch both failed to decode it), so the exact "35%"/p<.01 figures could not be independently re-read. Secondary sources (ResearchGate, ScienceDirect citations, Frontiers) consistently corroborate the core finding — reduced/faded KR relative frequency improved retention vs. 100% KR, at the cost of acquisition-phase performance — so the direction and existence of the effect is solid; treat the precise percentage as unverified-but-plausible.
- Claim 8 (bandwidth feedback: cue only past threshold, silence = implicit success signal) — **confirmed in substance** via secondary sources (ScienceDirect/Atlantis Press summaries state explicitly that "missing augmented feedback acts as reinforcement"), though the original Springer review (10.3758/s13423-012-0333-8) was paywalled and could not be fetched directly.
- Claim 10 (PMC6698475: faded 100→75→50→25% KR only condition with significant 1-2wk retention, p=.045/.039; 100% KR worst) — **confirmed**, quotes matched almost verbatim on direct fetch of the PMC article.
- Claim 11 (5-trial summary-KR inverted-U vs 1/10/15) — **confirmed** via search corroboration of the Schmidt et al. summary-KR studies.
- Truncated claim 12 items (bandwidth, self-controlled feedback, Wulf external focus, Confucian Heritage Culture praise norms, CBAS/coach-praise-rate observation) — re-found and summarized in the table/narrative above; none contradicted the prior run's characterization.
