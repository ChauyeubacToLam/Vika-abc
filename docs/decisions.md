# Decisions — append-only ledger

Rationale for calls that aren't obvious from the code. Append new entries at the top. Mark superseded
entries, never delete them. `git log` is the fine-grained history; this is the "why", not the "what".

Template:
```
## YYYY-MM-DD · <short title>
Status: active | superseded by <entry>
Decision: <what we chose>
Why: <the reasoning, incl. Vietnamese-market angle if relevant>
Alternatives considered: <what we rejected and why>
```

---

## 2026-07-12 · ADR: two-modality catalog (rep-based + hybrid hold) + hybrid progression
Status: active — Nam approved P1 (07-12): decisions 1 (two modalities) + 2 (seconds-axis hybrid
progression) are committed and cleared for Codex. Decision 3 (count==1 UI) rides with P4; forks
(a) label copy, (b) rep-based /1 rows, (c) bear-plank clock leniency remain OPEN and gate P3/P4,
not P1. Resolves the OPEN impl item in "Holds count holds as REPS" (how a plank-model row carries
both hold count and per-hold seconds) and the prod-severity `prescribeVolume` blocker in state.md.
Problem: the catalog has three shapes — reps-only, seconds-only, and (since the plank-model flip)
both-fields on high_plank/bear_plank. Every consumer enforces exactly-one-of
(progression_rules.dart:348-349 discriminators, generator tool exit(1) guard), so the two hybrid
rows crash plan generation (`prescribeVolume` StateError at recommendation_engine.dart:112) while
being fully pool-eligible (verified 07-12: selection filters never check modality). Scaling holds
adds N more hybrid rows; three modalities means every consumer carries a third branch forever.
Decision (recommended, per Nam's framing 07-12):
1. TWO modalities only. `base_reps` is ALWAYS set (unit count per set). `base_seconds` present ⇔
   HYBRID hold (each unit = one hold of that many seconds); absent ⇔ rep-based. The four
   seconds-only rows (butterfly, seated_forward_fold, side_plank_dip, sphinx) get `base_reps = 1`:
   a long hold is the 1-unit case of reps-of-holds, same machine, different constants. The
   `isHoldBased` discriminator dies.
2. Hybrid progression: SECONDS is the only progression axis — existing hold path (tier start →
   per-tier cap interpolation, deload factor, carry-over floor, variant unlock on the seconds cap).
   Hold COUNT is a structural constant from the catalog, like sets: no tier bump, no weekly
   interpolation.
3. UI rule: hold count == 1 renders as pure time (no rep hero, no "1 ×"); count > 1 renders the
   hybrid two-surface UI (High Plank pattern: time rings + rep hero).
Why: one invariant (`base_seconds != null` = hold modality) that every consumer can check instead
of three shapes — the current crash IS the drift cost of shape #3. Progressing seconds matches how
the PT catalog is authored (per-tier `max_seconds_*` columns already exist) and keeps progression
one-dimensional; hold count staying fixed mirrors how sets are prescribed.
Alternatives considered: keep three modalities and add hybrid branches at every call site
(rejected — permanent third branch, and the crash shows consumers won't stay in sync); progress
hold count then seconds, or redistribute total time (rejected — two-axis progression with no PT
basis; revisit with session data); default null reps to 1 in code without the data flip (rejected —
the exactly-one guard keeps lying to readers and the catalog generator still exits).
OPEN forks (Nam):
(a) Hybrid volume label copy (e.g. "3 hiệp × 3 lần × 20 giây") — spec proposes, Nam owns copy.
(b) Rep-based rows with reps=1 (downward_dog, prayer_pose, raised_arms) show a "/1" rep hero
    today; left unchanged this pass (hiding it would leave them no progress surface).
(c) Bear plank's clock flips form-gated → pose-validity-gated two-ring when it adopts the shared
    engine. That follows the locked hold design but is MORE LENIENT than its current scoring
    (back/weight faults become coached, not clock-stopping) — PT sanity-check wanted.
Sequencing: P1 engine+data unbreak (progression rules hybrid path, variant unlock, generator
guard, SQL base_reps=1 ×4, regen JSON) → P2 hold-engine extraction from High Plank
(behavior-preserving) → P3 bear plank onto the engine + its voice pools (second consumer proves
the contract) → P4 UI generalization (count==1 pure-time rendering, intro band, labels).
Artifacts (Nam: lavish skipped per 07-12 instruction; design annotations live inside the specs):
docs/scratch/hold-hybrid-modality-codex-spec.md + hold-engine-extraction-codex-spec.md.

## 2026-07-12 · High Plank pre-scale safety contract
Status: active — implemented and covered before the hold pattern is cloned.
Decision:
- A base pause/re-hold discards the CURRENT partial High Plank hold. Completed holds, rep logs, and
  set progress survive. This is intentionally different from an in-exercise `dropping` wobble,
  which pauses and resumes earned time. The reset runs in `onPauseReactivationStarted`: despite the
  name, the base calls it on the resume edge before any exercise update, which is the earliest safe
  point to kill the stale tick.
- `TimerMetric` and `HoldSecondsAccumulator` share the same valid inter-frame delta range. Gaps
  outside that range are dropped, so a pause, camera interruption, or janky frame cannot be credited
  as held time by one clock while the other rejects it.
- Until the deferred shared hold engine owns a typed phase model, rep-counted holds use one named
  string contract (`setup`, `holding`, `dropping`, `resting`, `reArming`). The voice adapter checks
  every reported phase and fails loud: one release log plus a debug assertion for an unknown key.
- Rep-counted-hold milestone praise and hustle pools are required configuration. Empty pools get the
  same release-log/debug-assert treatment; no fallback line is invented. Rep exercises never enter
  either hold-only guard.
Why: Reset + delta-gating is defense in depth for data honesty; either one blocks the false-perfect
completion. Discarding the partial attempt matches the base pause ritual: the user must re-prove the
start pose and earn a fresh continuous hold. The string/pool guards make future hold wiring fail
visibly without prematurely extracting a one-consumer state machine or hiding missing content behind
a generic fallback.
Alternatives considered: reset only after the resume hold completes (rejected — stale state survives
too long); clamp a large frame gap (rejected — it still invents earned time); typed hold phase enum now
(deferred to the bear-plank/shared-engine design); fallback praise/hustle content (rejected — it masks
an invalid voice footprint).

## 2026-07-12 · High Plank device-tune (first on-device pass) — 3 fixes + 1 dropped
Status: active — Nam's calls from the first High Plank device smoke (07-12). The pilot works
end-to-end (3 holds, countdown, both tones, rest re-arm all confirmed in-log); these are polish.
Decisions:
1. **Within-hold milestone ALWAYS speaks an outcome — never silent.** Supersedes the round-2
   "neither wins → time line alone" bullet: at each milestone the time line is followed
   DETERMINISTICALLY by praise OR hustle (no probability miss, no silent slot). Keep the
   clean→praise / struggling-or-final-stretch→hustle switch and never-praise-twice; when the
   switch would land on a suppressed/failed roll, fall through to the other so SOMETHING always
   fires. (Device read: "Được một nửa rồi" landing alone in silence felt dead — Nam wants an
   encouragement every mark.)
2. **Outer-ring needs a HORIZONTALITY gate, not tighter angle thresholds.** A standing/walking
   user reads as a valid plank because shoulder-hip-ankle / arm / knee angles are all ~180° when
   upright too — geometrically identical to a plank on the current outer-ring terms, so no
   threshold value catches "walked around." Fix: add a torso-orientation term (plank torso is
   horizontal; standing is vertical) to the outer-ring exit so standing drops the hold. Nam's
   "tighten the threshold" instinct won't work; the orientation gate is the real fix.
3. **Re-arm REUSES the existing set-start setup instruction WHOLE — UI *and* its voice — nothing
   new (Nam clarified twice).** Not a bespoke silent ring: use the setup_position machinery the
   exercise already has. Because it's set-start's machinery, it behaves exactly like set-start —
   when the user is in frame + correct orientation but not yet in the pose, the existing "get
   into position" UI + its voice fire; when the user IS already posed, it goes straight to 3-2-1
   (quiet). So the voice appears ONLY when the user actually needs the prompt, never on a clean
   re-arm — no per-hold spam. "Just make sure that UI and that voice work correctly after a
   break." Current bugs blocking that: (a) resting→reArming only advances inside processPose, so
   leaving the frame freezes the machine in resting (ring stuck at 0); (b) the re-arm presented a
   bespoke silent "Vào tư thế" ring gated behind guidanceCopy==null instead of reusing
   setup_position. Fix: drive rest completion on a pose-independent time check, and publish the
   real setup_position guidance (UI + voice) from re-arm so it IS set-start's behavior.
   Mechanism confirmed (Opus, verified in code): the setup-voice producer
   `_SetupSafetyVoiceController.processFrame` is SIGNAL-driven off `exercise.guidanceSignal` (not
   exerciseState), runs every frame incl. mid-set, so High Plank just re-emits
   `GuidanceSignal.setupPosition`/`holdStill` from reArming — no change to checkExerciseState or
   the base voice controller, can't leak into set-start. Copy = set-start's own "Vào vị trí".
   TIMING CHOICE (Opus, needs Nam confirm): UI banner shows immediately when out of pose, but the
   VOICE uses set-start's DELAYED stuck-user re-tell (~10s) — fast clean re-arm SILENT, only a
   genuinely-stuck user is told (no per-hold "vào vị trí" spam). Latch must re-arm on the re-arm
   presence edge, time ~10s from there (device item). Nam can ask for a faster voice if ~10s
   feels too long after a break.
   RING OVERRIDE (Nam, 07-12 device): Opus's design routed the re-arm 3-2-1 through the LEGACY
   `_CenterOverlay` set-start gauge ("no new widget"). Nam rejected it — the count must render in
   the NEW `RestCountdownRing` (hold-pilot ring design) for visual consistency. Impl: get-into-
   position = the reused setup banner (not-posed); once posed, guidance clears + `_CenterOverlay`
   is hidden during re-arm + `RestCountdownRing` shows the 3-2-1 (remaining=3s×(1−activationProgress)).
4. **Re-arm voice-silent ruling SUPERSEDED by #3.** The earlier "re-arm is voice-silent"
   (07-12 round 2, "Inter-hold rest RULED" REFINED bullet) is REVERSED: the re-arm reuses
   set-start's setup_position which speaks its "get into position" line when the user isn't posed.
   This is NOT "introducing a new line" — it's the existing setup voice, per #3. Still dropped:
   the side_orientation break spam is left AS-IS ("not the problem, don't fix it").
   Propagated 07-12: hold-rest-design.html's current-code banner, voice-behavior-spec.md § Hold-based,
   and the earlier "Inter-hold rest RULED" bullets all re-point to #3.
Owner: Opus design (esp. #2 CV geometry) → Codex impl; Nam reviews. Full record: state.md
device-smoke block.

## 2026-07-12 · Hustle is fleet-wide hesitation encouragement, not intensity pressure
Status: active — Tier 3 wired across every rep exercise 07-12; the six fast/quirky exercises retain
the standard policy temporarily and carry explicit follow-up TODOs.
Decision: Every rep exercise declares an effort phase and uses `common.push` for a generic
hesitation push plus `common.one_more_rep` only for a target-proven final rep. Hustle means warm
encouragement when the user's inter-rep gap stretches and they choose to continue, never "push
harder." That register makes it valid for controlled and stability work as well as grinds. The
default Ashtanga path is a verified correction to the Tier-3 draft: transient mode enters
`recognized`, not `holding`; its script selects `recognized` for transient mode and `holding` for
micro-hold mode.
Why: the shared gap-stretch arming already self-gates fast movement and only fires after a user
commits to another effort. Excluding controlled exercises would confuse encouragement with intensity
and leave tired users in those movements without the same support. Vietnamese-market register stays
warm and face-saving: `common.push` is "Cố lên nào!", not an aggressive command.
Deferred: Mountain Climber, Jumping Jack, Jump Squat, Step-Back Burpee, Russian Twist, and Ashtanga
Namaskara need a fast/quirky policy variant that thins count and all cue density and models their
non-standard rep boundaries. Tier 3 does not solve that policy design.
Alternatives considered: leave controlled/stability exercises off (rejected — encouragement does not
contradict control); use the default mixed hustle bundle (rejected — it can say "one more rep"
mid-set); skip the six quirky exercises (rejected — fast gaps self-gate today and the debt is now
explicit).

## 2026-07-12 · Device re-rulings: reminder consecutive-content ban + activation countdown counts DOWN
Status: active — decided by Nam from device experience 07-12; implemented and covered in the shared
policy-coach suite the same day (hard rule 12, § reminder, § setup countdown).
Decision:
1. **Reminder same-content consecutive-rep ban (hard rule 12).** A reminder for fault X on rep N is
   never followed by a reminder for the same X on rep N+1; a DIFFERENT fault's reminder on rep N+1 is
   explicitly fine. Implemented in the ADAPTER's candidate pick (skip the banned id, priority falls
   through to the next eligible fault or silence), not the shared policy — the policy only sees one
   candidate, so a policy-side rule could only silence, never fall through. Ban expires after one
   reminder-free rep; resets per set.
2. **Activation countdown flips to "ba, hai, một"** (was "một, hai, ba" — supersedes the direction
   detail of 07-10 "Setup-instruction voice" point 5; everything else there stands). Same offsets,
   same common count files in reverse order, perishability/intro-termination semantics unchanged; the
   existing ready line still follows activation ("ba-hai-một, ready"). Side effect: the 07-10
   voice-up/ring-down UI mismatch (Nam had kept it) dissolves — both count down now.
Why: (1) same-fault reminders on back-to-back reps read as nagging — the PT pattern is remind, watch,
switch focus; different-fault back-to-back is real coaching. (2) counting UP to activation reads as
rep counting, not a countdown; 3-2-1-go is the universal pre-start convention.
Alternatives considered: policy-level hard rule for the ban (rejected — can't fall through to a
different fault); cross-set ban carryover (rejected — a new set is a fresh coaching context);
re-recording dedicated countdown audio (unnecessary — count files reuse in reverse).

## 2026-07-12 · Voice tuning: ONE default, no per-exercise overrides
Status: active — Nam 2026-07-12.
Decision: All cue tuning lives in the single `kDefaultTuning` map (lib/voice/voice_policy.dart). No
exercise passes a `tuning:` override. The glute pilot's device-calibrated values ARE the default now;
glute's `_voiceTuning` and squat's hustle-neutralizing override are deleted (both used `VoicePolicy()`).
Two things this promoted to fleet-wide: `criticalFault` gains firstOccurrenceCertain and drops the
(now-redundant) relief valve; `reminder` becomes 0.30/+0.15/0.65 + firstOccurrenceCertain (was a weak
0.20 default that barely fired on device — 07-12 report). And it FIXED A LATENT BUG: `softFault` was
missing from the default entirely, so every fleet soft nudge Tier 2 wired was a silent no-op
('soft-no-tuning-configured') — adding it makes them speak.
Why: the whole point of the policy design is a single calibrated PT tuned once, retuned only via the
personality scalar — per-exercise maps defeat that and drift. At this decision point hustle stayed
off fleet-wide via absent effortPhaseKeys (the real gate); fleet enablement is superseded by the
07-12 Tier-3 decision above. Glute behaviour is unchanged (default now equals its old override). Test
mechanisms that left the default (relief valve, D8 formScore scaling, roll-based escalation) now
construct explicit tunings in voice_policy_test.dart.
Alternatives considered: keep glute's override as "the pilot's own numbers" — rejected; they were always
meant to be the fleet default, and the split hid the missing-softFault bug.

## 2026-07-11 · Squat stops narrating movement phases (no phaseCues)
Status: active — Nam 2026-07-11 (device catch).
Decision: Squat's `phaseCues` ({descending→"Xuống", bottom→"Giữ", ascending→"Đứng lên"}) is
removed. Squat now behaves like the fleet: silence is the default, it speaks only counts, praise,
faults, and setup — no per-phase movement narration. The dead `'Xuống'/'Giữ'/'Đứng lên'` →
`squat/*.wav` entries in `commonFiles` are removed and the 3 wavs archived.
Why: Tier-1 migration retained squat's legacy phase narration; on device it read as the old coach
talking through every rep ("going down / going up"). Movement narration contradicts principle 1
(silence is default) and no other exercise does it. `phaseCues` stays in `VoiceScript` as unused
infrastructure (only Surya, voice-null, ever referenced it) — do NOT re-add it to squat.
Alternatives considered: keep phase cues as a squat-only nicety — rejected; it's the exact legacy
behaviour the redesign removed everywhere else.

## 2026-07-12 · Inter-hold rest RULED: per-hold re-activation ritual + HYBRID modality
Status: active — Nam's rulings via the hold-rest-design.html lavish review (7 notes + freeform,
07-12 late). The PROPOSAL's V2/V3/U3 recommendations were RE-SHAPED by Nam; V1/U1/U2 land as
proposed. Nam's freeform mandate: "everything I said is what I want… there is some overlap, not
really clean — make it cleaner" → Opus design v2 (cleanup) owns reconciling the overlaps.
Decision:
- **V1 — rest start is silent**, screen-only; the amber rest ring appearing is the signal.
- **V2 RE-SHAPED — re-entry is a full re-activation ritual, every hold:** when the rest timer
  completes (timed edge, restElapsed >= REST_DURATION — honest, it's a real timer) fire a
  rest-end tone; then a setup-register instruction line ("rest done, get into the pose"); then,
  once the pose is confirmed, the SAME "ba, hai, một" activation countdown as exercise start;
  the next hold's clock starts only when the countdown lands. The hold timer must never run
  while the user isn't actually in the exercise (Nam's why).
- **V3 folded into V2:** the rest-end tone + instruction IS the dead-system nudge; no separate
  `common.hold_reengage` one-shot. (User who still never re-poses = stuck-user re-tell
  territory; design v2 resolves.)
- **No predictive spoken rest countdown** (confirmed): the rest-end tone marks time-done.
- **U1 EXPANDED — three modalities: time-based, rep-based, HYBRID.** Former hold-based homework
  exercises become HYBRID: the time/hold rings AND the rep-tracking UI both render ("hybrid also
  needs to keep track of the reps — the same UI of checking reps needs to be there as well").
  The isTimeBased pin-true fence stands; the hybrid UI composition is design v2's job.
- **U2 — option B:** typed `liveRestSeconds` / `liveRestTargetSeconds` getters replace the
  'Nghỉ X.Xs' regex parse.
- **U3 — overrun visual:** the drained ring flips to a setup-style "Vào tư thế" instruction,
  the visual twin of the V2 audio flow.
- RESOLVED (Nam, 07-12 follow-up chat — delegated the finalize): rest-end tone = SIBLING sound
  (not end_tone.mp3 reuse; two identical bells ~5s apart would mean both "work done" and "rest
  done"). LANDED: assets/audio/common/rest_end_tone.mp3 (1.0s bell ding, CC0
  freesound.org/s/192761). ~~Instruction: rest-over cue reuses the exercise's `setup_position`
  line, fired IFF not posed; stuck-user re-tell = same line ~10s later~~ SUPERSEDED same day
  (next bullet). Ring text "Vào tư thế" stands (UI copy, not audio).
- REFINED (Nam, 07-12) then **PARTLY SUPERSEDED 07-12 device-tune #3** (voice-silence reversed):
  (a) ~~NO instruction voice at rest re-entry~~ SUPERSEDED — the re-arm now REUSES set-start's
  setup_position UI + voice (speaks "get into position" only when the user isn't posed, quiet
  when posed). See "High Plank device-tune" #3/#4. The ritual is rest_end_tone → set-start setup
  behavior (UI + its voice as needed) → pose → "ba, hai, một" → clock. STILL TRUE from this
  bullet: the final countdown + tone shape; the drop-path (form break) still skips the ritual.
  (b) NO guidance grace during re-arm: the ~3.5s set-start fallback (and intro-span grace) do
  NOT apply mid-set — the user is already in frame, just resting on the floor; guidance signals
  run ungraced there. Set-START grace behavior is unchanged. (Claude's interpretation of "remove
  the defer 3.5" = the rest re-arm only, not the set-start fallback fleet-wide — flagged to Nam.)
  Implementation clarification (Codex, 07-12, accepted): "voice-silent" means no
  instruction/coaching voice — real SAFETY guidance (orientation, body-in-frame) still speaks
  during re-arm, ungraced, per (b); the two sub-rulings compose, they don't conflict.
Why: reusing the trained activation ritual (tone → instruction → pose → ba-hai-một) makes every
hold start identical to the exercise's first activation — zero new grammar — and keeps the clock
honest. Supersedes the hold-voice impl spec's verified reuse note ("none re-fire per hold"): the
activation countdown now re-arms per hold BY DESIGN.

## 2026-07-12 · Hold voice round 2: SPOKEN final countdown (pips dropped), end tone kept + goes fleet-wide, inter-hold rest surfacing OPEN
Status: active — Nam's rulings, hold-design lavish review round 2 (4 notes, 07-12). Supersedes the
"Final countdown is NON-VERBAL" bullet of the 07-11 hold entry below (and §04 of
hold-exercise-voice-design.html — doc needs a v3 sync); everything else there stands.
Decision:
- **Final countdown is SPOKEN — "năm, bốn, ba, hai, một"** on the hold's last 5 earned seconds
  (reuses `count_5..count_1`). The final-3 earcon pips are DROPPED for v1 ("not really that
  important right now — we can still say it with the voice"). This reverses 07-11's
  "spoken countdown robot-counts" rejection; the escape hatch flagged there made it a
  content-level swap, which is what happened.
- **End tone STAYS** (one distinct "time!" sound as earned time hits the per-hold target) — and
  EXTENDS to rep-based exercises (confirmed by Nam in chat, 07-12): the tone REPLACES the spoken
  `common.set_complete` line, fired as the set's final rep lands (with that rep's numeral, same
  once-per-set latch). Hold sets inherit for free: the last hold's per-hold tone IS the set
  marker; no spoken set-complete anywhere. Channel-consistent: "set done" is state, and sounds
  carry state. RULED (07-12 chat, follow-up): the exercise's LAST set additionally speaks
  `common.exercise_complete` (already recorded) on top of the tone — the coach's goodbye; a
  bell-only workout ending reads cold. All other sets: tone only. The recorded
  `common.set_complete` asset goes unwired (flag, don't delete); its missing-audio.md
  listen-check is moot. End-tone asset: assets/audio/common/end_tone.mp3 (Nam-picked, CC0
  freesound.org/s/157277).
- **Milestones stay short spoken words** ("còn 10 giây", halfway) while the UI clock counts down
  independently — the voice/UI mismatch is accepted; voice never per-second-counts outside the
  final countdown.
- **OPEN — inter-hold rest surfacing:** the breather between holds needs (a) a voice treatment
  (announce/close the rest) and (b) a UI ring/timer for the rest period — currently missing
  entirely (Nam: "missing the rings showing time for break between two reps"). Un-designed;
  needs a design pass before the impl spec closes.
Why: device/lavish read — Nam wants the last seconds audible in words, not an abstract beep
grammar; the end tone still earns its place as the unmistakable "done" marker and generalizes
cleanly to rep-based sets.

## 2026-07-12 · Holds count holds as REPS (plank model) — supersedes "a set = one continuous hold"
Status: active — Nam's ruling, 07-12 chat ("rep count needs to act exactly like plank"). Refines
the 07-11 hold entry below: its sets-normalization bullet is SUPERSEDED, everything else stands.
Decision: Isometric holds adopt Forearm Plank's existing model — a SET contains N holds counted as
REPS (each completed hold → repCount+1 + a per-hold RepLog; brief in-exercise breather between
holds, plank.dart REST_DURATION-style), per-hold duration from the catalog, formal multi-set flow
on top. High Plank migrates `HighPlank(maxSeconds)` → maxHolds × holdSeconds; each completed hold
speaks its NUMBER via the rep fleet's count-registration rule (deterministic "Một!"); milestones +
final-3 beeps live INSIDE each hold, relative to per-hold seconds; hold-episode fault bookkeeping
now coincides with the rep; the reminder commit edge = the next hold's re-entry into holding.
Why: Plank/Cobra/Warrior already work this way (Plank(maxRep), Cobra(maxRep), WarriorOne(maxHolds))
— High Plank was the odd one out, and "one long hold" loses the rest-and-go-again structure real
plank programming uses. Counting each hold as a rep reuses the entire rep voice machinery (count
registration, RepLogs, reminder edges) instead of inventing hold-only variants.
Data corollary: the v1 catalog SQL (applied 07-12) wrongly nulled base_reps on plank/cobra/
warrior_one — misread their hold count as a mis-encoding — which flips them into _resolveVolume's
hold path and hits the _withReps reps!=null assert at launch. Corrective v2 in
docs/scratch/hold-catalog-hybrid-fix.sql restores them (APPLIED + read back 07-12: base_reps
3/3/2 confirmed); high_plank/bear_plank stay seconds-shaped
until the code migration lands, then flip plank-shaped. OPEN (impl spec): how a plank-model row
carries BOTH hold count and per-hold seconds without flipping _resolveVolume's
seconds-means-hold modality inference.

## 2026-07-11 · Hold-based voice behavior LOCKED (glute pilot's time-based counterpart)
Status: active, ONE bullet superseded — "sets normalized (a set = one continuous hold)" is replaced
by the 07-12 plank-model entry above; all other rulings stand. Nam's rulings via the
hold-design lavish review + same-day chat. Design doc:
docs/reference/voice-coach/hold-exercise-voice-design.html (v2 DECIDED); impl spec for Codex:
docs/scratch/hold-voice-impl-spec.md; behavior: voice-behavior-spec.md § Hold-based exercises.
Decision, the shape (High Plank = pilot):
- **Clock is pose-validity gated, NOT form-gated.** Two rings: outer = anti-cheat/"still in the
  pose" gates time accrual; inner = form-quality metrics coach real-time while the clock RUNS.
  Only cheating stops earning. Per-metric fault-seconds accounting stays (summary honesty).
  REVERSES the shipped High Plank perfect-timer semantics (timer paused on any form drop).
- **Voice milestones, relative rule any duration:** halfway + "còn 10 giây", deterministic,
  earned-time crossings. NO spoken per-second countdown — a coach says "10 seconds left", never
  "10, 9, 8". Voice speaks REMAINING; the UI ring stays as-is (coach = person, screen = tool).
- ~~**Final countdown is NON-VERBAL:** 3 identical beeps on the last 3 earned seconds + a distinct
  end tone~~ SUPERSEDED 07-12 (round-2 entry above): countdown is SPOKEN "năm…một", pips dropped,
  end tone kept. Still true from this bullet: no continuous tick in v1.
- **Milestone outcome slot SWITCHES praise/hustle by measured state:** clean since last milestone
  → praise roll; struggling/final stretch → hustle roll; ~~neither wins → time line alone~~
  SUPERSEDED 07-12 device-tune (always fires praise-or-hustle, never silent — see "High Plank
  device-tune" entry). Never
  praise two consecutive milestones. Hustle's second flavor: final-third pose-break arms, re-hold
  commit fires (quiet-side roll).
- **criticalFault/softFault real-time during the hold, rep-fleet rules unchanged**; persistence +
  same-fault-once bookkeeping unit = the hold EPISODE, not the (nonexistent) rep.
- **90s TIMEOUT DELETED.** Walk-away = presence gate; stuck = setup_position re-tell; give-up =
  quit. No third ending, no "hết giờ" line.
- ~~**Sets normalized fleet-wide (hybrid):** a set = one continuous hold to target duration~~
  SUPERSEDED 07-12 (plank-model entry above): a set = N holds counted as reps, plank.dart style.
  Still true from this bullet: the repCount-carries-SECONDS leak gets cleaned in migration —
  repCount now carries completed HOLDS, a real count.
Why: users come to be coached on faults — freezing the clock on every fault is a referee, not a
coach (Nam); milestones are a hold's only structural moments, so outcome cues anchor there; the
beep grammar is already trained into every phone user; timeout was an arbitrary third ending.
Alternatives rejected: form-gated earned time (v1 proposal — punitive), spoken "năm-bốn-ba-hai-một"
final countdown (robot-counts — REVERSED 07-12 round 2: Nam ruled spoken after device/lavish read),
praise-only milestone pairing (praises bad holds), keeping timeout
at 15-20min (dead mechanism once the clock runs through faults).
Out of scope, deferred: yoga/stretch register (VoiceScript config: reduced milestones, no hustle);
audio wordings (structure ships first, missing keys are safe no-ops — Nam records later).

## 2026-07-11 · Voice-copy skill: external-target cue style with no-assumption fence; bạn confirmed; praise stays generic
Status: active — Nam picked the options after the 07-11 wording research run (voice-research-rules.md §3d).
Decision: All new voice lines are written per the `voice-copy` skill (.agents/skills/voice-copy/SKILL.md).
Four calls locked there:
1. **Cue style = external target (verb + direction + concrete target), with a NO-ASSUMPTION FENCE:**
   only universally-present targets (sàn, trần nhà, màn hình/điện thoại, own-body geometry). Wall, chair,
   mirror, furniture forbidden — even as metaphor ("như ngồi ghế" out). Anatomical cue is the sanctioned
   fallback when no safe target exists; never force a weird image.
2. **`bạn` stays** despite the research flag that it can read as youth/ad register vs age-matched anh/chị
   (§3d pronoun flag). Why: pre-recorded audio would ~double per line, runtime doesn't reliably know
   age/gender, and `bạn` fits the training-partner register the hustle research favors. Revisit only on a
   move to dynamic TTS.
3. **Praise stays generic** (common rotating pool). Specific process-praise is better per the research but
   a shared recording can't name specifics; post-set (interpreter) carries all measured specificity.
   **DEFERRED, first noted here: per-metric specific praise files** (phase-2-style, alongside the existing
   variant-pools deferral, NOT scheduled).
4. **Mandatory grounding before writing metric strings:** read the exercise class + the metric file first
   (what it measures, what clears it), then write — a line naming an unmeasured action is a data-honesty
   violation (Nam's explicit note).
Why: fleet is scaling past hand-written strings; a skill makes any model write them correctly. External
focus is the strongest replicated finding in cueing science; the fence keeps it from producing nonsense
audio in unknown rooms (Nam's flag — user's room contents are unknowable).
Alternatives considered: analogy/image style (rejected as default — highest assumption risk); anh/chị
address (rejected for v1 — fleet size + unknown demographics); per-exercise specific praise now (rejected
— recording cost, post-set already carries specifics); template-free formula-only copywriting (rejected —
deterministic channels keep locked 07-10 templates).
Consequence: pending un-recorded lines in missing-audio.md should be checked against the formula before
recording (cheap now, nothing recorded for those yet); Nam confirms wordings at recording time as before.

## 2026-07-11 · Fleet soft/critical severity kept as-coded; ONE flip (walking_lunge torso → critical)
Status: active — Nam delegated "change only what's super off" on the Tier-1 fleet decision table.
Decision: The per-fault `affectsForm` values across the 24-exercise rep fleet stand as coded, with one
correction: `walking_lunge` `torso` flips soft→critical (torso_verticality_metric.dart). Its soft line
is NOT recorded; the existing critical `walking_lunge/torso.mp3` covers it. Soft-cue wordings for the
fleet live in missing-audio.md ("Fleet Tier-1 SOFT cues"), pattern-derived, Nam confirms at recording.
Why: trunk-lean is critical in every sibling (squat/lunge/jump squat/bird dog/mountain climber/
plank-family), and the walking-lunge detector only fires past MAX_FORWARD_LEAN — the error band — so
soft was miscoded, not a calibration choice. Side-effect (accepted): the fault now fails the rep in
scoring/logs, matching stationary Lunge. Left as-coded despite variance, both directions defensible:
rom criticality (critical on sit-up/mountain-climber/leg-raises, soft on v-up) and tempo criticality
(exercise-dependent — fast eccentric on spinal flexion is a real risk, jumping-jack pace is style).
Alternatives considered: flipping cossack_squat `torso` too — rejected, deep lateral squat geometry
legitimately needs forward lean, soft is a calibration choice there, not an error.

## 2026-07-11 · Rep voice fleet Tier 1 uses one policy adapter and the existing fault contract
Status: active — implementation landed in the working tree; Nam review pending.
Decision: Put all 24 in-scope rep exercises on an explicit rep-based `PolicyVoiceCoach` bundle with
`targetReps`, normalized snake_case fault ids, and the three-field RepLog contract
(`fault_types`, `fault_affects_form`, `fault_priorities`). Expose current metric faults through
`liveFaults` for 23 exercises. Tricep Dip deliberately omits `liveFaults`: its four metric objects are
declared but never updated, collected, or reset by the exercise, so surfacing them would pretend that
detection exists when it does not. Retire the superseded Bird Dog, Jumping Jack, Wall Push Up, Leg
Raise, and Squat voice stacks after verifying that production has no remaining call sites. Tier 1 does
not add soft pools, reminders, hustle phase keys, per-exercise tuning, or new audio.
Why: the fleet already had the shared policy path, but PascalCase detector types did not match the
legacy snake_case script ids, so the adapter filtered fault voice out. Three rep exercises also exposed
a hold target and therefore inherited the wrong time-based voice bundle. Normalizing at the fault
source makes one id describe detection, RepLog data, reporting, and the existing asset convention;
explicit rep bundles remove the accidental hold/rep ambiguity. Preserving each `affectsForm` value
keeps Tier 1 data-honest and leaves critical/soft product calls for the fleet decision table.
Alternatives considered: aliasing every mismatch only at RepLog write time — rejected because UI,
reports, and voice would keep different identities; changing the shared voice engine — rejected because
the engine contract already works; wiring Tricep Dip's dormant metrics — deferred because that is a
detection/pipeline change, outside a voice rollout; inventing mappings for Bird Dog `MissingBody`/
`Plank` or Russian Twist `arm_swinging` — rejected because no matching legacy meaning or recording was
verified.

## 2026-07-11 · Praise relief valve DROPPED (never built, hunger saturates first)
Status: active — Nam 2026-07-11.
Decision: The praise "5+ clean unpraised → next ≥90%" relief valve is dropped from the spec, not to be
built. It never existed in any code path (no `reliefAfter` on praise tuning; `_praise` has no relief
branch).
Why: Hunger already does the valve's job. At base 0.50 + 0.10/rep the praise probability hits its 0.85
cap by ~rep 4-5 of an unpraised clean streak, so the valve would only nudge 0.85 → ≥0.90 —
near-invisible on a real set. Consistent with the 07-08 "lean into praise / fewer hard rules"
direction. Surfaced during the 07-11 full-code-review lavish walkthrough.
Alternatives considered: build the ≥0.90 floor for spec completeness — rejected; buys almost nothing
at base 0.50 and adds a hard rule for no felt gain.

## 2026-07-11 · Glute bridge feel-tune: hustle backoff + non-neck metric tightening
Status: active — Nam's 2026-07-11 device feel call. Refines the 07-09 hustle decision and the 07-11
glute bridge threshold tune. Neck/head metric thresholds stay untouched because Nam flagged that metric
as sensitive after the prior loosening.
Decision: Keep hustle hesitation-armed and stochastic, but add a post-fire negative-hunger backoff of 2
instead of a fixed rep cooldown. Tighten only non-neck glute metrics: hip extension 152/140 with
hyperextension deviation 0.045, knee angle good 85-135 with upper acceptable to 145 and hard lower 55,
and speed-control ratio/velocity to 1.3x plus 0.08/0.15.
Why: device feel said hustle could talk on repeated hesitations, but a deterministic "cool down for 2-3
reps" violates the anti-metronome rule that makes Vika sound less robotic. Negative hunger makes the
next eligible pushes unlikely and lets silence recover the chance naturally. The form metrics were
under-calling easy reps, so the threshold move should create more honest soft coaching without touching
the known-sensitive neck/head detector or changing the rep state machine.
Alternatives considered: fixed rep cooldown after hustle — rejected as learnable cadence; retuning
neck/head too — rejected per Nam's hard fence; rep-count/state-machine tightening — rejected because the
complaint named metrics, and changing count registration would be the wrong trust surface.

---

## 2026-07-11 · Count = REGISTRATION: every landed rep is counted (supersedes count-thinning)
Status: active — Nam's ruling 2026-07-11 after device runs. SUPERSEDES the stochastic count-thinning
design (07-07) and the 07-08 pilot retune (base 0.50/+0.10/cap 1.0), and RETIRES hard rule 4's
non-verbal tick (decided-never-built; no skipped counts exist to tick for).
Decision: `CueType.count` speaks on EVERY landed rep, deterministically and personality-immune
(fleet default base 1.0 short-circuits the roll; the roll machinery survives only for an explicit
re-thinned config). Rep-1/final-2 anchors and the relief valve remain in code as guards if anyone
re-thins.
Why: on device the count turned out to be REGISTRATION feedback, not pacing chatter — users don't
watch the screen (new tech, lying down), so the spoken number is their only proof a rep landed; a
silent rep is ambiguous between "counted but coach chose silence" and "didn't register", which is a
trust leak in exactly the population Vika targets. This re-classifies the count under principle 3
(deterministic is reserved for causality/structure — a rep landing IS the causal event) rather than
principle 2 (no metronomes — which governs OPTIONAL cues; the 07-08 metronome complaint was about the
relief valve's learnable alternating rhythm, not counting itself; a PT counting every rep is just a
rep counter). The coach's non-robotic personality lives in the stochastic outcome layer on top
(praise/faults/hustle), which is unchanged.
Alternatives considered: guarantee-one-cue coalescing (count only when no outcome cue fired that rep)
— rejected: an outcome line doesn't carry the NUMBER, so the user still loses their place, and it
buys marginal quiet for real ordering complexity; the non-verbal tick — rejected/retired: a tick
must be learned, a number is self-evident, and the asset was never built.

---

## 2026-07-11 · Phone-orientation guidance gets VOICE (device-driven)
Status: active — Nam's ruling 2026-07-11 after the first full-setup device run (he hit silent rotate
signage mid-setup). Supersedes the voiceless default for `phoneLandscape`/`phonePortrait` in the
setup-safety class map (they were UI-only; the 07-10 grace entries treated phone setup as pre-position
signage). `searching` and `holdStill` KEEP their explicit silent rulings (intro covers get-in-frame;
the countdown owns the hold) — Nam's "everything the setup UI shows" read as the rotate gap he hit,
not a blanket reversal.
Decision: `phoneLandscape`/`phonePortrait` join the deterministic latch channel as standard
entry-fire classes (~1s debounce, 10s re-cue, re-fire on re-entry, ungraced) speaking new COMMON keys
`common.rotate_landscape` / `common.rotate_portrait`. MP3 files are present in tree 07-11 (listen-check
if needed); the legacy ngang/thẳng intro files were rejected as the source (old voice, intro-length
content).
Known feel-check: wrong orientation at set start queues the rotate line right behind the intro (FIFO)
rather than cutting it — flagged for device, not gated.
Why: the orientation gate blocks the whole pipeline and the user may already be propped-and-stepped-
back; a silent block is the dead-system failure this channel exists to kill.
Alternatives considered: reusing `common/ngang_intro.mp3` (rejected — legacy voice + intro-register
content); speaking the rotate line INSTEAD of the intro at set start (rejected — the intro is an
unconditional one-shot by ruling; revisit only if device feel demands it).

---

## 2026-07-10 · Resume requires the start-position hold again
Status: active — landed in tree, not device-smoked.
Decision: Any active-set resume, manual or auto, routes the exercise back through `ExerciseState.
notActivated` while preserving completed reps, logger data, and set progress. The user must regain the
exercise's normal start position and hold through the same voiced "một, hai, ba" countdown before reps
count again. This is a resume re-hold, not a new set: the per-set setup intro does NOT replay, but the
countdown and `common.ready` re-arm. The generic `common.resume` edge is effectively reserved for
non-reactivation resume edges; active-set resume uses the start-position flow. The glute-bridge pilot
resets only transient in-progress rep phase/fault state on this edge, so an interrupted half-rep is
dropped without clearing completed reps.
Why: after a pause/walkout, counting immediately can accept a bad return frame or resume from a stale
mid-rep state. Reusing `notActivated` is the smallest honest path because it already owns the start-pose
check, setup signage, scale-factor hard-write, activation countdown, and ready edge. Calling the normal
`onExerciseActivated()` path would wipe many exercises' counters/loggers, so resume has its own
reactivation hook.
Alternatives considered: (a) speak `common.resume` and continue immediately — rejected, too easy to
count from a bad/stale posture; (b) add a second resume-countdown state — rejected, duplicates the
activation gate and risks drift; (c) treat resume as a full new set — rejected, replays the intro and
can clear progress.

---

## 2026-07-10 · Setup-voice follow-ups: grace goes VOICE-ONLY and = intro duration; countdown terminates the intro; ring caption removed
Status: active — Nam's rulings latest 2026-07-10 (chat, reviewing the landed setup-instruction cluster).
SUPERSEDES two same-day rulings in part: (a) the "Setup-safety firing simplified" entry's point 3
UI-PARITY requirement — grace no longer gates the UI at all; (b) the settle-window tail — grace ends at
intro-audio-end, not intro-end + 3.5s.
Decision:
1. **Grace suppresses VOICE only. The UI always shows safety signage, live.** During the intro (and any
   grace) the guidance table renders whatever the current signal is; only the voice stays quiet. Why: a
   user still SETTING UP is standing and looking at the screen — signage is useful from frame one; it was
   the VOICE firing over the intro that was the double-speak problem. The UI is a live table (re-derived
   every frame, never queued); the single-slot/FIFO semantics are voice-channel-only.
   `guidanceSignalForPresentation` (landed hours earlier, now dead) is REMOVED, not flagged — it never
   shipped in a commit.
2. **Voice grace window = the intro voice's actual duration.** The pinning implementation stays (window
   pinned to now each frame while intro audio plays) but the tail goes: at intro-audio-end the window
   CLOSES (no +3.5s settle; the ~1s enter debounce is the only residual delay before a persisting
   graced-class condition speaks). Fallback when the intro produces no audio: the old fixed 3500ms from
   set start stays (no spoken first-telling happened, so the settle window still earns its keep). The
   activation-edge re-anchor (3.5s voice-quiet for graced classes right after activation) is RETAINED —
   pre-dates today's rulings, not re-opened.
3. **The activation countdown TERMINATES a still-playing intro.** A user already holding the start
   position has no use for setup instructions; when the first count fires while intro audio is still
   playing, the sink is stopped (current + queued lines dropped), the count speaks immediately, and
   intro-audio-end is marked at that moment (so the voice grace closes with it). "Let people get the
   voice that makes sense" (Nam). The intro never resumes — it is one-shot and was consumed.
4. **holdStill ring caption 'Giữ yên' is REMOVED from the UI** — the countdown number sits centered in
   the activation ring ('Bắt đầu' at ready keeps its slot). The number stays remaining-seconds while the
   voice counts up; Nam saw the mismatch and kept it (mid-hold the user can't see the screen anyway).
Alternatives considered: keeping UI parity with voice grace (rejected — the parity cure was worse than
the renderer-drift disease once the intro voice landed; the drift concern was about COPY sources, which
stays one table); letting queued counts play after the intro instead of terminating (rejected — stale
counts lag the hold and read broken); gating the countdown on intro completion (rejected — the countdown
must stay deterministic, causality beats politeness here).

---

## 2026-07-10 · Setup-instruction voice: per-set one-shot intro, stuck-user re-tell, holdStill voiceless
Status: active — ruled with Nam late 2026-07-10 (chat). Completes the instruction-cluster design the 07-09
defer pointed at (missing-audio.md "wiring deferred to a next-thread pass"). Wiring is a Codex follow-up
spec (docs/scratch/setup-intro-voice-impl-spec.md), sequenced AFTER the 3-delta setup-safety spec lands.
Decision:
1. **Setup intro = one-shot BROADCAST, not a monitored latch.** `<slug>.setup_position` +
   `<slug>.active_intro` (the legacy pair) fire back-to-back exactly once at set start, unconditional —
   the intro does not wait for the user to be in frame; it IS the thing that tells them to get in frame
   (same logic that ruled `searching` voiceless). Never latches, re-fires, or re-cues.
2. **Fires EVERY set.** Per-session dedupe on set 2+ (intro once per exercise, ready per set) is a noted
   future refinement for the multi-set flow, explicitly NOT designed now (Nam: good idea, that kind of
   thing will be different later — don't perfect it yet).
3. **The anti-chatter is the grace re-anchor going live:** wiring the intro re-anchors the shared
   per-class grace window from set start to INTRO-AUDIO-END (the commented seam). Sequence the user
   hears: intro → silence while complying → safety line only if still broken past the settle window →
   countdown → set. The intro counts as the first telling; the first latch fire is the escalation.
4. **Stuck-user backstop:** `GuidanceClass.setupPosition` maps to voice (was null). Entry-fire
   SUPPRESSED; ONE delayed re-tell of `<slug>.setup_position` iff the class stays continuously latched
   ~10s past intro-audio-end (feel-tune), then quiet for real; debounced exit re-arms as usual. Shape
   borrowed from no-count and the safety re-cue: tell → one help → silence.
5. **`holdStill` stays LINELESS — and the activation countdown IS VOICED (follow-up ruling, same chat):**
   [direction SUPERSEDED 07-12 by "Device re-rulings": counts DOWN "ba, hai, một"; rest of this point stands]
   "một, hai, ba" synced to the 3s activation hold, REUSING the existing `common/count_1..3.mp3` rep-count
   assets (no new recording; listen-check that the rep-count intonation reads as a countdown). Counts
   align so "ba" lands at/near the activation moment (exact offsets feel-tune). A hold break stops the
   count and DROPS any pending count lines (perishable); a re-hold restarts from "một" — causal feedback,
   not a nag. Deterministic (structure), never routed through rep-count thinning. No "giữ yên"
   instruction line ever (`common/hold_still.mp3` exists on disk, stays unwired by design): the countdown
   occupies that state's audio.
6. `common.ready` (activation edge) and the set-complete line stay hard-rule-2 deterministic, once per
   their moment, per set.
Execution note: Nam explicitly ordered direct implementation by an Opus subagent (07-10, overriding the
default Codex lane for this change), stacking onto the uncommitted setup-safety diff — his call, one
review pass covers both.
Why: the setup instruction narrates STRUCTURE (like countdown and finish line); it does not react to
state the way the safety latch channel does. Running it through the latch machinery would stack lines
during setup and drown everything — Nam's exact worry ("it's gonna be a lot and they won't ever hear
anything"). The stuck-user case is the one hole a pure one-shot leaves: in frame + right orientation +
not in pose means the safety channel has nothing to say → permanently-silent dead system, the failure
this whole channel exists to kill. One deterministic delayed re-tell fills it at minimal chatter cost.
Alternatives considered: routing setup through the safety latch (rejected: chatter + double-speak with
the intro); fully silent on the stuck user (rejected — though weaker than the usual can't-read-the-screen
argument, since a user not yet lying down CAN read the setup card; dead-system failure mode still wins);
step-by-step detected sub-instructions (rejected: no sub-step detection exists, would machine-gun);
once-per-exercise-session intro (deferred, revisit with the multi-set flow).

---

## 2026-07-10 · Setup-safety firing simplified: re-fire interval + post-audio gap DELETED; grace goes per-class at the signal layer (UI parity)
Status: active EXCEPT point 3's UI-parity + settle-tail portions — superseded same day by "Setup-voice
follow-ups" above (grace is now VOICE-ONLY and = intro duration; the UI renders signage ungated). Nam's
rulings late 2026-07-10 (chat, after reviewing the implemented behavior). Partially
supersedes the same-day lavish-review addendum below: its per-class MIN RE-FIRE point ONLY — the addendum's
grace anchor, producer-emitted resume, UI copy table, and searching-silent all stand.
Decision:
1. The per-class ~10s minimum re-fire interval is REMOVED. Re-firing is governed only by
   continuous-presence latch semantics: fire on debounced entry; silent while held; ONE re-cue iff the SAME
   flag stays continuously latched ~10s (clock dies on exit); debounced exit + re-entry = fresh fire, never
   blocked by wall-clock time since the last utterance. Anti-ping-pong (instant back-and-forth flicker) is
   the EXIT DEBOUNCE's job (~1s; THE designated feel-tune knob if device tests show fiddle-spam) — never a
   wall-clock block.
2. The ~1s post-audio safety gap is DELETED outright. (An interim "make it per-content-key" proposal from
   the same conversation is superseded by full deletion, same day.) Once per-content it could never bind:
   same-key refire is already floored by exit+enter debounce (~2s > 1s) and the re-cue fires at ~10s;
   different keys must stay responsive (Nam). Chaining is structurally impossible anyway: single latest-wins
   pending slot (max two back-to-back lines, each re-validated true at speak time) + sink serialization.
   The setup-safety channel now has NO time cooldowns at all — debounces, the continuous-presence re-cue,
   and sink serialization only; the outcome channel's collision gap is again the system's ONLY time cooldown.
3. The activation grace (~3.5s, feel-tune) becomes PER-CLASS and moves to the SIGNAL layer, shared by BOTH
   renderers. Graced (fixable in-position, trivially true while settling): body_in_frame (incl. the
   lighting fold), turnSide, faceCamera. UNgraced (must be known BEFORE getting into position, else the
   user has to get back up — or informational/edge): phoneLandscape, phonePortrait, searching, paused,
   resume. One clock + one graced-class set at the signal layer, consulted by both renderers; during grace
   the UI suppresses graced-class signage too (today it shows from frame one while voice waits — renderer
   drift, the disease the typed backend exists to kill). searching/get-ready states still render, so the
   screen never looks dead. The intro-audio-end re-anchor seam is unchanged.
Why: (1) a genuine switch-away-and-come-back — fix orientation, regress 5s later — MUST fire again; every
line in a slow alternation is true and actionable when spoken; the floor's failure mode (coach deaf to a
real regression for up to 10s = feels dead) is worse than the noise it prevents, and the noise is
self-limiting (nobody fiddles with a phone for a minute straight). (2) Fewer moving parts to review; limits
must be saturation guards that never bind, and this one could never bind. (3) The settle window is right
only where settling IS the fix; blocking "rotate your phone" for 3.5s makes the user get back up.
Alternatives considered: keep the 10s floor (rejected: deaf-to-regression); shrink it to ~3-4s (rejected
for v1: the exit debounce already covers it; revisit only on device evidence); per-content-key gap
(superseded same day by full deletion — scoped correctly, it protected nothing). Fallback if the two-line
butt-joint feels rushed on device: a small breath at the pump, feel-tune — never a cooldown map.

---

## 2026-07-10 · Voice copy conventions: persona (Vika/bạn), soft + reminder patterns, orientation→common, metric audio per-exercise
Status: active — finalized with Nam 2026-07-10 (chat), after the setup-safety entries below. Wordings
live in docs/reference/voice-coach/missing-audio.md (one-fact-one-place); behavior in voice-behavior-spec.md.
Decision:
- PERSONA DEFAULT for ALL voice lines: the coach self-refers as **Vika** and addresses the user as **bạn**
  (softer tone). Two fixed copy patterns: soft fault `Tốt, bạn [action] chút nữa là đẹp.`; reminder
  `Lần này bạn nhớ [action] nhé.` Nam's verbatim string wins over the mechanical pattern where he wrote one
  (e.g. hip_extension_soft "Tốt đấy, nâng hông cao hơn chút nữa là đẹp." drops the pattern's "bạn").
- ORIENTATION becomes a COMMON key: `common.side_orientation` (assets/audio/common/side_orientation.mp3),
  SUPERSEDING the per-exercise `<slug>.orientation` plan in the "moves to VOICE" entry below. Rationale:
  only ~3 orientation modes exist total, so a few shared recordings beat one-per-exercise (N files). Only
  the SIDE mode gets a key now ("Bạn quay nghiêng người với màn hình nhé."); other modes onboard their keys
  with the first exercise that needs them. CONSEQUENCE: as a `common.*` key it must be hand-registered in
  `GenericExerciseVoiceAssets.commonFiles` (resolveAsset returns null for unregistered `common.*`); the code
  currently resolves orientation via `script.faultKey('orientation')` (per-exercise, policy_voice_coach.dart)
  and must repoint to `common.side_orientation` — a pending code delta.
- AUDIO ROUTING RULE (the principle behind the above): COMMON (`common.*`) = structural/channel lines
  (counts, praise, setup, setup/tracking-safety, orientation — about the camera/session, identical
  everywhere); PER-EXERCISE (`<slug>.<id>`) = movement lines (faults, softs, reminders — about this
  exercise's mechanics). Metric/fault audio STAYS per-exercise even where a metric is reused across
  exercises: a shared fault pool is a file-management dependency graph waiting to cause weird issues;
  per-exercise keeps lines specific (data honesty) and the onboarding workflow simple (onboard exercise →
  record its metric set).
- REMINDER length constraint relaxed: the reminder slot is the system's tightest window (~1–1.5s at the
  rep-start commit edge). The persona pattern runs longer than the old ≤7-word cap (hyperextension_reminder
  is now 10 words — the longest line in the tightest slot), so the constraint relaxes from a word count to
  "keep ~1.5s spoken, record brisk."
- VARIANT POOLS deferred (phase-2-style, NOT scheduled): multiple recordings per content key so
  deterministic-channel repeats (reminders, safety, soft) aren't verbatim; praise already rotates. Noted,
  not on any checklist.
Why: warmer VN tone (Vika/bạn softens correction); one shared orientation recording per mode instead of N
near-identical files; per-exercise fault audio avoids a cross-exercise file dependency graph and keeps data
honesty. Wordings finalized: missing-audio.md carries the final vs pattern-derived table.
Alternatives considered: per-exercise orientation (rejected — N near-identical recordings for ~3 modes); a
shared cross-exercise metric-fault pool (rejected — file-management dependency graph, dilutes line
specificity); enforcing ≤7 words on reminders (rejected — the persona pattern needs the room; brisk
recording covers the timing).

---

## 2026-07-10 · Setup-safety voice lavish review: per-class re-fire interval added; grace/resume/UI-copy locked
Status: partially superseded — the per-class MINIMUM RE-FIRE point below was removed later the same day
(see "Setup-safety firing simplified" above); every other resolution stands. Nam's lavish review of
setup-safety-voice-design.html (7 notes), resolved same day.
Addendum to the base entry below; the design HTML is rev 2 with resolutions folded in place.
Decision:
- NEW mechanism: a per-class MINIMUM RE-FIRE INTERVAL (~10s, feel-tune) joins the latch machine. Why the
  two-edge debounce alone is not enough: it stops flicker WITHIN a class but not cross-class ping-pong — a
  user fiddling with the phone can alternate orientation-wrong ↔ body-out-of-frame every ~2s, each pass
  clearing its ~1s debounce and re-arming while the other class is latched, producing alternating
  instructions every ~3s forever. The re-fire window floors the gap between any two fires of one class,
  across clear/re-entry cycles. Sized as a saturation guard, not a scheduler (principle 2's corollary): a
  genuine comply-then-regress cycle takes >10s, so it never binds in normal use; pathological fiddling
  degrades to ~one line per ~10s. Distinct knob from the ~10s mid-set re-cue (which fires while
  CONTINUOUSLY latched). Enforced at the pump/drain gate so the latest-wins slot + re-validation still
  guarantee a late line only speaks if the condition still holds.
- Implementation reuses the house debouncer utilities (StickyDebouncer/Debouncer, lib/utils/) for the
  enter/exit edges — no new timer code.
- `paused` confirmed timer-free: the gate's person-lost grace is its ENTIRE timing (no enter-debounce, no
  re-fire window, no cooldown).
- Grace anchor DECIDED: fixed window from activation/set-start for the pilot (the policy coach doesn't
  emit the setup intro yet); commented re-anchor seam to intro-audio-end for when setup voice wires.
- `resume` LOCKED producer-emitted (one-frame GuidanceSignal from the gate's resume edge) — one-family
  consistency; the adapter-edge alternative rejected (splits guidance semantics across layers).
- UI copy source of truth LOCKED: default VN title/body per class lives in the ONE UI table; the signal
  carries only optional per-exercise overrides; producer stays copy-free; voice never reads title/body.
- searching-silent + missing-asset-safe-no-op confirmed as designed. Nam downloads the 4 audio files
  himself pre-device-test; missing-audio.md carries the exact key → filename table (the three `common.*`
  keys additionally need `commonFiles` map entries — resolveAsset returns null for unregistered common
  keys).
Why: review notes in the lavish session 07-10. All timings remain feel-tune, none canonical. Spec final:
docs/scratch/setup-safety-voice-codex-spec.md. Next: Codex implements; Nam fetches audio + runs the
design's §07 device stress-tests.

---

## 2026-07-10 · Setup/tracking-safety guidance moves to VOICE, on a typed GuidanceSignal backend (one producer → two renderers)
Status: active — decided with Nam + Fable 2026-07-10. Review addendum: see the lavish-review entry above
(same day) — re-fire interval added, grace/resume/UI-copy locked.
Supersedes (in part): the "Safety — reframed 2026-07-09" section of
docs/reference/voice-coach/voice-behavior-spec.md, on the ONE point that landmark/tracking safety
"surfaces on-screen text, not voice." That point is reversed here. The rest of the 07-09 reframe stands
(critical FORM faults firing real-time ARE the injury cue; there is still no separate injury voice line).
Decision:
- Setup / tracking-safety guidance GETS VOICE. The producers are the person-gate blocks
  (searching/paused), `checkSafety` (orientation + landmark/lighting), and the no-pose branch. Every one
  of these EARLY-RETURNS the pipeline — `ExerciseBase.processPose` returns on a gate block and on
  `checkSafety != null`; `processNoPoseFrame` on a missing skeleton — so NO reps count while they hold,
  and a mid-exercise user physically cannot read the screen (glute bridge = lying on the floor). Without
  voice the system goes silently dead. This is the least optional cue in the app.
- ONE typed signal, TWO renderers. Producers stop emitting free Vietnamese `feedback['System']` strings
  and emit a typed `GuidanceSignal` (a condition class + optional per-exercise copy). Both surfaces derive
  from it. UI = one table (glyph + title + body), replacing the substring sniffers
  `_guidanceForSystemMessage` + `_translateSystemMessage` in active_exercise_page.dart (~2478-2624), which
  today classify by `contains('quay nghiêng')` / `contains('wrong_orientation_landscape')`. Voice = class →
  content key through the deterministic firing policy below. `checkSafety`'s return type changes
  `String?` → the typed signal across all ~20 exercise subclasses (mechanical but wide; Nam approved this
  pipeline-architecture change explicitly).
- The check STAYS granular; only the MESSAGE generalizes. `checkSafety` keeps its per-exercise,
  per-landmark logic (glute-bridge side view permanently occludes the far arm — a literal full-body gate
  would block forever; a loosened gate would score reps off unseen landmarks and break data honesty). The
  asymmetry is deliberate: the message over-asks ("be fully in frame" = a simple, always-safe compliance
  action), the check under-asks (only the landmarks this exercise measures). Do not weaken the gate.
- Voice content keys are COARSE (the anti-spam decision): `orientation` (per-exercise line — SUPERSEDED
  07-10: now the COMMON key `common.side_orientation`, see the "Voice copy conventions" entry above),
  `body_in_frame` (ALL landmark-missing variants collapse to ONE generic line — NEVER name body parts;
  per-landmark latching would machine-gun as confidence cycles knee→hip→knee), `paused` (pause-commit),
  `resume` (one-shot on gate resume), `searching` = NO voice (the setup intro already says get in frame).
- Firing policy is DETERMINISTIC (principle 3 — deterministic is reserved for causality and structure),
  not a probability draw: latch per content-class (coarse on purpose); fire once on entry; silent while the
  condition persists; re-arm only after the exit debounce clears; re-fire on genuine re-entry (user
  complied then regressed). Two-edge ~1s debounce each way (frame-flicker guard, house precedent
  StickyDebouncer 5-frame / gate 650ms). Single pending slot, latest-wins, re-validated at speak time —
  drop silently if the condition cleared while audio was busy (the drop is correct; the user complied).
  ~1s post-audio saturation gap (SUPERSEDED 07-10 — DELETED, see the "Setup-safety firing simplified"
  entry above; the sink already serializes, so no time cooldown is needed). Arm-after-intro grace during
  setup (the intro is the first telling; the first latch fire is the escalation). ONE fuller re-cue if still latched after ~10s, then real silence
  (borrowed from the no-count "cue → one help → quiet" shape; the failure it prevents is a user who never
  heard it → permanently silent dead system). `paused` fires on the pause COMMIT edge, not the first lost
  frame (mirrors the UI, which renders no banner during the person-lost grace). ALL timings are FEEL-TUNE,
  none enters canonical-numbers.
Why: these states block the pipeline and the screen is unreadable mid-rep, so a text-only cue is a silent
death. The honest backend is a typed signal — the string channel is already a de-facto enum with none of
the safety (active_exercise_page matches the machine token `wrong_orientation_landscape` INSIDE the display
copy), and two independent substring sniffers is exactly the fragility a typed source removes.
Alternatives considered: keep landmark/tracking safety on-screen only (rejected — silent dead system for a
floor-bound user); genericize the gate to match the generic message (rejected — breaks data honesty, blocks
occluded-limb exercises); probabilistic firing (rejected — safety/structure is deterministic, principle 3);
per-landmark voice lines (rejected — machine-guns as landmark confidence cycles; latch on the class instead).
Seam already stubbed: `CueType.safety` exists (`CueMode.always`) and policy_voice_coach.dart:128-131 carries
a `TODO(wiring)` waiting for exactly this typed hook. Design:
docs/reference/voice-coach/setup-safety-voice-design.html. Codex spec:
docs/scratch/setup-safety-voice-codex-spec.md. Implementation PENDING (spec ready, no code yet).

---

## 2026-07-09 · Next-rep instruction lavish review: UI instruction layer deleted (voice-only), neck_head flipped critical, Q2-Q4 locked
Status: active — Nam's lavish review of next-rep-instruction-design.html (rev 2 folds resolutions in
place). Resolves every open item of the base "Next-rep instruction layer" entry (moved to sit below
this one) except the neck_head reminder wording.
Decision:
- The on-screen instruction layer DIES: delete `ExerciseBase.instructions` + `addInstruction()` +
  all metric call sites (~13 files across six exercises) + the UI consumer(s). Rationale (Nam): a
  user mid-exercise cannot look at the screen, so on-screen instructions are worthless where they
  matter; the instruction concept lives ONLY in the voice coach — the next-rep reminder layer IS
  the replacement. The broader "delayed UI display" idea is a separate later task. Metrics' VN
  instruction strings are preserved as comments (voice-wording references) before deletion.
- `neck_head` flips to `affectsForm: true` (critical). Accepted consequences: fires real-time as a
  deterministic-first criticalFault (existing 4.4s neck_head.mp3 — long, consider re-record);
  head-lifted reps no longer count clean (praise gating + form score shift); `neck_head_soft`
  recording ON HOLD (soft path unreachable). Pilot reminder faults: 2.
- Q2 streak-first reminder deterministic (100%): YES. Q3 cue-type name `CueType.reminder`: YES.
  Q4 hyperextension line: "Lần này siết bụng, lưng sát sàn nhé" (option A).
- neck_head reminder wording PROPOSED ("Lần này giữ đầu trên sàn nhé"), pending Nam — blocks only
  the recording, not implementation (stage A ships with empty pools).
Why: review notes in the lavish session 07-09; design doc §02/§07 carry the evidence and the flip's
consequences. Codex spec (docs/scratch/next-rep-instruction-codex-spec.md) APPROVED FOR
IMPLEMENTATION same day — coordinate the shared commit edge with hustle stage A.
Addendum (same day, chat): SEQUENCING — the UI removal runs FIRST as its own Codex task
(docs/scratch/ui-instructions-removal-codex-spec.md), before the reminder wiring (task 2). Discovery
(Nam asked for a real audit, not his guess): the instructions map is dual-purpose — metric-fault
"remember next time" texts (invisible in v9, nothing reads them → delete) vs the 'Status' phase
channel (LIVE hold/rest UI protocol: rest-ring 'Nghỉ X s' parse, hold/release cue verbs → migrate to
a dedicated phase-status surface, then the map dies). `resultIssues.feedback` untouched: 'System' is
the safety UI channel, and non-System metric entries feed the legacy fleet voice coach
(_GenericExerciseVoiceCoach) — invisible in v9 UI but load-bearing for fleet voice. Legacy main.dart
instruction reads sit in the orphaned exercise screen ('/exercise' routes to
ExerciseExperienceScreen) — its reads go with the map; full orphan cleanup stays phase-2.
neck_head reminder wording APPROVED ("Lần này giữ đầu trên sàn nhé") — both reminder lines recordable.

---

## 2026-07-09 · Next-rep instruction layer: scope = real-time-cued critical faults; peak faults excluded
Status: active — all Open items resolved by the lavish-review entry above; kept for the scope +
firing-moment rationale. The "mirroring the UI addInstruction pattern" framing below is superseded in
part: the UI layer is now deleted, voice-only (entry above). (Entry moved here from the file bottom
07-09 — this ledger appends at top.)
Decision: The parked post-rep/next-rep reminder becomes a voice "instruction" layer mirroring the UI
`addInstruction` pattern (ExerciseBase.instructions, phase-keyed): a CONTINUOUS critical fault that was
cued real-time during rep N earns a short feedforward reminder around the start of rep N+1 ("lần này
hạ sâu hơn chút nhé"). Peak-measured faults (glute: hip_extension, knee_angle, speed_control) are
EXCLUDED: their rep-end firing is already framed as next-rep guidance — it IS the instruction; a second
line would duplicate. (Supersedes the spec's earlier sentence routing peak faults INTO the parked
post-rep-instructions feature; they stay at rep-end.) Confirm-after-fix praise ("Đó, đúng rồi!" when a
reminded fault comes back clean) DEFERRED — research-backed but not worth complicating the praise
system now; when it lands, prefer a praise-pool variant selection (resolver picks the confirm register
when the prior rep carried a reminder) over any new cue type.
Why: mimics the observed PT chain — correct mid-rep, remind at the next attempt, then watch. Research:
voice-research-rules.md §3b (two independent capped runs converging on cue-before-the-phase-it-fixes +
feedforward phrasing + brevity). Anti-duplication keeps one measured fault = one instruction surface.
Decided same day (Nam): firing moment = the rep-start COMMIT EDGE — the state-machine transition out
of rest into the rep's first movement phase, per exercise (glute: bottom→ascending + the
descending→ascending fast-path; a squat would be standing→descending). On glute this coincides with
hustle's fire moment (effort-phase entry = the raise, per the 07-09 hustle lavish-review entry);
when both arm at one moment, the reminder outranks hustle. Exercises whose effort phase is not the
first movement (squat: effort = ascent, rep-start = descent) separate the two moments — the reminder
stays on rep-start. Why: rep-end already hosts count + outcome and the fast-path makes rep-end and
rep-start coincide on continuous tempo — the commit edge is the empty slot and lands the cue
adjacent to the action (cue-before-the-phase-it-fixes, research §3b). Design: model rep-start and
effort-phase entry as two declared moments that share plumbing where they coincide.
Open (all RESOLVED 07-09 by the lavish-review entry above): cadence numbers; cue-type name; line pool
recordings.

---

## 2026-07-09 · Hustle lavish-review refinements: effort-phase firing, void-on-absence, final-rep paired push
Status: active — Nam's lavish review of hustle-design.html, resolved with Fable 07-09. Refines the
"hesitation-armed, commit-fired" entry below (fire-moment clause + two additions); everything else
there stands.
Decision:
- Fire moment generalizes: the armed cue fires at entry into the exercise's DECLARED EFFORT PHASE
  (`VoiceScript.effortPhaseKeys`, renamed from the draft's `risePhaseKeys`) — the first one after the
  armed gap — not literally "rep start". Glute bridge: the raise (behavior identical to the draft).
  Squat when it migrates: the ascent — a squat rep STARTS with the descent, but the push belongs on
  the force moment (Nam; matches the cue-just-before-effort coaching craft). Review Q4 decided with
  it: the declaration lives on VoiceScript (zero ExerciseBase surface, squat's neutralization stays a
  default no-op, phaseCues is precedent for phase semantics in the content layer).
- Void-on-absence: presence-loss or pause during an inter-rep gap VOIDS that gap — it cannot arm
  hustle and is excluded from the baseline median. We cannot distinguish an urgent out-of-frame
  errand from a walk-away rest, and both invalidate the "hesitating in position" read; voiding is
  wrong in neither case. Extends the draft's pause guard.
- Final-rep paired push (second hustle flavor; resolves review Q1): when the count anchor fires with
  exactly one rep remaining (rep N-1 lands), the push MAY pair in the same breath ("Chín — cố lên!" /
  "Một cái nữa thôi!" — truthful, target-proven). STOCHASTIC quiet-side roll, rotating final pool,
  never deterministic — a guaranteed finish line every set is the 07-08 metronome again. A fired
  pairing consumes the push for that transition (no second fire at the final rep's effort-phase entry).
- Review Q2: inflated-baseline failure mode accepted for v1 + instrumented (Stage-B data decides a
  clamp). Review Q3: strict perishability — an armed push drops if the sink is busy at the fire moment.
Why: the draft's "rep start" was a glute-bridge coincidence (its rep starts with its effort phase);
Nam caught that the push should track force, not rep topology. The paired final push restores the
finish-energy feel Nam wants without re-opening the rejected 07-08 shape: it rides an anchor count
that fires anyway, is last-rep-only content, stays a roll, and the mid-set hesitation mechanism
exists independently.
Next: Opus folds these into hustle-design.html + docs/scratch/hustle-codex-spec.md; then Codex
implements stage A (wired OFF + gap debug-logging).

---

## 2026-07-09 · Voice coach: hustle = hesitation-armed, commit-fired (replaces the final-rep push)
Status: active — decided with Nam 07-09 (chat); fire-moment clause refined + two rules added by the
07-09 lavish-review entry above. ENABLED in the glute pilot 07-11 (was "OFF until calibration"): Nam
called it on after Stage-B device data (armed on real 6s+ gaps vs a ~4s baseline). Tuning base 0.50/
step 0.20/cap 0.90, pools common.push + common.one_more_rep (MP3 files present in tree 07-11;
listen-check if needed);
fast-path baseline pollution fixed (sub-kMinArmGapMs gaps excluded — the ~0ms descending→ascending
gaps the device log exposed). Placeholder arming numbers (kStretchRatio 1.5, kMinArmGapMs 800) held,
device-tunable. Details: voice-behavior-spec.md § Hustle. Supersedes the 07-08 candidate mechanism
(grind = rep duration >> set average) and the 07-07 "hustle ≤1/set" hard cap.
Decision: hustle fires on effort decisions, not rep positions:
- ARM on hesitation: the inter-rep gap stretching past this set's own baseline (median of the set's
  first 2-3 gaps) arms hustle. Nothing is ever spoken mid-gap.
- FIRE on commit: the armed cue rolls at the instant the next rep starts (rest -> raise transition),
  so the push lands on the effort the user just chose. If the next rep never starts, hustle never
  fires — structurally impossible to hustle someone who already finished or quit.
- Probability: persistence-shaped, no hard per-set cap. First hesitation of a set = low odds;
  accumulating hesitations climb (same shape as criticalFault persistence); firing resets. A genuinely
  grinding finish can earn 2+ pushes. Base starts quiet-side; personality scalar applies as usual.
- Rep-duration slowdown is NOT a trigger for bodyweight (weight 0 in the glute pilot); shelved as a
  loaded-movement corroborator for when squat migrates.
- Line honesty: "Một cái nữa thôi!" only when targetReps proves it's the final rep; otherwise generic
  "Cố lên!". Slot rules unchanged (lowest outcome priority, never the second in-rep slot).
- Numbers (gap-stretch threshold, base, persistence step) are deliberately NOT set here: calibrate
  from real ExerciseLogger rep timestamps before enabling; no canonical-numbers row until calibrated.
  Pilot: glute bridge (the gap signal needs no load, so the original pilot stands).
Why: research (voice-research-rules.md §3): encouragement's effect is in-the-moment and dies the
instant the voice stops — per-rep beats once-per-set, so the rejected finish-line one-shot was also
the least effective placement. Bodyweight reality (Nam): without load there is little mid-rep grind;
the struggle is the "do I go again" decision, visible as the stretched gap. Literature: spontaneous
inter-rep pause is unstudied (not refuted); the documented near-failure slowdown is concentric/
barbell-only — so the gap is read as a BEHAVIORAL hesitation signal, not a fatigue meter, and our own
logged timestamps are the calibration authority. Firing on commit instead of mid-gap (Nam's call)
avoids surveillance/nagging framing (VN face-saving: don't call out the slack, join the effort) and
structurally kills the worst false positive (encouraging someone who already ended the set). Known
cost, accepted: a user who hesitates and never starts another rep gets no push — we lose the coach's
"talk them into one more" moment in exchange for never nagging.
Alternatives considered: (a) any final-reps-window softening — rejected, still a rep-counter robot and
fires on easy sets (07-08 rationale); (b) rep-duration grind trigger — barbell-derived, unvalidated
for bodyweight; (c) mid-gap firing — nagging framing + needs a fragile "grinding vs done" ceiling
threshold; (d) hard 1/set cap — contradicts the in-the-moment evidence; the post-fire persistence
reset already spaces fires.
Next: Opus lavish design + Codex spec; zero/migrate squat's stale live hustle gate (generic 0.50
tuning + wired targetReps, inconsistent with the 07-08 lock) in the same change; hustle audio still
unrecorded (missing-audio.md).

---

## 2026-07-09 · Voice coach: outcome exclusivity is per-MOMENT, not per-rep (critical second slot + collision gap)
Status: active — decided with Nam 07-09 (chat), implemented for the glute pilot. Refines the 07-08
glute-bridge lock's "max one outcome cue per rep" clause (spec hard rule 7 / principle 4).
Decision: "max one outcome cue per rep" becomes "max one outcome cue per MOMENT":
- A second outcome cue may voice within the same rep only if ALL of: it is a `criticalFault` (safety class —
  softFault/praise/hustle stay strictly one-per-rep); it is a DIFFERENT fault than anything already voiced
  this rep (same fault never re-voices in-rep — cross-rep persistence escalation owns repeats); the collision
  gap has passed; and fewer than 2 outcome cues have voiced this rep (saturation cap).
- Collision gap: an outcome cue may not start until the previous outcome cue's audio ENDED + ~0.5s silence
  (cooldown = line length + buffer, so long lines can't chain). Applies to outcome-after-outcome adjacency
  across rep boundaries too. Numbers (0.5s, cap 2) tune-on-device; shape locked.
- Blocked ≠ spent: a critical suppressed by gap/cap keeps its first-occurrence credit (next occurrence still
  fires deterministically — hard rule 5 bends for a moment, never silently breaks) and still counts in the
  post-set summary. v1 drops the blocked line (perishable), no delayed replay.
- Scope: this is the system's ONLY time cooldown. No global cooldown — count+outcome pairing is designed
  co-occurrence (principle 4), setup/set-complete are exactly-once hard rules, praise/soft/hustle are already
  spaced by rep cadence, and QueuedAssetVoicePlayer already serializes all audio.
Why: hard rule 7 was written in the post-rep era when every outcome cue fired at the same instant (the rep
boundary), so "one per rep" really meant "one per moment". Real-time firing (07-09) made the rep the wrong
time quantum: knees-cue on the raise + neck-cue on the lower of one glute-bridge rep is normal coaching (a
real PT coaches the up and the down), not nagging. Nagging = the same fault repeated, or lines chained without
air — each gets its own guard (in-rep fault dedup; audio-end+buffer gap). Cap 2 is sized at the degenerate
edge — ~1.5s lines + 0.5s gap in a 3–5s rep physically fits at most 2 — so it almost never binds (saturation
guards, not schedulers).
Alternatives considered: (a) keep strict one-per-rep — rejected, drops a legitimate second fault for an
artifact of the old post-rep batching; (b) system-wide cooldown — rejected, breaks count+outcome pairing,
threatens exactly-once setup cues, and duplicates rep-cadence spacing (a limit that binds every set is a
metronome); (c) gap measured from cue TRIGGER time — rejected, long lines would still chain (measure from
audio end).
Implementation seam: `_lastOutcomeRep` in lib/voice/voice_policy.dart became a last-outcome-audio-end
timestamp + per-rep voiced-outcome count. `VoiceCoach` stamps the policy when the sink reports idle after
an accepted outcome cue; this is exact for the current serialized outcome flow and conservative if a later
non-outcome line ever queues behind it.

---

## 2026-07-09 · Voice coach: cue-type rename for clarity (criticalFault / softFault / setup)
Status: active — applied this session (contained scope); analyze + 33 voice tests green.
Decision: Rename CueType members for legibility: `correct`->`criticalFault`, `soft`->`softFault`,
`instruction`->`setup` (+ the matching VoicePolicy methods, tuning maps, glute/squat scripts, voice tests).
NOT renamed: `resultIssues.instructions` (the mid-rep UI / live-fault signal) — deferred, fleet-wide blast radius.
Why: Nam kept conflating the types during the glute-bridge review — "correct" read as "the clean/correct cue",
and "instruction" was ambiguous between setup copy and the live-fault channel. Names now state intent:
criticalFault = a fault with `affectsForm==true` (this IS the "safety fires immediately" cue; there is no
separate injury cue), softFault = a non-critical measured fault, setup = deterministic setup/ready/complete copy.
Alternatives considered: full rename incl. `resultIssues.instructions`->`liveReminders` — rejected for now
(fleet-wide, out of glute-bridge scope; do it in a later dedicated pass).

---

## 2026-07-09 · Voice coach: critical/soft fire real-time off a generic liveFaults surface (glute-bridge)
Status: active — design locked with Nam 07-09 via lavish `docs/reference/voice-coach/realtime-cue-design.html`;
implemented for the glute pilot. Supersedes the post-rep-batched critical/soft timing (07-07 spec) for
glute bridge.
Decision: criticalFault + softFault fire the instant a fault is KNOWN, not batched at rep-completion.
- Signal: a new read-only `List<FaultRecord> get liveFaults` on `ExerciseBase` (default `const []`; GluteBridge
  overrides to expose its metrics' current faults). Read `FaultRecord` (id + `affectsForm`) directly — NOT the
  coarse `resultIssues.instructions` UI-string map (no affectsForm, ad-hoc PascalCase keys) — so critical-vs-soft
  stays correct. [Nam Q3: the one additive base getter is acceptable — the same "zero new ExerciseBase surface"
  relaxation already taken for the target fields in the entry below.]
- Adapter: each frame, drain NEW liveFaults -> criticalFault (affectsForm, always / first-occurrence-certain) or
  softFault (hunger+base, real-time [Nam Q1=A]); dedup per rep so a fault never speaks twice. Count + praise stay
  post-rep (rep number and "clean == no fault all rep" are only knowable then). Faults detected during the
  bottom/setup phase (e.g. neck-lift) ARE spoken [Nam Q2=yes].
- Timing split: continuous faults (hyperextension, neck-lift) surface mid-rep -> real-time; peak faults
  (insufficient hip-extension, knee severity, speed) are only knowable at rep-end and the metrics clear their
  `faults` before the coach frame runs, so they fire via RepLog at rep-completion.
- Peak faults: a peak fault can't be acted on in its own rep, so the implementation fires it at rep-end
  via RepLog as NEXT-REP guidance, not an urgent mid-rep correction. When the parked post-rep-instructions
  feature lands, route peak faults THERE and drop the rep-end firing so the same fault is never spoken twice.
Why: the only place a fault is known mid-rep is the moment its metric detects it; "fire the instant known" =
real-time for continuous faults, rep-end for peak. Honest realization of the 07-08 "correct + soft fire
real-time" decision given the true shape of the mid-rep signal.
Alternatives considered: (a) keep post-rep batching — rejected, corrections land too late to act on; (b) drive
off `resultIssues.instructions` coarsely — rejected (no affectsForm, ad-hoc keys, misses peak faults);
(c) enrich the metrics to push structured live faults — unnecessary, the getter exposes what metrics already
accumulate in their `faults` list.

---

## 2026-07-09 · ExerciseBase carries the per-set target(s); voice reads them from the base
Status: active (glute-bridge scope; extends the 07-08 glute-bridge voice lock). Relaxes the 07-07
"zero new ExerciseBase surface" guardrail for the target fields only.
Decision: ExerciseBase gains two optional fields, `targetReps` and `targetSeconds`, injected via its
constructor (`ExerciseBase({this.targetReps, this.targetSeconds})`). Both independent + nullable so
the base covers every modality: reps-only (targetReps set), hold-only (targetSeconds set), mixed
(both set, e.g. N reps each held M seconds). A subclass forwards whatever target(s) it takes via
`super(...)`. Glute bridge (pure reps) now does `super(targetReps: maxRep)` and feeds its
PolicyVoiceCoach from the base field (`targetReps: targetReps`), which activates the coach's existing
`_isFinalReps` final-rep awareness (the flag rides in every cue's CueContext, not just hustle).
Why: PolicyVoiceCoach was written to accept `targetReps` but was never fed it (its own doc comment
names the gap: "no target rep count anywhere in ExerciseBase"). Putting the target on the base lets
ANY consumer read it polymorphically instead of downcasting to the concrete exercise
(GluteBridge.maxRep). Nam's call to keep BOTH targets on the base rather than a single reps-XOR-seconds
target, because some exercises are genuinely mixed (reps each held N seconds) and need both.
No audible change yet: glute bridge's hustlePool is `[]` and hustle tuning 0.0 (both deliberate per
07-08 "hustle OFF, grind-triggered later"). This wires the signal, not a new spoken line.
Supersedes: the 07-07 stance that target rep count stays OUT of ExerciseBase (coach fed only from a
launch-screen constructor arg, to honor "zero pipeline changes"). That guardrail is intentionally
relaxed for these two fields.
Deferred: squat still feeds its coach `targetReps: maxRep` directly (not via super/base), migrate it
to the base-forwarding pattern later; hold-based exercises forward `super(targetSeconds:)` next; mixed
last (needs `_resolveVolume` + the factory to carry BOTH values — today they collapse to one via the
`isHold` bool).
Flags: landed as a hand edit by Opus, which conflicts with the Opus-designs / Codex-implements rule
(see the pending CLAUDE.md §Delegation reconciliation). Kept per Nam ("it's fine, glute bridge only").
The exercise-base lavish walkthrough (docs/reference/exercise-base/exercise-base-explained.html) is
now stale on the constructor + core-state fields and its gutter line numbers below §5a (code shifted
~16 lines); sync deferred until the hold/mixed steps land to avoid re-churning it twice.

---

## 2026-07-08 · Voice coach: glute-bridge-first behavior lock (soft cue, deterministic first fault, count/praise retune)
Status: active EXCEPT the count clause — superseded 07-11 by "Count = registration" (every landed rep
is counted deterministically; the 0.50/+0.10 thinning is retired). Locked with Nam 07-08 via the
lavish review docs/reference/voice-coach/glute-bridge-voice-review.html; refines the 07-07 entry's
ship-day defaults. Implementation: Codex, glute-bridge scope only.
Decision: Wire glute bridge end-to-end as the first on-device voice test, and lock the behavior below (glute-bridge scope only; other exercises untouched until device-confirmed).
- Rep classifier (adapter, from existing RepLog data — NO new fields): `!correctForm` (a critical / affectsForm fault) -> correction; `correctForm && fault_types` non-empty (only non-critical faults) -> NEW soft cue; `correctForm && fault_types` empty (truly clean) -> praise. Count fires independently.
- NEW cue type `soft` (minor / non-critical): a warm nudge ("Tốt, chỉ cần nâng hông cao hơn chút") — not urgent, gentler cadence (lower base, NOT first-time-deterministic), own audio. Exists so we never say "good" on a rep with a measured minor fault (data honesty) yet never scold for a non-critical one. Praise is thereby gated on TRULY clean (correctForm && no faults at all).
- Correction: first occurrence of a fault fires deterministically (faultPersistence==0 -> 100%), then escalates on persistence; one outcome cue per rep. The `correct` relief valve (reliefAfter:4) is removed (redundant once first=100%).
- Count: base 0.50 + hunger step ~0.10, cap 1.0 (rep 1 always). Hunger climbing to certainty IS the "never essentially uncounted" guard, so the discrete relief valve (reliefAfter:6) is removed. Step kept small so 100% is only reached after ~5 straight silent counts — a degenerate-edge saturation guard, not a scheduler (cap 1.0 reached after 2 skips WAS the audible bốn/sáu/tám rhythm; small step avoids it).
- Praise: keep variable-ratio (hunger + cap 0.85 + never-twice-in-a-row + one-outcome-per-rep); raise base ~0.35 -> 0.45-0.50 (lean into praise); DELETE the D8 formScore multiplier (roll*(0.6+0.4*formScore)) — it only ever half-masked the fault-id bug.
- Hustle: OFF. A once-per-set finish-line push on a rep counter is robotic, not PT behavior; effort pushes should be grind-triggered (rep duration >> set average), which isn't wired — deferred.
- Fault vocabulary: rename glute bridge's four metric `FaultRecord.type` strings to snake_case (HipExtension->hip_extension, Hyperextension->hyperextension, KneeAngle->knee_angle, SpeedControl->speed_control, NeckHead->neck_head) and align the exercise's voice faultIds to match, so replog id == audio-key stem (glute_bridge/<id>.mp3) and the (kept, shared) faultIds filter passes.
Why: the shipped policy wiring (07-07 design) had glute-bridge corrections silently dead — its RepLog fault types were PascalCase metric names, its voice faultIds snake_case, matched by a bare `contains` that the old string-sniffing coach's normalizer used to bridge; faulty reps fell through to praise (data-honesty break). Fixing at the seam surfaced Nam's stronger preferences: fewer hard rules (drop both relief valves), deterministic causal first-reaction over a 25% roll, no robotic finish-line hustle, and a third "minor" bucket so non-critical faults are neither praised, scolded, nor silently dropped. Numbers stay tune-on-device; the shapes are locked. VN-market: warm nudges over scolding; the soft cue keeps encouragement honest.
Deferred (documented): per-rep speak-only-the-top-priority-fault (needs the replog to carry priority order or a top-fault field; the priority sort already exists in glute_bridge._onRepCompleted); hustle via grind-detection; rollout to the other ~35 exercises after device confirmation.
Supersedes (from the 07-07 ship-day defaults, glute-bridge scope): count cap 0.90 + never-skip-two-counts + reliefAfter:6 -> base 0.50 / step 0.10 / cap 1.0 with no discrete valve; `correct` reliefAfter:4 removed; hustle <=1/set -> off; D8 "praise proportional to quality" -> removed; adds cue type `soft` (not in the 07-07 CueType list). First-occurrence-of-a-fault-always-cued is RESTORED (the implemented `_correct` had softened it to a 25% base roll).
Alternatives considered: (a) keep non-critical faults silent (07-07 bandwidth reading) — rejected: uninformative (never tells the user what to tweak) and still lets praise fire on minor-fault reps; (b) delete the shared faultIds filter now — deferred, out of glute-bridge scope; (c) keep both relief valves as saturation guards — rejected for the smooth hunger->cap-1.0 mechanism ("no extra rules").

---

## 2026-07-07 · Voice coach: one policy module, stochastic PT cadence, personality scalar
Status: active (behavior spec approved by Nam 07-07; implementation pending — spec at
docs/reference/voice-coach/voice-behavior-spec.md, research at voice-research-rules.md same folder)
Decision: All exercise voice goes through one policy module with a single entry point —
say(type, content, context) — plus per-exercise voice DATA only (script: intro keys, fault-id→cue
map, praise pool; evolved from scriptsByExerciseName, keyed by slug not display name). The module
owns whether/when/how a cue plays via one policy table keyed by CueType (safety, instruction,
count, noCount, praise, correction, hustle). Cadence is stochastic: optional cues fire on per-event
probability draws with hunger shaping (base chance + bonus per silent eligible rep + relief-valve
backstop), never fixed counters. Effective chance = (base + hunger) × personality — a tunable
coach-chattiness scalar (0.5–1.5, v1 ships 1.0) that also scales hunger accrual, clamps at caps,
composes with the provisional skill-fade multipliers, and never touches hard rules or relief valves
(safety always; setup/complete once; rep-1 + final-2 count anchors, never skip two counts,
non-verbal tick on skipped counts; first occurrence of a fault-id always cued; never praise
consecutive reps; one outcome cue per rep, correction > praise > hustle; hustle ≤1/set; no-count
always informs, switching to help after 2 consecutive). ExerciseBase emits the events (rep counted
with faults, state change, phase change, safety); the 8 dedicated coach classes + inline BirdDog
coach + orphaned LegRaise coach + per-exercise player wrappers + the unused ExerciseBase.ttsService
field get deleted; ViettelTTSService survives only as the TTS fallback inside content resolution
(surya's dynamic lines). Migration order: generic coach first (~35 exercises), then squat + the 6
dedicated coaches, then surya.
Why: voice logic was 11 coach classes across 4 patterns, 2 playback engines, throttle constants
scattered per coach (250/350/2500 ms), no event model (per-frame state diffing), squat
string-sniffing Vietnamese status text. Verified research (voice-research-rules.md): real coaches
default to silence (silent monitoring ~22% of behavior, their most common act), praise
intermittently (variable-ratio, ~30-50% of clean reps), correct only on bandwidth crossings, and
concentrate dense feedback post-set; every-rep feedback was the worst schedule for retention. Fixed
cooldowns are learnable rhythms = robotic (Nam 07-07: "nothing in real life is predictive as
cooldown every 3 reps"); hunger-shaped draws give an average cadence with no pattern. The
personality scalar keeps reference numbers fixed in the spec while making chattiness tunable per
persona/user later. VN-market: warm encouraging tone, corrections say what TO do, and thinned
counting keeps trust via anchors + tick (users mid-set can't see the screen; the count proves the
CV counter registered).
Alternatives considered: (a) central policy layer but keep the 11 coaches routing through it —
ships randomness fastest, keeps per-exercise setup + string-sniffing, rejected; (b) push structured
fault-ids up from metrics for mid-rep bandwidth cueing — conflicts with the post-rep-coaching
guardrail (real-time = safety only) and stays deferred, same deferral as the presence-gate entry.
Supersedes: canonical-numbers.md "Coaching & Adaptation" rows "Cooldowns: corrective 3 reps /
positive 1 rep" and "Voice priority queue: 5 layers" — aspirational values that never existed in
code; both rows now point at the behavior spec.

---

## 2026-07-06 · docs/reference/ organized into per-topic folders
Status: active (supersedes the flat "build the lavish HTML at docs/reference/<name>.html next to its
.md" convention recorded in the learning-docs-use-lavish-html memory note, 2026-07-05)
Decision: `docs/reference/` is now one folder per topic; each folder holds that topic's markdown
spec/report and its lavish HTML explainer together. Current folders: `agent-memory/`, `exercise-base/`,
`presence-gate/` (spec + presence-pipeline-explained.html), `push-up/`, `recommendation-engine/`,
`scale-factor/`, `supabase-schema/`, `ui/` (PREMIUM_IVORY_WIRING + ui-real-logic spec). A new reference
doc goes in the matching topic folder (create one if none fits); a spec and its lavish HTML share the
folder. Files moved with `git mv` (history preserved); all internal cross-references + docs/README +
the memory note updated in the same pass.
Why: the flat dir mixed markdown and HTML across unrelated topics ("dumped everything in reference").
As each spec grows a lavish explainer the pair belongs side by side; per-topic folders keep a spec and
its walkthrough in one place and make "where does this doc go" obvious.
Alternatives considered: (a) group by subsystem (exercise-pipeline / ui / data) — fewer folders but the
exercise cluster balloons and placement gets fuzzy as it grows; (b) fold only topics that already have
2+ files, leave singletons flat — least churn but leaves most docs loose, the exact problem being fixed.

---

## 2026-07-05 · PresenceGate: extract presence/pause/segmentation from ExerciseBase
Status: active (implemented; spec at docs/reference/presence-gate/presence_gate_extraction_spec.md)
Decision: Pull the presence / auto-pause / segmentation-trigger responsibility out of `ExerciseBase`
into a `PresenceGate` collaborator (`lib/exercise/presence_gate.dart`) that the base owns and calls
once per frame (`onPose`/`onNoPose` → `GateVerdict`). ~200 lines move: the `PersonDetector` +
`PresenceAnomalyDetector`, the 4 `_was*` edge-trigger flags, the confirm/grace/resume timers + their
3 duration consts, `AVG_LOW_PRESENCE_THRESHOLD`, the pause booleans, `_syncPresenceState`,
`_computeAvgPresence`, `_isPoseFrameEdgeRisk`, `_resetPresenceDetectors`, and all 7 `triggerCheck`
call sites. `ExerciseBase` keeps its public API as thin delegates (no external call site changes;
`surya_namaskar`'s manualPause/Resume overrides keep working). Clock is injected (base passes
`frameTimestamp`; `manualResume` passes `DateTime.now()`). A minimal `PosePresenceSource` interface on
`PersonDetector` (declaration only, no logic change) lets tests inject a fake without platform
channels. Pure structural refactor — ZERO behavior change.
Why: One responsibility ("is a person reliably in frame, should we pause, when to poke segmentation")
was smeared across 12 fields + 4 methods + 7 scattered trigger calls inside the per-frame pipeline,
untestable without a full ExerciseBase subclass pumping fake frames. Extraction makes the
confirm(500ms)/grace(900ms)/resume(320ms) timers unit-testable with a fake clock — the real payoff —
and lets `processPose` read as a clean linear pipeline. Pairs with the pending voice-coach redesign
(the other big non-base tenant of this file), done separately.
Decisions within: (a) detector seam = minimal interface, not a fake SegmentationChannel (clean
isolated tests over exercising real smoothing math); (b) the 3 near-pure detector-plumbing members
(`disposeDetectors`, `personPresenceScore`, `runPersonDetection`) stay as ExerciseBase delegates, not
a publicly exposed gate — the exercise is the single façade the camera holds and the completed-guard
is genuinely exercise-state; (c) Vietnamese copy stays in the base, gate returns enums only; (d) unit
tests in scope this pass.
Alternatives considered: (a) thin state-holder that only moves the fields but keeps the trigger calls
scattered in `processPose` — rejected, the scatter IS the problem, gains nothing testable; (b) expose
the gate and have the camera drive it directly — cleaner base surface but edits the fenced camera
files and leaks the collaborator for no behavioral gain; (c) fake-channel tests instead of the
interface seam — heavier, less isolated, runs real hysteresis math. Deferred: pushing structured
fault-ids up from metrics (the string-sniffing voice engine) — that's the separate voice redesign.

---

## 2026-07-05 · scaleFactor: hold-seeded, EMA-adaptive, side-aware source
Status: active (implementation pending; spec at docs/reference/scale-factor/scale_factor_calibration_spec.md)
Decision: Base `scaleFactor` stops being a live per-frame value with a `1.0` fallback and becomes a
slowly-drifting calibration signal:
- Source: shoulder→hip distance; camera-side pair when `cameraFacing` is left/right, shoulder/hip
  midpoints when front. Measurement is gated on `isLandmarkConfident` (presence≥0.7, visibility≥0.3),
  NOT mere non-null — the pose smoother keeps occluded landmarks as low-confidence entries, so a
  non-null check would silently measure a hallucinated far-side hip. Same landmarks the exercise's
  `checkSafety` gate already guarantees, so safety passing ⇒ scale computable, by construction.
- Lifecycle: two-state write. While notActivated (approach + 3s hold), scaleFactor is hard-written to
  the current confident measurement each frame (last-write-wins) — this feeds glute_bridge's start
  check a fresh value AND locks the hold measurement at activation. Once activated, it adapts by slow
  EMA (alpha=0.1) on confident frames only. Bad frames never write in either state (reuse-last-good,
  free), and the notActivated hard-write IS the EMA's seed, so no separate seeded flag. The
  `return 1.0` fallback is deleted; glute_bridge's `> 0` guards become dead-but-harmless (the
  seed-before-activation invariant replaces them). NOTE: posture_stack's `< 1.0` check reads
  prayer_pose's LOCAL scale, a different source — out of scope, untouched.
- Resume re-hold is now landed (2026-07-10 entry above) and re-seeds for free: it routes state back to
  notActivated, so the hard-track resumes during the re-hold and re-freezes into EMA on re-activation.
  No reset helper needed — it falls out of the notActivated guard.
- Anatomical basis stays shoulder→hip. Not switching to femur (hip→knee, rigid under flexion)
  because every PT-calibrated ratio threshold is denominated in torso-lengths; changing basis =
  recalibrating all form-checked exercises. Door stays open per-exercise later.
Why: scale = body proportion (fixed) × camera distance (drifts only on reposition). Measuring a
calibration constant as a live signal is the design mismatch behind the `1.0`-spike bug (single
occluded frame → scale collapses ~100-400× → phantom faults/reps in glute bridge + curl-up, the two
base-field consumers). checkSafety already gates on camera-side visibility every frame (existing,
PT-reviewed idiom) but calScaleFactor demanded all four torso landmarks — the far side is exactly
what's occluded in side-lying exercises. Side-aware source closes that gap without demanding the
occluded side of a side-lying user be visible (which could make glute bridge un-activatable).
Flags: (1) curl-up metrics currently normalize against a scale that shrinks as the trunk flexes;
under EMA they normalize against stable mean torso length — likely better, but needs a device pass
on curl-up thresholds before shipped. (2) Exercises computing local per-frame `scale`
(prayer_pose, raised_arms, seated_forward_fold) are out of scope now; this shape is their future
migration target.
Alternatives considered: (a) per-frame + reuse-last-good only — fixes spikes, keeps needless jitter
and curl-up mid-rep shrink; (b) freeze at activation — elegant but blind to mid-set repositioning
(mat scoot → silently wrong for the rest of the set); (c) gate all four torso landmarks in
checkSafety — honest but risks bricking side-lying exercises whose far side is legitimately
occluded; (d) femur basis — rejected above (threshold recalibration project).

---

## 2026-07-05 · docs/agent-memory/ is the shared cross-agent memory
Status: active
Decision: Claude Code's private auto-memory dir is symlinked to `docs/agent-memory/`, so Claude's
automatic capture/recall now lands in the repo, in git, where Codex (and any future agent) reads it via
`docs/agent-memory/MEMORY.md`. Routing rule added to CLAUDE.md § "Agent memory". Personal/sensitive
facts go in `private-*.md` (gitignored).
Why: One brain for every agent on the repo without new infrastructure. Files-in-git beats tool-private
silos and MCP memory servers on auditability (diff/review/provenance) and cost for a solo dev. Keeps
"one fact, one place": structured knowledge stays in its owning docs/ file; agent-memory holds ambient
learnings + working prefs only.
Alternatives considered: (a) docs/-only routing without sharing the auto-memory — cleaner but loses
Claude's frictionless self-capture; (b) MCP memory server (MemPalace/engram) — right for teams of
agents, overkill + un-auditable for one dev now; (c) exposing the auto-memory at its home path —
machine-specific, breaks on clone. Revisit MCP if 3+ agents enter rotation.

---

## 2026-07-06 · Auto-paused presence re-confirm uses a 1s poll, not a per-frame poke
Status: active
Decision: While auto-paused (person walked away mid-set), the segmentation detector runs at a
dedicated 1s cadence (`PAUSED_PROCESS_INTERVAL`) instead of the old behaviour where the gate fired
`triggerCheck(reason: 'paused_pose_present')` every frame (rate-limited only by the 200ms cooldown =
up to 5 samples/s). The `usePausedCadence()` capability existed on PersonDetector but was never wired;
now the auto-pause edge calls it, the auto-resume + manualResume edges restore
`useActivatedCadence()` (8s). A manual pause drops straight to the 8s baseline and never samples fast
— presence can never clear a manual pause, so there was nothing to sample for (that path was the worst
waste: 5 samples/s forever while a manually-paused user stood in frame).
Why: The presence design is "cheap slow baseline + one-shot edge triggers," and canonical-numbers
already described post-activation samples as one-shot. The two *sustained* per-frame triggers
(`paused_pose_present`, and the self-terminating `no_landmarks_stale_present`) drifted from that. 1s
keeps the full 5x cost cut vs the 200ms hammer while resuming in ~1.3s (≤1s to next poll +
`_PERSON_RESUME_CONFIRM_DURATION` 320ms) — roughly half the ~2.3s a 2s cadence would give.
Kept: every one-shot edge trigger (pose_returned, no_landmarks, pose_low_presence, pose_frame_edge,
pose_anomaly, manual_resume) — those are the good event-driven path and make auto-pause itself prompt.
`no_landmarks_stale_present` stays too: it self-terminates once a sample flips personDetected false.
Alternatives considered: (a) 2s cadence (reuse SEARCH) — 10x cheaper but ~2.3s resume, felt sluggish;
(b) keep per-frame poke for auto-pause, only fix the manual-pause waste — leaves the 5 samples/s cost
on the common auto-pause path; (c) flat 2s everywhere incl. active — breaks prompt absence detection
(personDetected caches true for a full interval; the one-shot no_landmarks trigger is what makes
auto-pause fire on time). `useSearchCadence()` remains dead code (seeking still uses SEARCH at init) —
flagged, not deleted.

---

## 2026-07-06 · PresenceGate: _computeAvgPresence stays all-joints presence (side-aware rejected)
Status: active
Decision: `_computeAvgPresence` keeps averaging `presence` over all ~33 landmarks, unweighted.
Rejected the cleanup-review suggestion (presence-pipeline-explained.html §07, worklist item 9) to
weight by visibility or average only camera-side joints. Fable confirmed against code + measured data.
Why: The suggestion's premise conflated the two confidence fields. The average uses `presence`
= P(landmark exists), which stays 0.988+ for legitimately occluded side-view joints (empirical
05-06, canonical-numbers.md); `visibility` (0.34–0.95 on the back leg) is the noisy field and never
enters the average. So side-view avgPresence sits ~0.98–0.99, far above the 0.35 pose_low_presence
threshold — no measured misfire exists. The only recorded dip into 0.10–0.35 is a real walkout
boundary (smoke-test frame 712), the exact event the poke exists to catch. Weighting by visibility
would pull framed side-view users toward the threshold (creating the misfires it claimed to fix)
and would silently re-baseline PresenceAnomalyDetector, which consumes the same average. Camera-side-
only averaging halves the joint pool and adds a cameraFacing-correctness dependency; in a walkout
the far side can leave frame first, so it can also blind the early warning. The scale-factor
side-aware idiom (2026-07-05 entry) gates *measurements* on confidence so we never measure a
hallucinated far-side landmark — that logic doesn't transfer to a presence aggregate whose job is
noticing joints leave the frame. Poke cost is one native sample on a 200ms cooldown, edge-triggered,
so even a spurious fire would be near-free.
Flag (unfixed, watch): the presence-vs-visibility distinction can silently erode in one place — when
the native channel omits `presence`, the adapter falls back to `presence := visibility`
(lib/pose/pose_landmarker_adapter.dart:34), and the Expando fallback in vika_pose_landmark.dart
duplicates `likelihood` into both fields. If native ever stops sending `presence`, the gate degrades
with zero signal. Candidate fix someday: debug assert or a canonical-numbers note pinning the channel
contract.

---

## 2026-07-06 · Pose inference throttles to ~1fps while paused (Option A: throttle, not off)
Status: active (implementation delegated 07-06: Opus → iOS native, Sonnet → Dart wiring)
Decision: While the exercise is paused (auto or manual), native pose inference drops to ~1fps via a
new pose-channel method `setDetectionInterval` (args `{'minDetectionIntervalMs': int}`, 0 = full
rate); full rate restored on resume. Camera, preview texture, and the segmentation feed are
untouched in both states. Pose is NEVER gated during active (it is the product) or seeking (v1
scope: seeking-phase gating would add up to ~2s skeleton latency at the segmentation SEARCH 2s
cadence — measure the pause-only win first).
Why: Pose landmarker at ~30fps is the dominant per-frame ML cost and is ~100% wasted during pauses
(rest between sets can run minutes). Throttling instead of stopping keeps pose events flowing, so
the gate's _syncPresence tick, auto-resume timers, and every existing invariant work unchanged — no
new tick source, no deadlock class, ~29/30 of the inference saved. Two traps make the naive hard-off
(Option B) dangerous: (1) native `captureOutput` feeds SegmentationService AFTER the
`guard detectionEnabled` (ios/Runner/PoseLandmarkerService.swift), so `stopDetection()` starves
segmentation → `personDetected` freezes stale → nothing can ever resume (deadlock); (2) with zero
pose events the Dart pipeline stops ticking the gate entirely (processPose/processNoPoseFrame are
event-driven), so auto-resume timers never advance without new timer plumbing. The throttle skip
must gate ONLY the landmarker submit — the segmentation feed stays per-frame (it self-throttles on
its own cadence, PAUSED_PROCESS_INTERVAL 1000ms).
Alternatives considered: (a) hard stopDetection/startDetection on pause edges — marginally more
saving, but needs the seg-feed move + a new pause-time tick source and adds ~0-1s resume latency;
deferred, revisit only if throttle numbers disappoint. (b) also gate pose during seeking — bigger
battery window but sluggish skeleton appearance when the user steps into frame; v2 candidate.
Flags: crosses the camera-file fence (active_exercise_page.dart + native service) — Nam approved
07-06. Existing `detectionEnabled`/`stopDetection` semantics (lifecycle/backgrounding) intentionally
untouched. On ship: add canonical-numbers row for the paused pose interval (start 1000ms, tune from
beta) + device thermal/battery pass across a 2-3min pause.
