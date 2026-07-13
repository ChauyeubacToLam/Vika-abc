# Voice Coach — Behavior Spec (v1, draft for Nam's review)

Status: v1.5 — reviewed by Nam 2026-07-07 (personality scalar), refined 2026-07-08 (glute-bridge
behavior lock), 2026-07-09 (cue-type rename + real-time critical/soft + per-moment outcome
exclusivity + hustle re-decided: hesitation-armed / commit-fired), and fleet-wired through Tier 3 on
2026-07-12. Numbers stay open for feel-tuning; shapes locked. Glute bridge remains the device pilot;
the shared rep fleet now carries the same policy wiring.
07-09 folded in: cue types renamed `criticalFault`/`softFault`/`setup`; NEW `softFault` (non-critical)
bucket; count finalized to cap-1.0 / no-discrete-relief-valve; `criticalFault` + `softFault` fire
REAL-TIME (the instant a fault is known), not post-rep; outcome exclusivity relaxed to per-MOMENT
(critical-only second slot in-rep + audio-end+0.5s collision gap, cap 2/rep).
07-10 folded in: setup/tracking-safety guidance GETS VOICE on a typed `GuidanceSignal` backend (one
producer, two renderers — UI table + voice), a DETERMINISTIC latch channel separate from the form-fault
cues below. Supersedes the 07-09 "landmark/tracking safety = on-screen text, not voice" line (§ Safety).
Late 07-10: setup-instruction behavior ruled — per-set one-shot intro (+ grace re-anchor to
intro-audio-end goes live with it), voiced 1-2-3 activation countdown, `setupPosition` stuck-user
re-tell, `holdStill` lineless (§ Setup / structure; decisions.md same-day "Setup-instruction voice"
entry). LANDED in tree same day (Opus direct per Nam's call, Fable-verified; uncommitted, one review
pass with the setup-safety diff). Latest 07-10 follow-ups (decisions.md "Setup-voice follow-ups";
landed): grace goes VOICE-ONLY and = intro duration (UI signage ungated,
`guidanceSignalForPresentation` removed), the countdown terminates a still-playing intro, the ring's
'Giữ yên' caption is removed.
Late 07-10 follow-up landed: active-set resume (manual or auto) now routes through the normal
start-position hold again. It does not replay the per-set setup intro, but it re-arms the voiced
"ba, hai, một" countdown and `common.ready`; completed reps/logs stay intact.
07-12: two device re-rulings LANDED: countdown direction flips to "ba, hai, một" (was "một, hai,
ba"); reminder gains a consecutive-rep same-content ban (hard rule 12).
07-12 Tier 3: hustle enabled on all 24 rep exercises with verified effort-phase keys and the strict
generic/final pools; six fast/quirky exercises retain the standard policy with explicit follow-up TODOs.
07-11 late: HOLD-BASED family behavior decided (§ Hold-based exercises below) — pose-gated clock,
voice milestones + spoken final countdown + end tone (07-12 round 2: pips dropped, countdown went
verbal, end tone extends to rep-based), milestone praise/hustle switch; High Plank pilot,
implemented and device-tuned in the working tree.
07-12: holds re-ruled to the PLANK MODEL — a set = N holds counted as reps, each completed hold
speaks its number (registration); supersedes "a set = one continuous hold" (§ Hold-based).
Design + state machine: [setup-safety-voice-design.html](setup-safety-voice-design.html) (same folder).
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
4. **One outcome cue per MOMENT.** A count may pair with ONE outcome word (praise/correction/
   hustle); never two outcome lines at the same instant. (Amended 2026-07-09: was "per rep, max" —
   a leftover from post-rep batching, when every outcome cue fired at the rep boundary and per-rep
   WAS per-moment. A second `criticalFault` on a different fault may voice later in the same rep,
   after the collision gap — see the criticalFault rules.)
5. **Data honesty.** Every cue maps to something measured this set. No generic filler.
6. **Tone: warm Vietnamese, never drill-sergeant.** Corrections say what TO do ("hạ thấp hơn"),
   not what failed. **Persona default (Nam, 2026-07-10):** the coach self-refers as **Vika** and
   addresses the user as **bạn** — the default pronoun scheme for ALL voice lines. Two fixed copy
   patterns follow: soft fault `Tốt, bạn [action] chút nữa là đẹp.`; reminder `Lần này bạn nhớ [action] nhé.`
   (wordings live in missing-audio.md).

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

### Audio routing — COMMON vs PER-EXERCISE keys (Nam, 2026-07-10)
The content-key namespace splits on what a line is ABOUT, and that split decides the file layout:
- **COMMON (`common.*`, one shared recording fleet-wide) = structural / channel lines** — about the
  camera or the session, identical for every exercise: counts, praise, setup, setup/tracking-safety,
  orientation. Registered by hand in `GenericExerciseVoiceAssets.commonFiles`.
- **PER-EXERCISE (`<slug>.<id>`) = movement lines** — about THIS exercise's mechanics: critical faults,
  soft faults, reminders. Resolve on the default `<slug>/<id>.mp3` path, no registration needed.
Metric/fault audio stays PER-EXERCISE even where a metric is reused across exercises (Nam's explicit
call): a shared fault pool is a file-management dependency graph waiting to cause weird issues;
per-exercise keeps each line specific (data honesty) and the onboarding workflow simple (onboard an
exercise → record its metric set). Decision: decisions.md 2026-07-10 "Voice copy conventions".

### "Safety" — TWO distinct channels (reframed 2026-07-10)
Safety splits into two channels that must not be conflated:

1. **Form-fault safety = `criticalFault`, unchanged (07-09).** A critical form fault firing real-time is
   the injury reaction; there is no separate injury voice line. This is what "safety fires immediately"
   means — see the `criticalFault` rules below.
2. **Setup / tracking-safety = a NEW deterministic voice channel (07-10).** The pipeline-BLOCKING states —
   person-gate blocks (searching/paused), `ExerciseBase.checkSafety` (wrong orientation, required landmark
   missing, poor lighting), and the no-pose branch — now speak. **This supersedes the 07-09 line that
   routed landmark/tracking safety to on-screen text only.** Rationale: those states early-return the
   pipeline (no reps count while they hold) and a mid-exercise user physically cannot read the screen
   (glute bridge = lying on the floor), so a text-only cue is a silent dead system. Full rules in the next
   subsection.

### Setup / tracking-safety guidance (`GuidanceSignal`) — deterministic latch, NEW 2026-07-10
One producer, two renderers. The gate blocks, `checkSafety`, and the no-pose branch stop emitting free
`feedback['System']` strings and emit a typed `GuidanceSignal` (a condition CLASS + optional per-exercise
copy). The UI derives glyph+title+body from it via one table; the voice channel derives a content key and
runs the firing policy here. `checkSafety`'s return type changes `String?` → the typed signal across all
~20 exercise subclasses. The check STAYS granular per-exercise/per-landmark; only the message generalizes
(it over-asks — "be fully in frame" is a simple always-safe action — while the check under-asks, only the
landmarks this exercise measures; a literal full-body gate would block a side-view glute bridge forever).

- **Content keys are coarse (the anti-spam decision):**
  - `orientation` — COMMON line (07-10: `common.side_orientation` for the SIDE mode, was per-exercise
    `<slug>.orientation`; glute bridge "quay nghiêng người"). Only ~3 orientation modes exist, so a few
    shared recordings beat one per exercise; only the side mode has a key today.
  - `body_in_frame` — ALL landmark-missing/low-confidence/lighting/tracking-loss variants collapse to ONE
    generic line (`common.body_in_frame`). NEVER name body parts — the remedy is identical for every
    variant, and per-landmark latching would machine-gun as confidence cycles knee→hip→knee.
  - `paused` — own key (`common.paused`), fires once on pause commit (user may still be in earshot).
  - `resume` — one-shot on a non-reactivation gate resume edge (`common.resume`, "Oke, tiếp tục nhé"
    vibe). Active-set resume normally routes back through the start-position hold, so it uses the
    countdown + `common.ready` flow instead of this line.
  - `searching` — NO voice. The setup intro already says get in frame.
  - `rotate_landscape` / `rotate_portrait` — NEW 07-11 (device-driven ruling, decisions.md
    "Phone-orientation guidance gets VOICE"): `phoneLandscape`/`phonePortrait` speak
    `common.rotate_landscape` / `common.rotate_portrait` on the standard entry latch (~1s debounce,
    10s re-cue, re-fire on re-entry, ungraced). MP3 files are present in tree 07-11 and registered in
    `commonFiles`; Nam can still listen-check wording/intonation. Feel-check on device: wrong
    orientation at set start queues the rotate line behind the intro (FIFO), it does not cut it.
  - `setup_position` — stuck-user re-tell ONLY (ruled late 07-10; landed same day). `GuidanceClass.
    setupPosition` maps to `<slug>.setup_position` on the latch machinery with `fireOnEntry: false` —
    entry fire SUPPRESSED; the ONE fire happens when `now − max(latch-start, intro-audio-end) ≥ ~10s`
    (own feel-tune constant, deliberately separate from the mid-set re-cue's 10s), no further re-cue
    (this IS the re-cue), debounced exit + re-entry re-arms exactly one more. A null intro-audio-end
    (intro still playing / never fired) blocks it outright — it can never speak over the intro. The
    `max()` means a late re-latch measures its 10s from the re-latch, not a long-gone intro-end. Fills
    the one hole the one-shot intro leaves: in frame + right orientation + not in pose = the other
    classes have nothing to say = otherwise a permanently silent dead system.
  - `holdStill` — NO voice; the activation countdown owns that state's audio (§ Setup / structure).
- **Deterministic, never a probability draw** (principle 3 — deterministic is reserved for causality and
  structure). Latch per content-key CLASS, coarse on purpose:
  - **Fire once on entry; silent while the condition persists; re-arm only after the class stays clear
    through the exit debounce; re-fire on genuine re-entry** (user complied then regressed).
  - **Two-edge debounce ~1s each way** (feel-tune) so frame-rate flicker (landmark confidence bouncing,
    `cameraFacing` near threshold) can't machine-gun. Implementation reuses the house debouncer utilities
    (StickyDebouncer/Debouncer in lib/utils/ — Nam's review directive), no new timer code. Precedent:
    StickyDebouncer 5-frame hysteresis, gate 650ms presence confirm.
  - **No wall-clock re-fire block (re-ruled late 07-10; supersedes the review's ~10s minimum re-fire
    interval).** Re-firing is governed ONLY by continuous-presence latch semantics: a debounced exit +
    re-entry is a fresh fire (fix orientation, regress 5s later → the coach responds), never blocked by
    time since the last utterance. Anti-ping-pong (instant back-and-forth flicker) is the EXIT DEBOUNCE's
    job — instant flapping can't clear it, and its width is THE designated feel-tune knob if device tests
    show fiddle-spam. Why the floor lost: every line in a slow alternation is true and actionable when
    spoken; a coach deaf to a real regression for up to 10s feels dead — the exact failure this channel
    exists to kill — and pathological fiddling is self-limiting (nobody adjusts a phone for a minute
    straight).
  - **Single pending slot, latest-wins, re-validated at speak time.** Setup lines are STATE DESCRIPTIONS,
    not events: if the condition cleared while audio was busy, DROP the line silently (the drop is correct;
    the user complied). Never FIFO-stack safety lines.
  - **No time cooldowns at all (re-ruled late 07-10; the interim ~1s post-audio gap is deleted).** Scoped
    per-content it could never bind (same-key refire is already floored by ~2s of exit+enter debounce; the
    re-cue fires at ~10s), and different keys must stay responsive. Chaining is structurally impossible:
    the single latest-wins slot allows at most two back-to-back lines, each re-validated true at speak
    time, and the sink serializes audio. This restores the collision gap (criticalFault rules) as the
    system's ONLY time cooldown. Fallback if the two-line butt-joint feels rushed on device: a small
    breath at the pump, feel-tune — never a cooldown map.
  - **Per-class grace = VOICE-ONLY, window = the intro voice's duration (re-re-ruled latest 07-10;
    supersedes the same-day "shared by voice AND UI" parity ruling).** Grace applies only to classes
    fixable in-position — graced: `body_in_frame` (incl. the lighting fold), `turnSide`, `faceCamera` —
    because firing VOICE over the setup intro is double-speak (the intro counts as the first telling;
    the first latch fire IS the escalation). The UI is NOT grace-gated: the guidance table renders the
    current signal live, from frame one, always — a user still setting up is standing and reading the
    screen, so signage is useful immediately; the UI is a live per-frame table, never a queue (the
    single-slot/FIFO semantics are voice-only). Window semantics: pinned open while the intro audio
    plays, CLOSES at intro-audio-end (no settle tail; the ~1s enter debounce is the only residual
    delay). Fallback when the intro produces no audio: fixed ~3500ms from set start (no spoken first
    telling happened). The activation-edge re-anchor (3.5s voice-quiet right after activation) is
    retained. UNgraced: `phoneLandscape`/`phonePortrait` (phone setup happens BEFORE getting into
    position; VOICED since 07-11 — the rotate prompts, see the key list), `searching` (UI-only, no
    voice), `paused`/`resume` (mid-set edges; grace is meaningless there).
  - **Mid-set re-cue:** if the same class is still latched after ~10s, ONE re-cue, then silence for real
    (shape borrowed from the no-count rule: cue → one help → quiet). The one case pure never-repeat fails
    is "user never heard it" → permanently silent dead system. Content intent is a fuller/help register;
    v1 audio replays the same file (missing-audio.md) — the fuller variant is a later recording, the
    mechanism doesn't wait for it.
  - **`paused` fires on the pause COMMIT edge**, not the first lost frame — mirrors the UI, which renders no
    banner during the person-lost grace and lets the pause overlay take over on commit. The gate's grace IS
    its entire timing (review-confirmed): no enter-debounce, no re-fire window, no cooldown on this class.
  - **`resume` is producer-emitted (review-locked):** a one-frame signal from the gate's resume edge, so
    every guidance event flows through the one `GuidanceSignal` family. The adapter-edge alternative was
    rejected (splits guidance semantics across two layers).
- **Player unchanged.** `QueuedAssetVoicePlayer` stays a dumb FIFO; the slot/latch/validate logic lives in
  the policy/adapter layer (the same seam where `sinkBusy` already serves perishable cues). `CueType.safety`
  already exists as `CueMode.always`; the latch/debounce is NEW adapter-owned deterministic logic that
  decides WHEN to hand a safety key to that channel — `CueMode.always` alone would fire every frame.

### Setup / structure (`setup`) — deterministic, once per set (behavior ruled late 2026-07-10)
Setup intro, ready countdown, set complete: exactly once at their moment, always, PER SET. (Was
`instruction`; renamed `setup` 07-09.) The adapter latches each moment so it fires exactly once (hard
rule 2). **Set-complete re-ruled 07-12 round 2: the spoken `common.set_complete` line is REPLACED by
the non-verbal end tone** (same "time!" sound as hold-end), fired as the set's final rep lands,
alongside that rep's numeral. Same moment, same once-per-set latch — only the content flips from
voice to earcon. The exercise's LAST set additionally speaks `common.exercise_complete` on top of
the tone (ruled 07-12 — the coach's goodbye; all other sets are tone-only). Wiring: docs/scratch/setup-intro-voice-impl-spec.md, after the 3-delta setup-safety spec.
- **Intro = one-shot broadcast, NOT a monitored latch.** `<slug>.setup_position` + `<slug>.active_intro`
  fire back-to-back once at set start, unconditional — the intro doesn't wait for in-frame; it IS the
  thing that tells the user to get in frame (why `searching` has no voice). It never re-fires or
  re-cues: it narrates structure, it doesn't react to state (that's the safety latch channel's job).
- **Fires every set.** Per-session dedupe on set 2+ (intro once per exercise, ready per set) is a noted
  future refinement for the multi-set flow, NOT designed now (Nam late 07-10).
- **The anti-chatter is voice grace = the intro's own duration (re-ruled latest 07-10):** while the
  intro audio plays, the voice grace window is re-pinned to now every frame; at intro-audio-end it
  CLOSES — no settle tail (the ~1s enter debounce is the only residual delay before a persisting
  graced condition speaks). The UI is not gated at all (§ setup/tracking-safety grace bullet).
  Intro-end is sink-idle with a generous 30s ceiling (the player's silent 4s default would fake idle
  mid-intro); a no-audio intro falls back to the fixed ~3.5s set-start window. Sequence the user
  hears: intro → silence while complying (screen signage live the whole time) → safety line only if
  still broken after the intro ends → countdown → set. The intro counts as the first telling; the
  first latch fire is the escalation.
- **Stuck-user backstop rides the safety channel**, not intro repetition: `setupPosition` class, one
  delayed re-tell of `<slug>.setup_position` iff still not activated ~10s past intro-audio-end, then
  quiet for real (details in the § setup/tracking-safety key list).
- **Activation countdown is VOICED (ruled late 07-10), direction RE-RULED 07-12: "ba, hai, một"**
  (counts DOWN — the up-count read as rep counting, not a countdown; Nam device call) synced to the
  3s hold, reusing `common/count_1..3.mp3` in reverse order (no new recording). Landed offsets:
  800/1600/2400ms elapsed (feel-tune; 2400 < 3000 on purpose so the last count fires before
  activation nulls the hold clock — it lands at/near the activation moment). Hold break drops
  pending count lines (`clearPending`, current line finishes) and re-hold restarts from "ba";
  activation keeps the queue so a mid-play "một" survives as the go cue. Deterministic — never
  routed through rep-count thinning. Landed 07-12 in `PolicyVoiceCoach`.
  **The countdown TERMINATES a still-playing intro (latest 07-10):** a user already holding the start
  position has no use for setup instructions — the first count to fire while intro audio is playing
  stops the sink (current + queued lines dropped), speaks immediately, and marks intro-audio-end at
  that moment (voice grace closes with it). The intro never resumes; it was consumed.
  **UI note (latest 07-10):** the activation ring shows the remaining-seconds number CENTERED, no
  'Giữ yên' caption (removed — it said nothing the ring didn't). The 07-10 voice-up/ring-down
  direction mismatch dissolves with the 07-12 re-ruling — both count down now.
- **Resume re-hold uses the same activation countdown, not the intro.** After an active-set pause or
  auto-pause, resume drops back to `notActivated` and requires the exercise's normal start position +
  hold. This preserves completed reps/logs and does NOT replay `<slug>.setup_position` +
  `<slug>.active_intro` (not a new set), but it re-arms the "ba, hai, một" countdown and `common.ready`.
  In-progress rep state is allowed to reset locally so a half-rep before pause is not counted after return.
- **`holdStill` = NO instruction line.** The countdown above is that state's audio; a "giữ yên" line
  would talk over its own countdown. A broken hold restarting the count is the causal feedback.
  (`common/hold_still.mp3` exists on disk; unwired by design.)
- **Completion line = `common.set_complete`** (landed choice; legacy spoke `common.exercise_complete`,
  both registered). Forward-compatible with multi-set (set_complete per set, exercise_complete at
  session end) — but LISTEN-CHECK pending (Nam): if the recording implies "next set coming", the
  single-set pilot should speak `exercise_complete` instead.

### Rep count — REGISTRATION: every landed rep is counted (re-ruled 2026-07-11)
Supersedes the thinning design below-the-line (07-07 draw + 07-08 pilot retune). On device the count
turned out to be TRUST feedback, not pacing chatter: users don't watch the screen (new tech, lying
down), so the spoken number is their only proof a rep landed — a silent rep is ambiguous between
"counted but quiet" and "didn't register". That re-classifies the count under principle 3
(deterministic = causality/structure; a rep landing IS the causal event), not principle 2 (no
metronomes — which governs OPTIONAL cues; a PT counting every rep is just a rep counter). Decision:
decisions.md 07-11 "Count = registration".

- **Every landed rep speaks its number, deterministically and personality-immune** (fleet default
  base 1.0 short-circuits the roll, consuming no RNG draw). The coach's non-robotic feel lives in the
  stochastic outcome layer on top (praise/faults/hustle), unchanged.
- **Anchors + relief valve survive in code as guards** for any future explicitly re-thinned config
  (base < 1.0): rep 1 and the final 2 always fire, the relief valve still backstops. Not active at
  the default.
- **The non-verbal tick is RETIRED** (was hard rule 4, decided-never-built): with no skipped counts
  there is nothing to tick for; a number is self-evident where a tick had to be learned.
- Superseded history, kept for the record: 07-07 thinning draw → 07-08 pilot retune (base 0.50 /
  +0.10 / cap 1.0, no discrete valve — the cap-0.90+relief-6 shape was itself a fix for the 2-skip
  floor).

### Praise — variable-ratio, truly-clean reps only
(Reconciled 07-10 to the 07-08 glute-bridge lock — decisions.md "glute-bridge-first behavior lock";
the section previously still showed the pre-retune numbers.)
- **Eligible:** truly clean rep only (`correctForm` AND zero measured faults — a soft-fault rep gets
  the soft nudge, never praise; data honesty).
- **Base 0.50** (07-08 retune, was 35% — "lean into praise"), hunger +10% per clean-but-unpraised
  rep, capped at 85%. The D8 praise-probability × formScore multiplier is DELETED (07-08).
- **Relief valve — DROPPED 2026-07-11 (Nam; decisions.md).** The "5+ clean unpraised → next ≥90%"
  valve never existed in any code path and is not to be built. Hunger saturates first: base 0.50 +
  0.10/rep hits the 0.85 cap by ~rep 4-5 of an unpraised clean streak, so the valve would only nudge
  0.85 → ≥0.90 — near-invisible. Consistent with the 07-08 "fewer hard rules" direction.
- **Hard rule:** never praise two consecutive reps. (Implemented.)
- **Content:** rotating pool, no immediate repeats; small acknowledgements (`common.good_*`) plus
  bigger ones (`common.great_1/2`). Implementation note: the "bigger lines on harder moments" intent
  is currently a flat 50% big-pool bias on any clean rep (formScore is binary today) — feel-tune on
  device, no late-set weighting exists yet.
- Expected feel: praise lands on average every ~2-3 clean reps, actual gaps vary, never rhythmic.

### Critical fault (`criticalFault`) — real-time, deterministic first reaction, escalating
(Was "Correction". A critical fault = a measured fault with `affectsForm==true`.)
- **Fires REAL-TIME (2026-07-09):** the instant the fault is known, not batched at rep-completion.
  Continuous faults (e.g. hyperextension, neck-lift — the latter flipped soft→critical in the
  07-09 lavish review; the code flip rides the reminder implementation) fire mid-rep, while the user
  can still act; peak-
  measured faults (e.g. insufficient hip-extension) are only knowable at rep-end and fire then.
  Supersedes the earlier "post-rep, per guardrail" — critical faults ARE the real-time safety class.
- **Bandwidth:** minor wobble inside tolerance = silence. Only threshold-crossing faults speak.
- **First occurrence of a fault this set: ALWAYS cued, deterministically (100%)** — causal reaction
  (principle 3). (`firstOccurrenceCertain`.)
- **Same fault persists:** re-cue with rising pressure — persistence escalates ~25→55→85%. No discrete
  relief valve (redundant once first=100%). Phrasing firms with persistence, tone stays warm.
- **Peak faults = next-rep guidance:** a peak fault can't be acted on in its own rep, so it fires at
  rep-end via RepLog and is framed as "do it right next rep." That framing IS its instruction (Nam
  2026-07-09): peak faults are EXCLUDED from the next-rep instruction layer (below) — a reminder on
  top of the rep-end line would double-speak. Supersedes the earlier plan to route peak faults into
  the parked post-rep-instructions feature.
- **Multiple faults on one rep (revised 2026-07-09, supersedes "only the highest-priority one
  speaks"):** exclusivity is per-MOMENT, not per-rep. At one moment, highest priority wins as before.
  A SECOND outcome cue may voice later in the same rep iff ALL of: it is a `criticalFault` (safety
  class — soft/praise/hustle never get the second slot); it is a different fault than anything
  already voiced this rep (same fault never re-voices in-rep; cross-rep persistence owns repeats);
  the collision gap has passed; and fewer than 2 outcome cues have voiced this rep. E.g. glute
  bridge: "knees wider" on the raise, "neck down" on the lower — normal coaching, not nagging.
- **Collision gap (the system's ONLY time cooldown):** an outcome cue may not start until the
  previous outcome cue's audio ENDED + ~0.5s silence (cooldown = line length + buffer, so long
  lines can't chain). Applies to outcome-after-outcome adjacency across rep boundaries too. Nothing
  else needs one: count/setup fire at structural moments, and the sink already serializes audio.
- **Blocked ≠ spent:** a critical suppressed by the gap or the cap-2 keeps its first-occurrence
  credit (its next occurrence still fires deterministically) and still counts in the post-set
  summary. v1 drops the blocked line (perishable); no delayed replay.

### Soft fault (`softFault`) — non-critical nudge, real-time, hunger-shaped
NEW 2026-07-09 — the 3-way classifier's middle bucket. A soft fault = a measured fault with
`affectsForm==false` (a warning, not an error). Exists so a rep with a minor measured fault is neither
praised as clean (data honesty) nor scolded like a critical one.
- **Fires REAL-TIME**, same signal as `criticalFault`, but **probabilistic: hunger + base, NOT
  first-occurrence-deterministic** (gentler cadence). Glute pilot: base 0.20, hunger +0.08, cap 0.55.
- Warm nudge tone, persona pattern `Tốt, bạn [action] chút nữa là đẹp.` (e.g. "Tốt, bạn hạ hông chậm
  hơn chút nữa là đẹp."). Own audio (`<slug>.<id>_soft`); wordings in missing-audio.md.
- Praise is thereby gated on TRULY clean (`correctForm && no faults at all`).

### Next-rep instruction (`reminder`) — shape LOCKED + design REVIEWED 2026-07-09
REPLACES the UI `addInstruction` layer (`ExerciseBase.instructions`), which is DELETED per the 07-09
lavish review — a mid-exercise user can't look at the screen; instructions are voice-only now. Scope
(code landed 2026-07-10): live phase copy formerly stored as type `Status` now lives in
`ResultIssues.phaseStatus`; it is not a post-rep instruction surface.
(decisions.md 07-09): a CONTINUOUS critical fault that was cued real-time in rep N earns a short
feedforward reminder around the start of rep N+1 ("lần này hạ sâu hơn chút nhé") — the PT chain of
correcting mid-rep, then reminding at the next attempt, then watching. Peak faults excluded (their
rep-end line IS the instruction, above). Confirm-after-fix praise DEFERRED (07-09; when it lands,
prefer a praise-pool variant over a new cue type).
- **Firing moment DECIDED (Nam 07-09): the rep-start COMMIT EDGE** — the state-machine transition
  out of rest into the rep's FIRST movement phase, whatever that is per exercise (glute bridge:
  bottom→ascending + the descending→ascending fast-path; a squat would be standing→descending). Why:
  on continuous tempo rep-end and rep-start coincide anyway; rep-end already hosts count + outcome;
  the commit edge is the empty slot and lands the cue adjacent to the action (research §3b). On
  glute bridge this is the same edge hustle fires on (its first phase IS its effort phase) —
  implement ONE shared "rep attempt started" boundary feeding both there. Where an exercise's
  effort phase differs from its first phase (squat), hustle's edge moves to the effort phase
  (07-09 lavish review) and the two cues stop competing.
- **Reminder outranks hustle at the commit edge (Nam 07-09).** Outcome-class: cap counts, collision
  gap, blocked ≠ spent all apply; it carries the fault's contentKey, so the same-fault-once-per-rep
  rule already blocks reminder + re-correction double-speak within rep N+1.
- **Same-content consecutive-rep ban (Nam device ruling 07-12, hard rule 12):** a reminder for fault
  X on rep N is NEVER followed by a reminder for the same X on rep N+1. A DIFFERENT fault on rep N+1
  is explicitly fine (shoulder this rep, legs the next — good coaching); the adapter skips the banned
  candidate in the priority pick so selection falls through to the next eligible fault, or to silence
  if none. Ban expires after one rep (X, quiet, X again is legal) and resets per set. Landed 07-12
  in the adapter candidate selection; the shared policy is unchanged.
- **Reminder must claim the slot BEFORE the in-progress live-fault drain (ordering fix 07-11).** The
  adapter now evaluates the rep-start reminder at the commit edge before draining that rep's live
  criticals, so the feedforward reminder wins the outcome slot and then same-fault-already-voiced
  suppresses the re-correction — the "remind, don't re-nag" rhythm the point above describes. The old
  drain-first order let a CONTINUOUS critical (neck_head, present from the start of nearly every rep)
  grab the slot first, so the reminder lost to `second-outcome-slot-is-critical-only` every rep and was
  near-silent on device (Nam heard it as "extremely rare"). First-occurrence criticals are unaffected —
  a fault with no prior-rep sighting has no eligible reminder, so nothing preempts its real-time cue.
- REVIEWED 07-09 (next-rep-instruction-design.html rev 2, all four review questions resolved):
  named `CueType.reminder`; streak-first deterministic, then base 0.30 / +0.15 / cap 0.65
  (feel-tune); pilot faults hyperextension + neck_head (flipped critical in the review); NEW short
  recordings required — the reminder slot is the tightest window in the system (~1–1.5s at the
  rep-start commit edge; existing fault lines run 1.9–4.8s and cannot double as reminders). Persona
  pattern `Lần này bạn nhớ [action] nhé.` (Nam 07-10) runs longer than the old ≤7-word cap, so the
  constraint relaxes to "keep ~1.5s spoken, record brisk" (the 10-word hyperextension reminder is the
  longest line in the tightest slot); both wordings FINAL (missing-audio.md).
  Code landed 2026-07-10: `VoiceScript.repStartPhaseKeys` + `reminderPools`, `CueType.reminder`,
  shared `PolicyVoiceCoach` edge before hustle/phase cues, empty glute pools for silent Stage A, and
  `neck_head` now `affectsForm: true`.

### Hustle / effort push — DECIDED 07-09, FLEET-ENABLED 07-12 (hesitation-armed, commit-fired)
- **Status:** behavior decided 07-09 (decisions.md); enabled in the glute pilot 07-11 after Stage-B
  device data looked sane, then enabled across all 24 rep exercises in Tier 3 on 07-12. Hustle is
  encouragement when a user hesitates and recommits, not pressure to move harder, so controlled and
  stability exercises use it too. Tuning
  base 0.50 / step 0.20 / cap 0.90 (quiet-side, persistence-shaped: lone hesitation ~coin flip,
  stacked hesitations climb), with a post-fire negative-hunger backoff of 2 so the next eligible pushes
  are muted without a fixed rep cooldown. Pools `common.push` (generic) + `common.one_more_rep`
  (target-proven final). All feel-tune. MP3 files are present in tree 07-11 and registered in
  `commonFiles`; Nam can still listen-check wording/intonation. The old final-rep push stays rejected
  (07-08, robotic on a rep counter) — this is the grind-triggered version.
- **Fast-path baseline guard (07-11):** inter-rep gaps below `kMinArmGapMs` (~800ms — the glute
  descending→ascending fast path emits ~0ms "gaps") are excluded from the baseline sample AND can't
  arm. They are not real hesitation and, left in, deflated the baseline median so genuine gaps looked
  stretched. (Confirmed on device: the log showed 0/101ms gaps being injected.)
- **Arm on hesitation — never speak mid-gap.** The inter-rep gap stretching past this set's own
  baseline (median of the set's first 2-3 gaps) arms hustle. The gap is a BEHAVIORAL "do I go again"
  signal, not a fatigue meter (spontaneous inter-rep pause is unstudied; 0-5s pauses buy ~no
  physiological recovery — research §3). Speaking into the hesitation would read as surveillance.
- **Fire on commit — at the exercise's EFFORT PHASE (refined 07-09 lavish review).** The armed cue
  rolls at the first entry into the exercise's declared effort phase (`VoiceScript.effortPhaseKeys`)
  after the armed gap, landing the push on the force moment the user just committed to. Glute
  bridge: the raise — which is also the rep's first movement phase, so hustle and the next-rep
  reminder DO share one commit-edge boundary in the pilot (and the reminder wins it, above). An
  exercise whose effort phase is not its first phase (squat: rep starts descending, force is the
  ascent) separates the two edges — the reminder stays at rep-start, the push tracks force. If the
  next rep never starts, hustle never fires — impossible to hustle someone who finished or quit.
- **Void-on-absence (07-09 lavish review).** Presence-loss or pause during a gap VOIDS it: it cannot
  arm hustle and is excluded from the baseline median. An out-of-frame errand and a walk-away rest
  are indistinguishable, and both kill the "hesitating in position" read — voiding is wrong in
  neither case.
- **Final-rep paired push (07-09 lavish review, second flavor).** When the count anchor fires with
  exactly one rep remaining, the push MAY pair in the same breath ("Chín — cố lên!" / "Một cái nữa
  thôi!" — target-proven). Stochastic quiet-side roll, rotating final pool, NEVER deterministic (a
  guaranteed finish line every set is the rejected 07-08 metronome). A fired pairing consumes the
  push for that transition — no second fire at the final rep's effort-phase entry.
- **Persistence-shaped, no per-set cap, stochastic post-fire backoff (07-11 feel-tune).** First
  hesitation = low odds; stacking silent hesitations climb the probability (criticalFault-persistence
  shape). Firing applies negative hunger rather than a deterministic "skip N reps" cooldown: with the
  current glute tuning the next eligible attempts roll below baseline, then climb back through normal
  silence. A grinding finish can still earn 2+ pushes — the once-per-set cap stays dropped
  (encouragement's effect is in-the-moment and dies when the voice stops; a one-shot is the least
  effective placement). Base quiet-side; personality applies.
- **Rep-duration slowdown is not a trigger** for bodyweight (weight 0, glute pilot); shelved as a
  loaded-movement corroborator for when squat migrates.
- **Line honesty:** "Một cái nữa thôi!" only when `targetReps` proves it's the final rep; otherwise
  "Cố lên!". Slot rules unchanged: lowest outcome priority, never the second in-rep slot.
- **Numbers stay feel-tune:** the current glute values are recorded in canonical-numbers for freshness,
  but gap-stretch threshold, base, step, cap, and backoff remain device-tunable.

### No-count (attempt didn't register) — reliable, but never naggy
- First and second no-count: always cue (trust info — user must know it didn't count), rotating
  phrasing.
- **Two consecutive no-counts:** stop repeating "chưa tính" — switch once to instructional help
  (why it's not counting, what to change), then stay quiet until something changes. Repeating the
  same failure line three times is nagging, not coaching.

## Stacking order within one rep-moment

count (maybe) → then at most one outcome cue per MOMENT: **criticalFault > softFault > praise > hustle**.
The next-rep instruction arms only at the rep-start commit edge, where its only possible rival is
hustle; the reminder wins there (Nam 07-09).
(if several are eligible at the same moment, higher wins; the others simply don't happen — no queueing
of stale compliments). Count is not an outcome cue and may co-occur. Later in the same rep one more
`criticalFault` may voice under the second-slot rules (different fault, collision gap, ≤2 per rep).

## Fade (provisional — phase 2, needs per-user skill state)

Direction from the literature (faded 100→75→50→25% was the only schedule with lasting retention):

- **New-to-user exercise (first ~2 sessions):** praise and correction hungers ×1.3 (talks more).
- **Mature exercise (weeks of clean history):** ×0.7 (talks less; silence = mastery signal).
- Set-level: no extra fade in v1 — sets are short (≤15 reps); hunger shaping already spaces cues.

Marked provisional: ship v1 with the multipliers fixed at 1.0 and the hook present.

## Variant pools (deferred — phase-2-style, NOT scheduled)
Multiple recordings per content key so repeats don't sound verbatim. Matters most on the DETERMINISTIC
channels — reminders, setup/tracking-safety, soft — where a verbatim repeat is where the robot shows
(probabilistic cues hide their repetition behind varying gaps; praise already rotates a pool). A
nice-to-have noted for the future, on no current checklist. (Nam, 2026-07-10.)

## Hold-based exercises (time-based family) — DECIDED 2026-07-11, re-ruled 07-12, High Plank pilot implemented
Nam's rulings via the hold-design lavish review + chat (07-11), plank-model re-ruling 07-12; full
design in [hold-exercise-voice-design.html](hold-exercise-voice-design.html) (v2), impl spec
docs/scratch/hold-voice-impl-spec.md (Codex), decision records decisions.md 07-11 "Hold-based voice
behavior LOCKED" + 07-12 "Holds count holds as REPS". High Plank = pilot. The hold mappings:

- **A set = N HOLDS counted as REPS (plank model, 07-12; supersedes "one continuous hold").**
  Forearm Plank is the reference implementation (`Plank(maxRep)`: each completed hold →
  repCount+1 + a per-hold RepLog, brief in-exercise breather between holds). High Plank migrates
  to maxHolds × holdSeconds (per-hold seconds catalog-driven). **Each completed hold speaks its
  number — rep count = registration (hard rule 3) applies verbatim.** The formal multi-set flow
  sits above, unchanged.
- **Clock: pose-validity gated, not form-gated.** Outer ring (anti-cheat / "still in the pose")
  gates time accrual; inner ring (form metrics) coaches real-time while the clock RUNS. Only
  cheating stops earning. Fault-seconds accounting keeps the summary honest. Reverses the shipped
  High Plank perfect-timer.
- **Pause/re-hold discards the current partial hold; in-exercise drop/re-entry does not.** A base
  pause means the user stopped the attempt and must earn a fresh hold from zero after the normal
  start-position re-hold. Completed hold reps/logs survive. A brief outer-ring break inside the
  exercise remains pause-and-resume. The hold timer drops any frame delta outside the canonical
  range in `canonical-numbers.md`, so pause/camera gaps cannot become earned time.
- **Within each hold: voice milestones** (deterministic, personality-immune, earned-time
  crossings, relative to PER-HOLD seconds): halfway + "còn 10 giây" (the latter only when the
  hold is long enough for it to be distinct). Voice speaks REMAINING; UI ring unchanged and
  counts down independently — the voice/UI mismatch is accepted (re-ruled 07-12 round 2): the
  voice only marks milestones and the final countdown, never tracks every second.
- **Hold-end (re-ruled 07-12 round 2) = SPOKEN countdown + end tone:** "năm, bốn, ba, hai, một"
  on the last 5 earned seconds (reuses `count_5..count_1`), then one distinct end tone as earned
  time hits the per-hold target (the count line then registers the landed hold). The final-3
  earcon pips are DROPPED for v1; no continuous tick. The end tone stays a separate lightweight
  channel — never queued behind voice lines — and EXTENDS to rep-based exercises (RULED 07-12
  round 2): the same "time!" sound REPLACES the spoken set-complete line, fired as the set's
  final rep lands. Hold sets inherit for free — the last hold's per-hold tone IS the set marker;
  no spoken set-complete anywhere.
- **Inter-hold rest (RULED 07-12, refined same day):** rest START silent (amber RestCountdownRing
  is the signal). Rest-timer completion fires the rest-end tone (assets/audio/common/
  rest_end_tone.mp3, timed edge, honest) — then the re-arm phase REUSES set-start's setup_position
  behavior WHOLE (UI + its voice), superseding the earlier voice-silent ruling (device-tune #3,
  07-12): the existing "get into position" UI + voice fire ONLY when the user isn't posed (quiet
  when posed, exactly like set-start), then the SAME "ba, hai, một" activation countdown; the next
  hold's clock starts when it lands. No predictive spoken rest countdown. The next-hold reminder
  queues behind "một", landing in the new hold's first seconds. HYBRID modality: former
  hold-based exercises render time rings AND the rep-tracking UI. Full record: decisions.md
  "Inter-hold rest RULED" + its REFINED bullet.
- **Milestone outcome slot is deterministic (device-tuned 07-12):** every milestone time line is
  followed by exactly one outcome. Clean since the last milestone → praise, unless the previous
  milestone was praise, then hustle; struggling or final stretch → hustle. The hold adapter passes
  `CueContext.force` only for this follow-up, bypassing the ordinary roll, sink-busy drop, collision
  gap, and second-outcome suppression so a second milestone in the same hold cannot land silent.
  Rep-path praise/hustle odds and guards are unchanged. A rep-counted-hold script must provide both
  pools; empty praise/hustle pools log once in release and assert in debug instead of failing silent.
- **Temporary phase-key contract (pre-scale guard):** until the shared hold engine owns a typed
  phase, rep-counted holds must report `setup`, `holding`, `dropping`, `resting`, or `reArming`.
  Shared constants replace scattered literals, and the adapter checks every hold phase: an unknown
  key logs once in release and asserts in debug. This is deliberately not the deferred engine/enum
  extraction.
- **criticalFault/softFault: identical real-time rules**; persistence + same-fault-once bookkeeping
  unit = the hold, which under the plank model IS the rep — the rep-fleet machinery (same-fault-
  once, cross-rep persistence, reminder at the next hold's re-entry into holding) maps directly.
- **Hustle flavors:** milestone-paired (primary) + final-third pose-break arms / re-hold commit
  fires (secondary, quiet-side).
- **No timeout ending.** Walk-away = presence gate; stuck = setup_position re-tell; give-up = quit.
- Setup intro / activation countdown / GuidanceSignal safety: modality-independent, unchanged.
  Set-complete: modality-independent but re-ruled 07-12 round 2 — the end tone, not a spoken line
  (§ Setup / structure). Yoga/stretch register deferred (VoiceScript config: reduced milestones,
  empty hustle).

## Post-set — deterministic, and the richest moment
End tone always (07-12 round 2 — the non-verbal "time!" sound replaced the spoken set-complete
line); then the summary carries the dense feedback: single dominant fault to
fix next set + one highlight. (Summary/terminal feedback beats per-rep commentary for retention —
this is already the interpreter's job, unchanged.)

## Hard rules (the complete list — everything else is probabilistic)

| # | Rule |
|---|---|
| 1 | No separate FORM-fault safety cue — a `criticalFault` firing real-time IS the injury reaction. (Setup/tracking-safety is a SEPARATE deterministic channel, rule 11.) |
| 2 | Setup intro / ready / set-complete exactly once PER SET, always (`setup`) — set-complete's content is the non-verbal END TONE since 07-12 round 2 (replaced the spoken `common.set_complete`), fired as the final rep/hold lands; the intro is an unconditional one-shot broadcast at set start, never latched or re-fired; activation countdown "ba, hai, một" (counts DOWN, re-ruled 07-12) voiced deterministically synced to the hold (break → drop pending + restart from ba; first count fired while the intro still plays TERMINATES the intro); `holdStill` has no instruction line — the countdown is that state's audio (stuck-user re-tell → rule 11) |
| 3 | EVERY landed rep is counted, deterministically and personality-immune (registration ruling 07-11; supersedes anchors+thinning — anchors/relief stay only as guards for an explicit re-thinned config) |
| 4 | ~~Skipped counts still get a non-verbal tick~~ RETIRED 07-11 — no skipped counts exist under rule 3 |
| 5 | First occurrence of a fault in a set is cued deterministically (100%); a fire blocked by the collision gap/cap keeps the credit — next occurrence is still deterministic |
| 6 | Never praise two consecutive reps |
| 7 | Max one outcome cue per MOMENT (`criticalFault` > `softFault` > praise > hustle); a 2nd in-rep cue only as a `criticalFault` on a different fault, ≥0.5s after the previous outcome line's audio ends, ≤2 voiced outcome cues per rep |
| 8 | Hustle (enabled in glute pilot 07-11): arms only on a stretched inter-rep gap, fires only at entry into the exercise's declared effort phase — never mid-gap, never after the set ends; a gap touched by pause/absence is void (no arm, no baseline); the final-rep count-paired push is a roll, never guaranteed; "một cái nữa" only when the counter proves the final rep; no per-set cap; after a fire, negative hunger mutes the next eligible pushes without a fixed cooldown |
| 9 | After 2 consecutive no-counts, switch to help, don't repeat the failure line (parked) |
| 10 | Every cue is backed by a measurement from this set |
| 11 | Setup/tracking-safety (07-10) is VOICE via a typed `GuidanceSignal`, deterministic: latch per content-class (`orientation` / `body_in_frame` / `paused` / `resume` / `rotate_landscape` / `rotate_portrait` (07-11), plus `setup_position` as a stuck-user re-tell: entry-fire suppressed, ONE fire iff continuously latched ~10s past intro-audio-end, then quiet; `searching` + `holdStill` = silent), fire once on debounced entry, silent while held, re-arm past the ~1s exit debounce, re-fire on genuine re-entry — NO wall-clock re-fire block and NO post-audio cooldown (re-ruled late 07-10; debounces + the single re-validated latest-wins slot + sink serialization are the only limiters); ONE fuller re-cue after ~10s continuously latched then silent; per-class grace is VOICE-ONLY and spans exactly the intro voice's playback (closes at intro-audio-end, no settle tail; ~3.5s set-start fallback when no intro audio; graced: body_in_frame/turnSide/faceCamera; ungraced: phone orientation, searching, paused, resume) — the UI renders signage live and ungated; `paused` fires on the pause commit edge with NO extra timers; active-set resume re-enters the start-position hold and re-arms countdown + ready instead of speaking `common.resume`. All timings feel-tune, none canonical. |
| 12 | A reminder never repeats the same fault content on two consecutive reps (07-12) — a different fault's reminder on the next rep is allowed; if the banned fault is the only candidate, the rep gets no reminder; the ban expires after one reminder-free rep and resets per set |

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

- Praise base 0.50 / hunger +10% / cap 85% (07-08 retune) — feel-tuning, literature only says
  "30–50%, variable"; 0.50 sits at the chatty edge of that band, watch it on device. (The praise
  relief valve question is RESOLVED — dropped 07-11, never to be built; see § Praise + decisions.md.)
- ~~Count-skip on middle reps~~ RESOLVED 07-11: counting is registration, every rep speaks (hard
  rule 3). The open question inverted — if every-rep counting feels too chatty on device, the answer
  is NOT re-thinning (trust leak); it would be shorter/softer count recordings.
- Correction persistence curve 25→55→85% — direction is research-backed, the exact slope is mine.
- Hustle gap-stretch threshold / base / persistence step — deliberately unset (07-09); must come from
  ExerciseLogger timestamp calibration, not taste. The risk to watch: a hard set's EARLY gaps already
  long, inflating the baseline so hustle never arms.
- Fade multipliers ×1.3 / ×0.7 — provisional, phase 2 anyway.
- Personality scalar range 0.5–1.5 — bounds are a guess; too-low values may starve praise entirely
  on short sets even with the relief valves.
- Collision gap 0.5s post-audio + cap 2 outcome cues/rep — buffer is pure feel, tune on device; the
  cap should essentially never bind on a real set (if it does, the gap is too small).
- Setup/tracking-safety (07-10) timings — ALL feel-tune, none canonical:
  - enter/exit debounce widths (~1s each) — too short machine-guns on flicker; too long and the user is
    silently blocked for a beat before the coach reacts.
  - EXIT-debounce width doubles as the anti-ping-pong knob (re-ruled late 07-10 — it replaced the deleted
    MIN_REFIRE interval and post-audio gap): if device tests show phone-fiddling alternating lines too
    fast, widen the exit debounce; never reintroduce a wall-clock block.
  - voice grace = intro duration (latest 07-10) — the old fast-user risk is mostly gone (a fast holder
    terminates the intro via the countdown, closing grace with it); residual watch items: the ~3.5s
    set-start fallback when the intro has no audio, and the retained 3.5s activation-edge re-anchor —
    tune both against device feel.
  - 10s mid-set re-cue interval — the "user never heard it" backstop; if it feels naggy, lengthen it, don't
    drop it (dropping re-cue reintroduces the permanently-silent-dead-system failure).
  - stuck-user re-tell delay (~10s past intro-audio-end) — too short fires on slow-but-normal settlers
    (getting down on the floor legitimately takes a while after the intro ends); watch real setup times
    on device before tightening.
  - pause-commit edge — review-confirmed timer-free (the gate's person-lost grace is the only timing);
    verify the implementation didn't stack a second debounce on it.
