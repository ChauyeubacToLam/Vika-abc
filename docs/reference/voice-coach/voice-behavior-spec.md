# Voice Coach — Behavior Spec (v1, draft for Nam's review)

Status: v1.3 — reviewed by Nam 2026-07-07 (personality scalar), refined 2026-07-08 (glute-bridge
behavior lock), 2026-07-09 (cue-type rename + real-time critical/soft). Numbers stay open for
feel-tuning; shapes locked. Glute bridge is the in-code pilot; real-time firing is designed and
Codex-pending.
07-09 folded in: cue types renamed `criticalFault`/`softFault`/`setup`; NEW `softFault` (non-critical)
bucket; count finalized to cap-1.0 / no-discrete-relief-valve; `criticalFault` + `softFault` fire
REAL-TIME (the instant a fault is known), not post-rep.
Research backing: [voice-research-rules.md](voice-research-rules.md) (same folder).
Decision record: docs/decisions.md — 2026-07-07, 07-08, and 07-09 voice-coach entries.
Real-time design: [realtime-cue-design.html](realtime-cue-design.html) (same folder).

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

### "Safety" — reframed 2026-07-09: no separate cue
There is no dedicated safety voice cue. The spec's "safety fires immediately" IS the `criticalFault`
cue firing real-time (below) — a critical form fault is the immediate, deterministic reaction. The
landmark/tracking "safety" (`ExerciseBase.checkSafety`) surfaces on-screen text (orientation, "keep
shoulder/hip/knee in frame"), not voice. Real-time voice stays safety-only per the product guardrail —
and critical faults ARE that safety class.

### Setup / structure (`setup`) — deterministic, once
Setup intro, ready countdown, set complete: exactly once at their moment, always. (Was `instruction`;
renamed `setup` 07-09.) The adapter latches each moment so it fires exactly once (hard rule 2).

### Rep count — anchored, stochastically thinned
Counting is registration + pacing info, but it does not need to be every rep (Nam's call, matches
the guidance-hypothesis concern about constant voice).

- **Always counted (anchors):** rep 1 (proof the counter works), and the last 2 reps of the target
  (finish energy: "chín... mười!"). [The final-2 anchor is locked but NOT yet in code — pending, 07-09.]
- **Middle reps:** a real probability draw with hunger climbing per skipped count. Glute-bridge pilot:
  base 0.50, hunger +0.10, **cap 1.0** with a small step, so certainty is only reached after ~5
  straight silent counts.
- **No discrete relief valve (finalized 2026-07-08, supersedes the earlier cap-0.90 + "force a count
  after 6 silent counts"):** the hunger climb to cap-1.0 IS the "never essentially uncounted" guard —
  a saturation edge, not a scheduler ("no extra rules"). Sizing rule per principle 2's corollary. (The
  cap-0.90 + reliefAfter:6 was itself a fix for the 2-skip floor; both are now superseded.)
- **Skipped counts still tick:** a soft non-verbal tick marks the rep, so the user never wonders
  whether it registered. DECIDED, not yet built. Voice is thinned; registration feedback is not.

### Praise — variable-ratio, clean reps only
- **Eligible:** measured-clean rep only.
- **Base 35%**, hunger +10% per clean-but-unpraised rep, capped at 85%.
- **Relief valve:** 5+ consecutive clean reps with zero praise → next clean rep ≥90%.
- **Hard rule:** never praise two consecutive reps.
- **Content:** rotating pool, no immediate repeats; mix small acknowledgements ("Tốt", "Đúng rồi")
  with bigger ones ("Tốt lắm!"), bigger ones weighted toward harder moments (deep rep, late set).
- Expected feel: praise lands on average every ~3 clean reps, actual gaps 1–6, never rhythmic.

### Critical fault (`criticalFault`) — real-time, deterministic first reaction, escalating
(Was "Correction". A critical fault = a measured fault with `affectsForm==true`.)
- **Fires REAL-TIME (2026-07-09):** the instant the fault is known, not batched at rep-completion.
  Continuous faults (e.g. hyperextension, neck-lift) fire mid-rep, while the user can still act; peak-
  measured faults (e.g. insufficient hip-extension) are only knowable at rep-end and fire then.
  Supersedes the earlier "post-rep, per guardrail" — critical faults ARE the real-time safety class.
- **Bandwidth:** minor wobble inside tolerance = silence. Only threshold-crossing faults speak.
- **First occurrence of a fault this set: ALWAYS cued, deterministically (100%)** — causal reaction
  (principle 3). (`firstOccurrenceCertain`.)
- **Same fault persists:** re-cue with rising pressure — persistence escalates ~25→55→85%. No discrete
  relief valve (redundant once first=100%). Phrasing firms with persistence, tone stays warm.
- **Peak faults = next-rep guidance (OPEN, Nam 07-09):** a peak fault can't be acted on in its own
  rep, so it's framed as "do it right next rep." When the parked post-rep-instructions feature lands,
  peak faults route THERE and the rep-end firing is dropped (no double-speak). Delivery TBD at build.
- **Multiple faults on one rep:** only the highest-priority one speaks; the rest wait for the summary.

### Soft fault (`softFault`) — non-critical nudge, real-time, hunger-shaped
NEW 2026-07-09 — the 3-way classifier's middle bucket. A soft fault = a measured fault with
`affectsForm==false` (a warning, not an error). Exists so a rep with a minor measured fault is neither
praised as clean (data honesty) nor scolded like a critical one.
- **Fires REAL-TIME**, same signal as `criticalFault`, but **probabilistic: hunger + base, NOT
  first-occurrence-deterministic** (gentler cadence). Glute pilot: base 0.20, hunger +0.08, cap 0.55.
- Warm nudge tone ("Tốt, chỉ cần nâng hông cao hơn chút"). Own audio (`<slug>.<id>_soft`).
- Praise is thereby gated on TRULY clean (`correctForm && no faults at all`).

### Hustle / effort push — OFF; behavior being re-determined (Nam + Fable)
- **Status (2026-07-09):** hustle is **OFF** in code (glute pilot: empty pool + 0.0 tuning). Rejected
  07-08: a once-per-set finish-line push on the last 1–2 reps (robotic on a rep counter). What replaces
  it — trigger and behavior — is **TBD**; Nam is re-determining it with Fable. Do NOT wire a new hustle
  behavior until that lands. (Grind-detection was one candidate, not settled.)
- Whatever the trigger, when enabled: at most once per set, never on the same rep as a critical/soft fault.
- Lines: "Cố lên!", "Một cái nữa thôi!" — warm push, ~11% of real coach behavior, rare by design.

### No-count (attempt didn't register) — reliable, but never naggy
- First and second no-count: always cue (trust info — user must know it didn't count), rotating
  phrasing.
- **Two consecutive no-counts:** stop repeating "chưa tính" — switch once to instructional help
  (why it's not counting, what to change), then stay quiet until something changes. Repeating the
  same failure line three times is nagging, not coaching.

## Stacking order within one rep-moment

count (maybe) → then at most one outcome cue per rep: **criticalFault > softFault > praise > hustle**
(if several are eligible, higher wins; the others simply don't happen — no queueing of stale
compliments). Count is not an outcome cue and may co-occur.

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
| 1 | No separate safety cue — a `criticalFault` firing real-time IS the immediate reaction |
| 2 | Setup / ready / set-complete exactly once, always (`setup`) |
| 3 | Rep 1 and last 2 reps always counted; middle reps a real draw, hunger climbs to cap-1.0 saturation (no discrete relief valve) |
| 4 | Skipped counts still get a non-verbal tick (decided, not built) |
| 5 | First occurrence of a fault in a set is cued deterministically (100%) |
| 6 | Never praise two consecutive reps |
| 7 | Max one outcome cue per rep; `criticalFault` > `softFault` > praise > hustle |
| 8 | Hustle OFF (behavior TBD — Nam + Fable); when enabled: max once per set, never alongside a fault cue |
| 9 | After 2 consecutive no-counts, switch to help, don't repeat the failure line (parked) |
| 10 | Every cue is backed by a measurement from this set |

## Worked example — 10-rep squat set, faults on reps 4–5 (heels), grind on rep 9
(Illustrates the stochastic cadence principle. Predates the 07-09 refinements — it still shows the old
"correction" label, hustle-on, and post-rep timing; read it for the *rhythm*, not the current cue set.)

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
