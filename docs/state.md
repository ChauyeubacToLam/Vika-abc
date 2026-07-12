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
green (analyze clean; voice + exercise suites 247 green as of 07-12). The "why" for every call lives in
decisions.md (07-07 → 07-11 voice entries); behavior in voice-behavior-spec.md; numbers in
canonical-numbers.md § Glute Bridge; audio all recorded + resolving (missing-audio.md — no gap).
Scope shipped this pilot: 3-way classifier + real-time critical/soft + per-MOMENT exclusivity;
next-rep reminder (neck_head + hyperextension, wins the commit-edge slot over the re-correction);
count = REGISTRATION (every landed rep, deterministic, personality-immune); setup/tracking-safety
VOICE channel (typed `GuidanceSignal`, one producer / two renderers) incl. phone-orientation rotate
prompts; setup-instruction cluster (per-set intro, voiced ba-hai-một activation countdown, ready,
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

**Voice fleet rollout — Tier 1 COMMITTED (07-11, c9ed034), device-checked on squat+lunge.** All 24 in-scope
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
Device catch 07-11 (fixed in c9ed034): squat still narrated movement phases ("Xuống/Giữ/Đứng lên")
via a retained `phaseCues` — removed (decisions.md "Squat stops narrating"); squat now fleet-standard.
Also 07-11: all 166 fleet lines + 9 Tier-2 reminders GENERATED via vclip (Chi Mai, 64k/24kHz), legacy +
dead Viettel audio archived off-tree to gitignored `archive_voice/` (for Drive backup). Loose orphan
`16-30.mp3` count fallbacks KEPT (still wired, but old-voice — regen in Chi Mai if a plan uses >15 reps).

**Voice fleet Tiers 2 + 3 — IMPLEMENTED, UNCOMMITTED (07-12).** All 24 rep exercises verified; 27
reachable soft ids have `softCuePools`, 20 selected continuous-critical faults have `reminderPools` +
verified `repStartPhaseKeys`, and every script now has a verified effort phase plus the strict hustle
pair (`common.push` mid-set, `common.one_more_rep` target-proven final). No soft id was dropped and no
reminder pick was rep-end-only. Tier-2 correction: Walking Lunge can enter through `stepping` or
directly through `descending`, so both rep-start keys are wired. Tier-3 correction: default/transient
Ashtanga enters `recognized`, not the draft's `holding`; the script selects by mode. Hustle's register
is encouragement-when-hesitating, not "push harder," so controlled/stability moves stay enabled.
Engine, arming constants, tuning, Glute Bridge, holds, Surya, thresholds, `affectsForm`, audio and
pubspec untouched. Code-synced matrix: `docs/reference/voice-coach/voice-fleet-tier1-review.html`.
Verification 07-12: analyze clean; exercise suite 148 green; voice suite 100 green. The 9 reminder
mp3s and Tier-2/3 wiring are still uncommitted and belong in the same fleet commit.
- **DEFERRED (Tier-3 Note 1):** Mountain Climber, Jumping Jack, Jump Squat, Step-Back Burpee, Russian
  Twist, and Ashtanga Namaskara need a dedicated fast/quirky policy variant. It must thin count cadence
  and cue density across count/critical/soft/hustle and model their non-standard rep boundaries; all
  six run the standard policy for now and carry `TODO(voice)` at `createVoiceCoach`.
- **Watch (device):** lunge `trunk` (and squat `sync`) fire every rep like glute's neck_head did —
  honest if form's off, naggy if the metric's oversensitive; a metric-threshold tune, not a voice bug.
- **Parked cleanup:** Tricep Dip dead detectors; Bird Dog rejected-attempt fault clearing; the dead
  ViettelTtsService class + its import in exercise_base.dart + constants token.
- **Device residual** (from the 07-10 UI-instruction removal): plank rest-ring/hold-cue visuals → next device smoke.

**Hold-based voice — behavior DECIDED (07-11, plank-model re-ruling 07-12), implementation NOT
started.** Full record: decisions.md 07-11 "Hold-based voice behavior LOCKED" + 07-12 "Holds count
holds as REPS"; behavior spec § Hold-based exercises; design doc hold-exercise-voice-design.html
(v2, plank-model patch in flight). Shape: a set = N holds counted as REPS (plank.dart is the
reference; High Plank migrates to maxHolds × holdSeconds, each completed hold speaks its number),
pose-gated clock (only cheating stops earning), per-hold voice milestones (halfway + "còn 10 giây",
speaks remaining, UI ring untouched), final-3 earcon beeps + end tone per hold (no spoken countdown,
no tick v1), milestone praise/hustle switch, real-time faults (hold = the rep, fleet bookkeeping maps
directly), 90s timeout deleted. High Plank pilot.
- **NEXT:** Codex implements from docs/scratch/hold-voice-impl-spec.md (plank-model revision in
  flight 07-12); audio wordings parked until structure lands (master record list in missing-audio.md;
  new lines follow the voice-copy skill). Open in spec: how a plank-model catalog row carries both
  hold count and per-hold seconds (_resolveVolume infers hold-ness from base_seconds != null);
  firstOccurrenceCertain-as-factory-default awaiting Nam sign-off.
- **URGENT (data, Nam runs):** the v1 catalog SQL (applied 07-12) BROKE plank/cobra/warrior_one
  launches — it nulled base_reps, but their classes consume a hold count as reps (_withReps asserts
  reps != null). Corrective v2 restores them → docs/scratch/hold-catalog-hybrid-fix.sql. high_plank/
  bear_plank stay seconds-shaped (3 × one-hold interim) until the code migration lands, then flip
  plank-shaped (flip SQL drafted in the same file, commented out).

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
