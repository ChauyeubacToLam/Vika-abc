# Voice Coach — Behavior Spec (v1, draft for Nam's review)

Status: v1.2 — reviewed by Nam 2026-07-07, approved with one addition (coach-personality scalar,
below). 2026-07-08: count floor loosened (Nam) — caps/floors are saturation guards, not schedulers;
see principle 2 corollary and the rep-count rules. Numbers stay open for feel-tuning. Behavior only —
implementation doc comes later (Opus + lavish).
Research backing: [voice-research-rules.md](voice-research-rules.md) (same folder).
Decision record: docs/decisions.md, 2026-07-07 voice-coach entry.

## Design principles

1. **Silence is the default.** The coach speaks only on a trigger; it never fills dead air.
   (Real elite coaches: silent monitoring is their single most common behavior, ~22%.)
2. **No metronomes.** Nothing optional fires on a fixed counter ("every 3 reps") — every optional
   cue is a fresh probability draw, shaped by hunger (see model below). Gaps between cues vary
   naturally around an average; there is no learnable pattern within a set or across sets.
   Corollary (Nam, 2026-07-08): **hard floors and caps are saturation guards, not schedulers.**
   Size them at the degenerate edge — the pathological case they exist to prevent (a whole set
   uncounted, a cue on every rep) — never tight enough to bind on a typical set. A limit that
   binds every set IS a metronome: the original count floor forced a count after at most 2 silent
   reps, which produced an audible alternating rhythm ("bốn... sáu... tám... mười").
3. **Deterministic is reserved for causality and structure.** Safety alerts, setup instructions,
   set completion, and the *first* reaction to a new fault are reliable — reacting to something the
   user just did feels human; firing on a schedule feels robotic. Randomness applies to cadence,
   never to whether the coach responds to a real event at all.
4. **One voice moment per rep, max.** A count may pair with ONE outcome word (praise/correction/
   hustle). Never two outcome cues on the same rep.
5. **Data honesty.** Every cue maps to something measured this set. No generic filler.
6. **Tone: warm Vietnamese, never drill-sergeant.** Corrections say what TO do ("hạ thấp hơn"),
   not what failed.

## The randomness model (how "not predictive" works)

Each optional cue type has:

- **base chance** — probability it fires when eligible.
- **hunger bonus** — +X% per eligible-but-silent rep since that cue type last fired (capped).
  This guarantees the coach never goes weirdly quiet forever, without ever being periodic.
- **relief valve** — at extreme hunger the chance approaches near-certainty (a real PT would not
  watch 6 perfect reps and say nothing).
- **reset** — after firing, hunger drops to zero, so back-to-back repeats are unlikely but not
  forbidden (except where a hard rule below says never).

True randomness per draw (no fixed seed): two identical sets must never sound identical.

## Coach personality — the one tunable knob

The base chances and hunger slopes in this spec are **fixed reference values** (the calibrated PT).
Nobody tunes them per exercise or per screen. Chattiness is tuned through a single scalar:

- **effective chance = min(cap, (base + accrued hunger) × personality)** — the scalar multiplies
  both the base probability and the hunger increments, so a quiet coach starts lower AND warms up
  slower; a chatty one does the opposite.
- **Range 0.5 (quiet) – 1.5 (chatty), v1 ships one default: 1.0.** Presets, a per-user setting, or
  per-voice personas can arrive later without touching any spec number.
- **Immune to personality:** every hard rule in the table below, and the relief valves — they are
  the anti-weird backstops, so even the quietest coach eventually acknowledges a perfect streak and
  always responds to safety, structure, anchors, and no-counts.
- Composes multiplicatively with the (phase-2) skill-fade multipliers:
  effective = (base + hunger) × personality × fade, then clamped by the cap.

## Cue types

### Safety — deterministic, always
Fires immediately, interrupts anything currently playing. No probability, no cooldown, no fade.
A PT never dices on safety. (Real-time alerts are safety-only per product guardrail.)

### Instructions / structure — deterministic, once
Setup intro, ready countdown, set complete: exactly once at their moment, always.

### Rep count — anchored, stochastically thinned
Counting is registration + pacing info, but it does not need to be every rep (Nam's call, matches
the guidance-hypothesis concern about constant voice).

- **Always counted (anchors):** rep 1 (proof the counter works), and the last 2 reps of the target
  (finish energy: "chín... mười!").
- **Middle reps:** counted with ~70% chance, hunger +15%/skipped rep, **capped at 90%** — no
  skip streak may ever make the next count a certainty the user can learn.
- **Relief valve (supersedes "never skip two counts in a row", 2026-07-08):** a count is forced
  only after **6 consecutive silent counts**. That guard exists solely so a set never goes
  essentially uncounted; sized per principle 2's corollary so it cannot shape rhythm. The old
  2-skip floor was tight enough to bind every set and produced an alternating even-number pattern.
- **Skipped counts still tick:** a soft non-verbal tick marks the rep, so the user never wonders
  whether the rep registered. Voice is thinned; registration feedback is not.

### Praise — variable-ratio, clean reps only
- **Eligible:** measured-clean rep only.
- **Base 35%**, hunger +10% per clean-but-unpraised rep, capped at 85%.
- **Relief valve:** 5+ consecutive clean reps with zero praise → next clean rep ≥90%.
- **Hard rule:** never praise two consecutive reps.
- **Content:** rotating pool, no immediate repeats; mix small acknowledgements ("Tốt", "Đúng rồi")
  with bigger ones ("Tốt lắm!"), bigger ones weighted toward harder moments (deep rep, late set).
- Expected feel: praise lands on average every ~3 clean reps, actual gaps 1–6, never rhythmic.

### Correction — bandwidth + escalating pressure (post-rep, per guardrail)
- **Bandwidth:** minor wobble inside tolerance = silence. Only threshold-crossing faults speak.
  Silence itself is the "you're fine" signal.
- **First occurrence of a fault-id this set: always cue it** (deterministic — causal response,
  see principle 3).
- **Same fault persists:** re-cue with rising pressure, not a fixed wait — next rep ~25%, the rep
  after ~55%, then ~85% and stays high. Sometimes the coach jumps on it immediately, sometimes
  waits two reps: exactly how a PT watches for self-correction. Phrasing escalates with persistence
  ("nhớ giữ gót chân" → firmer variant), tone stays warm.
- **Fault clears then returns later in the set:** treated as fresh but slightly damped (~70% on
  reappearance, then the same rising curve).
- **Multiple faults on one rep:** only the highest-priority one speaks (safety-relevance first,
  then severity). The rest wait for the post-set summary.

### Hustle / effort push — sparse, situational (new cue type, needs a few new assets)
- **Eligible:** last 1–2 reps of the target, or a detected grind (rep duration well above the
  user's set average).
- **~50% chance**, at most once per set.
- **Hard rule:** never on the same rep as a correction.
- Lines: "Cố lên!", "Một cái nữa thôi!" — warm push, ~11% of real coach behavior, used exactly
  because it is rare.

### No-count (attempt didn't register) — reliable, but never naggy
- First and second no-count: always cue (trust info — user must know it didn't count), rotating
  phrasing.
- **Two consecutive no-counts:** stop repeating "chưa tính" — switch once to instructional help
  (why it's not counting, what to change), then stay quiet until something changes. Repeating the
  same failure line three times is nagging, not coaching.

## Stacking order within one rep-moment

count (maybe) → then at most one of: **correction > praise > hustle** (if several are eligible,
higher wins, the others simply don't happen — no queueing of stale compliments).

## Fade (provisional — phase 2, needs per-user skill state)

Direction from the literature (faded 100→75→50→25% was the only schedule with lasting retention):

- **New-to-user exercise (first ~2 sessions):** praise and correction hungers ×1.3 (talks more).
- **Mature exercise (weeks of clean history):** ×0.7 (talks less; silence = mastery signal).
- Set-level: no extra fade in v1 — sets are short (≤15 reps); hunger shaping already spaces cues.

Marked provisional: ship v1 with the multipliers fixed at 1.0 and the hook present.

## Post-set — deterministic, and the richest moment
Set-complete line always; then the summary carries the dense feedback: single dominant fault to
fix next set + one highlight. (Summary/terminal feedback beats per-rep commentary for retention —
this is already the interpreter's job, unchanged.)

## Hard rules (the complete list — everything else is probabilistic)

| # | Rule |
|---|---|
| 1 | Safety always speaks, immediately |
| 2 | Setup / ready / set-complete exactly once, always |
| 3 | Rep 1 and last 2 reps always counted; count forced only after 6 consecutive silent counts (middle-rep roll capped at 90%, never certain) |
| 4 | Skipped counts still get a non-verbal tick |
| 5 | First occurrence of a fault-id in a set always cued |
| 6 | Never praise two consecutive reps |
| 7 | Max one outcome cue per rep; correction > praise > hustle |
| 8 | Hustle max once per set, never alongside a correction |
| 9 | After 2 consecutive no-counts, switch to help, don't repeat the failure line |
| 10 | Every cue is backed by a measurement from this set |

## Worked example — 10-rep squat set, faults on reps 4–5 (heels), grind on rep 9

| Rep | Clean? | Coach says | Why |
|---|---|---|---|
| 1 | ✓ | "Một" | anchor count |
| 2 | ✓ | *(tick)* "Tốt" | count skipped (30% roll), praise fired (base 35%) |
| 3 | ✓ | "Ba" | praise blocked (hard rule 6) |
| 4 | ✗ heels | "Bốn — nhớ giữ gót chân nhé" | first fault occurrence: always |
| 5 | ✗ heels | "Năm" | re-cue rolled 25%: stayed quiet, watching |
| 6 | ✓ | *(tick)* | fault self-corrected → silence IS the feedback |
| 7 | ✓ | "Bảy — đúng rồi!" | praise hunger built up (3 clean unpraised) |
| 8 | ✓ | "Tám" | — |
| 9 | ✓ slow | "Chín — cố lên!" | anchor count + grind detected, hustle rolled 50% |
| 10 | ✓ | "Mười! Tốt lắm!" | anchor + final-rep praise |
| — | | set-complete + summary: heels fault, 8/10 clean | deterministic, richest feedback |

Run the same set again → different transcript. That's the point.

## Numbers most likely wrong (review targets for Nam)

- Praise base 35% / hunger +10% / cap 85% — feel-tuning, literature only says "30–50%, variable".
- Count-skip 30% on middle reps — could be too chatty (70% counted) or too sparse; also whether
  the tick is enough registration feedback on skipped counts.
- Correction persistence curve 25→55→85% — direction is research-backed, the exact slope is mine.
- Hustle 50% / once per set — pure product taste.
- Fade multipliers ×1.3 / ×0.7 — provisional, phase 2 anyway.
- Personality scalar range 0.5–1.5 — bounds are a guess; too-low values may starve praise entirely
  on short sets even with the relief valves.
