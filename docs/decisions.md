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
Codex to implement, glute-bridge scope. Supersedes the post-rep-batched critical/soft timing (07-07 spec) for
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
- OPEN build detail (Nam 07-09): a peak fault can't be acted on in its own rep, so treat it as NEXT-REP guidance,
  not an urgent correction; and when the parked post-rep-instructions feature lands, route peak faults THERE and
  drop the rep-end firing so the same fault is never spoken twice. Resolve the delivery shape when writing the
  Codex prompt.
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
Status: active (locked with Nam 07-08 via the lavish review docs/reference/voice-coach/glute-bridge-voice-review.html; refines the 07-07 entry's ship-day defaults). Implementation: Codex, glute-bridge scope only.
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
- Resume-rehold (planned) re-seeds for free: it routes state back to notActivated, so the hard-track
  resumes during the re-hold and re-freezes into EMA on re-activation. No reset helper needed — it
  falls out of the notActivated guard.
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
