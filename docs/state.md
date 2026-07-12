# Vika State

SNAPSHOT, current status only. Rewritten IN PLACE, never appended to. Prune shipped/resolved on sight
(the "why" lives in decisions.md; git log is the fine-grained history). Numbers -> canonical-numbers.md.
Design / how-it-works -> the owning reference doc. If this file only grows, it's rotting.

## Now

**Voice copy-writing skill — WRITTEN (07-11), Nam text-review pending, UNCOMMITTED.**
`.agents/skills/voice-copy/SKILL.md`: grounding steps, cue formula (external target + no-assumption
fence), per-slot templates, register, data honesty. Calls locked in decisions.md 07-11 "Voice-copy
skill"; research basis voice-research-rules.md §3d. Follow-up (non-blocking): check pending
un-recorded missing-audio.md lines against the formula before recording.

**Voice coach — glute-bridge pilot: COMPLETE (07-11), device-approved, UNCOMMITTED.**
Nam device-tested the full glute bridge 07-11: "good enough, call it done." All behavior landed and
green (analyze clean; voice + exercise suites ~241 green). The "why" for every call lives in
decisions.md (07-07 → 07-11 voice entries); behavior in voice-behavior-spec.md; numbers in
canonical-numbers.md § Glute Bridge; audio all recorded + resolving (missing-audio.md — no gap).
Scope shipped this pilot: 3-way classifier + real-time critical/soft + per-MOMENT exclusivity;
next-rep reminder (neck_head + hyperextension, wins the commit-edge slot over the re-correction);
count = REGISTRATION (every landed rep, deterministic, personality-immune); setup/tracking-safety
VOICE channel (typed `GuidanceSignal`, one producer / two renderers) incl. phone-orientation rotate
prompts; setup-instruction cluster (per-set intro, voiced một-hai-ba activation countdown, ready,
set-complete, stuck-user re-tell, holdStill lineless); hustle (hesitation-armed, stochastic post-fire
backoff); resume re-hold; non-neck glute metric tightening (neck_head left sensitive per Nam's fence).
Device-log observability across all cues (`[Voice]` / `[VoiceGuard]` / `[VoiceSetup]` / `[VoiceCount]`).
- **NEXT: Nam line-reviews + commits the whole stack.** Nothing from this session is committed — the
  entire voice pilot is in the working tree (last commit predates it). This is the one blocking step to
  "done."
- **OPEN (non-blocking):** (a) hustle uses a stochastic post-fire backoff (`postFireIdlePenalty: 2`),
  NOT a hard rep cooldown — Codex's deliberate anti-metronome call, ~10% back-to-back vs 0%; Nam to
  confirm or override (decisions.md 07-11 "hustle backoff + metric tightening"). (b) watch the
  tightened non-neck metrics for over-firing on the next device run before tightening further.
  (Praise relief valve RESOLVED 07-11: dropped from spec, never to be built — decisions.md.)
- **PARKED (post-pilot):** delete the 2 remaining rejected `kDefaultTuning` rows (criticalFault
  relief-4, praise 0.35 + D8 — count row already fixed); no-count cue type + behavior; per-rep
  speak-only-top-fault; multi-set intro dedupe (intro once per exercise).

**Voice fleet rollout — Tier 1 IMPLEMENTED (07-11), review pending, UNCOMMITTED.** All 24 in-scope
rep exercises now select the rep-based policy bundle explicitly, inherit `targetReps`, write the
three-key RepLog fault contract, and use normalized snake_case detector ids. Current faults are exposed
for 23/24; Tricep Dip is the deliberate exception because its metric objects are never driven by the
exercise, so Tier 1 provides setup/count/praise there without claiming fault detection. This fixes the
Superman / Plank Up-Down / Walking Lunge time-based-bundle bug and the fleet-wide type/id filter bug.
The obsolete bespoke exercise coaches and their isolated tests are removed after zero-call-site checks.
No shared voice-engine code, detector thresholds, `affectsForm` values, hold exercises, Surya, Glute
Bridge, or audio assets changed. Decision surface + code contradictions:
`docs/reference/voice-coach/voice-fleet-tier1-review.html`; asset gaps:
`docs/reference/voice-coach/missing-audio.md`. Scoped exercise/voice tests: 248 green; analyze clean.
Full suite: 434 passed / 6 failed, all six the documented pre-existing 12px workout-summary overflow
cluster; no fleet test failed.
Tier 2 (soft pools, reminders, hustle keys) waits on Nam's table rulings. Tier-3 design calls remain
parked: Jump Squat 3-phase effort, Burpee phase semantics, Russian Twist two-half reps, Mountain
Climber per-side types.
- **Device residual** (from the 07-10 UI-instruction removal): plank rest-ring/hold-cue visuals → next device smoke.

**Hold-based voice — behavior DECIDED (07-11), implementation NOT started.** Nam ruled via the
hold-design lavish review + chat; full record: decisions.md 07-11 "Hold-based voice behavior LOCKED",
behavior spec § Hold-based exercises, design doc hold-exercise-voice-design.html (v2). Shape:
pose-gated clock (only cheating stops earning — reverses High Plank's perfect-timer), voice milestones
(halfway + "còn 10 giây", speaks remaining, UI ring untouched), final-3 earcon beeps + end tone (no
spoken countdown, no tick v1), milestone praise/hustle switch, real-time faults with hold-EPISODE
bookkeeping, 90s timeout deleted, sets hybrid (High Plank joins the multi-set flow). High Plank pilot.
- **NEXT:** Codex implements from docs/scratch/hold-voice-impl-spec.md (authoring in flight 07-11);
  audio wordings parked until structure lands (master record list in missing-audio.md; new lines follow
  the voice-copy skill).
- **NEXT (data, Nam runs):** hold catalog rows are still single-set (base_sets=1 everywhere; plank/
  cobra/warrior_one mis-encode hold count in base_reps). Normalization SQL drafted →
  docs/scratch/hold-catalog-hybrid-fix.sql (provisional set counts, preserves volume intent; stretch
  poses untouched pending PT). Must apply BEFORE the hold pilot's device test or High Plank launches
  1×20s. Code path already consumes sets×seconds correctly — data-only fix.

**PresenceGate extraction (2026-07-05): SHIPPED, device smoke pending.** `lib/exercise/presence_gate.dart`
extracted from `ExerciseBase` (~200 lines lighter), `PosePresenceSource` on `PersonDetector`, analyze
clean. DRIFT (07-09): 2 seeking-confirm gate tests (+ ~6 workout_summary widget tests) FAIL on clean
HEAD — reproduced in an isolated worktree, so NOT caused by the 07-09 voice work; possibly
timing-sensitive; triage owner needed. Pending: device smoke (hold-still 3s, walk-out auto-pause,
walk-back auto-resume, tap-pause stays). ScaleFactor spec (docs/reference/scale-factor/) still
impl-pending.

**Pose-throttle-while-paused (2026-07-06): implemented (ADR decisions.md 07-06, Option A), review pending.**
Native `setDetectionInterval` drops pose inference to ~1fps during pause, full rate on resume; segmentation
and camera untouched. Orientation gate is no longer a pause path: wrong phone orientation blocks exercise
processing with setup guidance and keeps the rotate signage visible instead of showing the pause panel.
Lifecycle re-init force-resyncs the interval. Pending: Nam line-review, device smoke + thermal/battery over
a 2-3min pause, canonical-numbers row on ship.

**Progress tab v2 + Active exercise v9 (2026-07-02): SHIPPED in repo, NOT device-tested.** Progress v2:
ĐIỂM FORM gauge = scoped-average only (direction chip removed, supersedes 06-21). Active v9: PageView
camera <-> full-screen-demo swipe, shared lifted metric layer persists across both pages. Detail ->
Progress Experience + Exercise Experience reference docs. Pending: device verify.

## Top todos
1. **TestFlight team validation** (UNBLOCKED 07-02, Xcode runs again). Rebuild + push build 4, verify
   intent flow S01->S16 + a full workout end-to-end, add Khanh/Anh/Kiet/Ha as Internal Testers, capture
   feedback.
2. **Session-summary residuals.** Coach + trophy picker WIRED + frozen (06-02). Left: `metricCriticalityOrder()`
   now dead (delete or repoint); verify issue-mode popup doesn't overflow small phones; hero score-climb
   tween fires at build not reveal; share CTAs still stubbed. Live wiring TODOs: `grep -rn "TODO(wiring)" lib/`.
3. **Onboarding logic refinement sweep.** v5 UI locked, several decision points still on v1 hardcoded
   heuristics. Cheap wiring first: painAreas -> exercise mods, intent_quote at Day-1 Closer. Full list in
   Onboarding Flow doc.
4. **Onboarding re-login fix** (DECIDED 06-05, Codex prompt handed off, impl + verify pending). Add login
   entry state; move markComplete:true to S13 onAuthenticated; stop clearing local flag on signout.
5. **Progress v2 core scoring** (device-verify pending). Nam owns: period-ranker scoring (Theil-Sen slope,
   >=3 gate), VN copy, set MIN_IMPROVEMENT_SLOPE + trajectory "high" cutoff, device-smoke pain feature.
   Ranked insights renders guided-empty until per-exercise builders land.

## Active blockers
- **No physical-Android full-session test yet** = the Android validation gate. Build + video + Firebase
  distribution work, but nobody has run a full session (camera + pose + rep-count + set-complete + mid-set
  back-guard) on a real ARM Android phone; emulator can't. Play Store also pending: switch
  `flutter build apk` -> appbundle, create a real release keystore + register its NEW SHA-1 in Google Cloud
  BEFORE first use (current builds are debug-keystore-signed; a new unregistered keystore breaks auth).
- **iOS build 4 validation** (Xcode unblocked 07-02; was a stale process, a Mac reset fixed it, NOT the
  latent Xcode-26 FLUTTER_BUILD_DIR bug which can still recur). Rebuild + push build 4, confirm FPS cap
  ships at 24 (vs no-op 30), run 10-min Allocations + thermal over a 20-min session to confirm/refute the
  unmeasured native CVPixelBuffer leak, device-check resume re-hold mid-rep + rapid bg/fg.
- **Push-up interpreter**: implemented + landscape, anti-cheat thresholds provisional; separation test +
  calibration inside the Kiet-led HW track. Numbers -> Canonical.
- **Doctor sign-off pending** (06-13): canonical 7-zone pain vocab, fork pain->yoga/home weights, S09
  region mappings all SHIPPED provisional; VN verification doc prepared. Doctor combo patterns await the
  meeting (feeds Clinical Patterns doc); verify the cross-exercise clinical layer is BUILT vs spec-only
  before launch. Not blocking. Curl-up trunk_elevation thresholds provisional 05-04, await PT video calib.
- **Codemagic CI setup**, needed before the next TestFlight push (~1-2h one-time).
- **Privacy before external 30-50 user test** (internal OK): PostHog EU pending real phc_ token +
  analyze/device smoke; Kiet to confirm bundled S06 consent PDPL-sufficient + DPIA/TIA filings, Anthropic
  integration-intent confirm. Age-16 gate + withdraw/export/delete DONE.
- **Kiet confirm Vika VN legal entity**, gates Apple Org account + D-U-N-S. Doesn't block launch.
- **v4.4 catalog calibration SQL** ready, not yet applied to DB.
- **vikavn.app landing + /support + /privacy URLs** must be live before App Store submission (Khanh).
- **Demo account reseed watch.** Seeded to mid-week 5 ~06-27 (UID 6def169a-..., plan cab43878); Tuần tab
  empties ~07-04 if review hasn't happened, so likely empty now (today 07-08) — recheck + date-shift
  re-anchor before any reviewer access.
- **Open redundancy / forward-gotchas (not yet decided):** Session RPE vs per-exercise difficulty
  (leaning cut; onSessionRpe retained as an unused hook). Completion-anchored progression: plan_completed_at
  writer + long-gap guard (provisional 14d) not built — once plan_completed_at IS written, the active-only
  snapshot fetch drops completed plans and starves BOTH retest and Plan tab; whoever wires plan-completion
  must keep them fed. OAuth: com.vikavn.app://login-callback registered across Supabase + Info.plist +
  AndroidManifest for all 3 providers; Google verified on physical iPhone (05-26); Facebook intentionally
  HIDDEN not removed, native config retained ON PURPOSE (not cleanup debt).
- **Flagged-dead code** (flag, do not delete unasked; full list -> Codebase Backlog): executive_summary_page,
  exercise_comparison_service, plan_screen_legacy, the set_data completion cluster, widget.program in
  plan_screen, difficulty_rating_block, several progress mocks.

## Phase 2 cleanup (post-launch, non-blocking)
MediaPipe version skew iOS 0.10.21 vs Android 0.20230731; simplify iOS visibility-fallback-chain to
visibility-only; delete stale MainActivity.kt orphan; drop frameBytes from Android pose emission
(~42MB/sec); SharedPreferences->Supabase migration audit; per-exercise voice asset migration off Viettel
TTS; legacy onboarding + orphan screen cleanup; drop orphaned profiles.last_workout_at; set-duration
capture deferred; rebrand remaining Supabase auth email templates to Premium Ivory; SMS auth revisit if
beta data shows email-only signup completion hurting.

## Roadmap (at a glance)
Phase 2 Build MVP (now -> July): working app on stores, 2,000 downloads. First App Store submission was
targeted 6/19, live ~mid-July. Phase 3 Launch (Jul->Aug): data-dependent. Phase 4 Monetization (Aug->Dec):
PRO paywall, payments, AI coach insights (Haiku), ML threshold personalization at 200+ sessions, library
to 30+, challenges, PT tier. (Phase 1 Contest cancelled, work carried forward.)

## Tech snapshot
Flutter/Dart, MediaPipe Pose Landmarker Lite (33 landmarks ~30fps, iOS native + Android), One Euro
Filter, StickyDebouncer, Supabase (auth + profiles + RLS, Singapore), Viettel TTS (squat + glute-bridge
migrating to pre-recorded assets), rules-based ML Phase 1. Recommendation Engine v4.4 shipped end-to-end.
Multi-exercise session flow + WorkoutSummaryScreen shipped. Privacy v2 on PDPL framework. Two UI registers
(Premium Ivory active, legacy jade-green backing exercise/auth). Architecture + gotchas -> Vika Context
doc; interpreter/exercise pipeline -> Interpreter System + Exercise Implementation Guide.

## Validation
Survey: 151 respondents, ICP office workers 25-45, WTP >=99K. Full stats -> canonical-numbers.md +
vinafit-survey-analysis.docx.

## Team
Tech: Nam (founder/CTO), Anh Doan (voice + exercise specs), 3 exercise devs. 1 tester acting as PT for
threshold review. Mac teammate runs Codemagic CI / iOS builds. Exercise build + calibrate lane: Kiet (HW
track: push-up + ~22 camera exercises) + Khanh (yoga track: Sun Salutation chain), dev-led; interpreter
logic changes route through Nam (core). Business: Kiet (business/legal lead, DPO), Ha (marketing), +3.
Ops: Khanh (PM, ASC Admin + shared Apple ID). Comp: unpaid, pay from PRO revenue ~6mo in. Equity deferred.

## Key external contacts
- Doctor advisor, clinical diagnosis + musculoskeletal research, DXA lab access. Active: squat combo
  patterns for VN desk workers -> Clinical Patterns doc.
- Prof. Scott Uhlrich (UofU, OpenCap), call 04-10: rules > ML, validate with own data, model isn't the
  moat. NOT an integration target.
- Selim Gilon (MILA, ML/CV), potential peer for validation protocol design.

## Business reminders (proactive surface)
Pricing locked 99K VND/mo + 20K/item (151-survey validated). Forcing function = first paying user by
July 2026; 2k launch downloads; PRO conversion target Sept. Apply Apple ASBP + Google Play SBP NOW (15%
not 30%). Exercise DB Google Sheet (83 exercises + 43 yoga). Still need: unit economics, GTM post-launch,
judge/investor metrics. Platform Vision (B2B doctor referral flywheel) parked until product one has paying
users. Detail -> ~/vika-ops/.

## Pointers
Decisions + rationale -> docs/decisions.md. Numbers -> docs/canonical-numbers.md. Reference docs ->
docs/reference/. Business/vision/compliance -> ~/vika-ops/. Code bugs / cleanup / ideas -> Codebase Backlog.
