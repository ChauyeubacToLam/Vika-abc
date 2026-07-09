# Vika State

SNAPSHOT, current status only. Rewritten IN PLACE, never appended to. Prune shipped/resolved on sight
(the "why" lives in decisions.md; git log is the fine-grained history). Numbers -> canonical-numbers.md.
Design / how-it-works -> the owning reference doc. If this file only grows, it's rotting.

## Now

**Voice coach — glute-bridge first on-device test (2026-07-08).** Behavior locked 07-08 (decisions.md
07-08; lavish review docs/reference/voice-coach/glute-bridge-voice-review.html, notes threaded in
.lavish/lavish-notes.json). Codex implements, **glute-bridge scope only**: snake_case the 4 metric
`type`s + align faultIds; 3-way rep classifier (correction / NEW `soft` cue / praise) with praise gated
on truly-clean; first fault 100% then escalate; count base 0.50 / step ~0.10 / cap 1.0 (both relief
valves removed); praise keeps hunger+cap+never-twice, base ~0.45-0.50, D8 multiplier deleted; hustle off.
- Post first device-test (07-08): praise-on-clean + hustle-off confirmed working as designed; the "dead"
  feel was missing audio, not logic.
- Audio follow-ups: (1) DONE renamed 3 correction files to the `<slug>/<faultId>.mp3` convention
  (`speed_control`/`neck_head`/`hyperextension`) so all 5 correction lines resolve; convention documented
  in `audio-naming-convention.md`. (2) record 7 lines = 5 glute soft cues + `common.great_1/2` [Anh Doan,
  list in missing-audio.md]. (3) setup/orientation/ready cues deferred to the fleet migration.
- **v1 voice checkpoint committed (07-08).** Snapshot of the working glute-bridge state for tomorrow's
  code review. Included a real bugfix: `generic_exercise_voice_assets.dart` did NOT compile — a stale
  `_faultLineAlias` helper (the abandoned alias approach, `speed_control`->`speed.mp3` etc.) had mangled
  the class braces (extra `}` orphaned every later method) AND pointed at the files we renamed away.
  Deleted it; `resolveAsset`'s default `<slug>/<id>.mp3` now resolves correctly. analyze clean, 33 voice
  tests green.
- **Re-mappings (Nam 07-08), resolve earlier confusion:** (a) behavior-spec "safety fires immediately"
  = the `correct` cue (renaming -> `criticalFault`) firing REAL-TIME; there is no separate injury cue, so
  `CueType.safety` is vestigial (only the landmark/tracking `checkSafety` is "safety" in code). (b)
  "first fault always cued" belongs to the post-rep REMINDER feature (parked), not the criticalFault cue;
  `firstOccurrenceCertain` left on criticalFault for now, revisit with the reminder.
- **Decided this session, not yet built:** (1) correct + soft fire REAL-TIME (mid-rep, off the
  `resultIssues.instructions` map — the only mid-rep fault signal), superseding rep-completion timing.
  (2) DELETE fleet-wide the 3 rejected rules still in the policy — D8 praise scaling, count relief valve,
  correct relief valve (Nam: "just delete it"); reviewed-code tomorrow, kept out of the v1 checkpoint as
  it changes 9 exercises. (3) Naming rename (Nam's OK pending): `correct`->`criticalFault`,
  `soft`->`softFault`, `instruction`->`setup`, `resultIssues.instructions`->`liveReminders` (kills the
  name collision). Codex does the rename once confirmed.
- **Parked for tomorrow's rep-based review:** final-2-reps-always-counted (real decision 07-07 +
  behavior-spec, NOT in code; blocked on plumbing the rep target from the screen into the coach — no
  target exists in ExerciseBase); non-verbal tick on skipped counts (decided, never built); `noCount`
  cue type + behavior (bundled with the post-rep reminder decision); the post-rep reminder behavior
  itself (REPLACES vs COMPLEMENTS correct/soft; reuse loose `assets/audio/*.mp3` — cham_lai,
  nang_hong_cao_hon, khong_keo_co, siet_co_bung — vs record exact lines).
- Audio still pending: record 7 lines = 5 glute soft cues + `common.great_1/2` [Anh Doan, missing-audio.md].
- Deferred (post device-confirm): per-rep speak-only-top-priority-fault; grind-triggered hustle; fleet
  rollout to the other ~35 exercises.

**PresenceGate extraction (2026-07-05): SHIPPED, device smoke pending.** `lib/exercise/presence_gate.dart`
extracted from `ExerciseBase` (~200 lines lighter), `PosePresenceSource` on `PersonDetector`, 22 gate
tests green, analyze clean. Pending: device smoke (hold-still 3s, walk-out auto-pause, walk-back
auto-resume, tap-pause stays). ScaleFactor spec (docs/reference/scale-factor/) still impl-pending.

**Pose-throttle-while-paused (2026-07-06): implemented (ADR decisions.md 07-06, Option A), review pending.**
Native `setDetectionInterval` drops pose inference to ~1fps during pause, full rate on resume; segmentation
+ camera untouched. Orientation-gate manualPause also throttles; lifecycle re-init force-resyncs the
interval. Pending: Nam line-review, device smoke + thermal/battery over a 2-3min pause, canonical-numbers
row on ship.

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
  unmeasured native CVPixelBuffer leak, device-check resume-mid-rep + rapid bg/fg.
- **Voice phrase list not finalized** (feeds the current voice work).
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
