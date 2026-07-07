# Vika State

SNAPSHOT, current status only. Rewritten at each checkpoint, NOT appended to. Decisions + rationale
go to decisions.md. Numbers go to canonical-numbers.md. Design / how-it-works detail goes to the
owning reference doc. This file is overdue for a hygiene pass (compressed history has grown large);
prune stale/shipped items at the next checkpoint.

## Now
**In-flight (2026-07-05):** `PresenceGate` extraction from `ExerciseBase` — SHIPPED. `lib/exercise/presence_gate.dart` (new), `exercise_base.dart` collapsed by ~200 lines, `PosePresenceSource` interface on `PersonDetector`, 22 gate unit tests green. `flutter analyze` clean; 7 pre-existing suite failures unchanged. Pending: device smoke (hold-still 3s, walk out → auto-pause, walk back → auto-resume, tap pause → stays). ScaleFactor spec (docs/reference/scale-factor/scale_factor_calibration_spec.md) still implementation-pending.

**Cleanup pass (2026-07-06):** presence-pipeline review (docs/reference/presence-gate/presence-pipeline-explained.html) actioned — worklist at docs/reference/presence-gate/presence-gate-worklist.md. Done: confirm-duration standardized to 900ms (code + tests aligned, other agent); manualPause guard removed (pause allowed pre-activation, resume always reachable via pause overlay); ANOMALY_DELTA doc drift fixed 0.20→0.15; edge-risk magic numbers promoted to `_FRAME_EDGE_*` consts; debug `personStableMs` wiring dropped; `runDetection` retyped `Object?`→`InputImage?`. New debug-only contract guard in `pose_landmarker_adapter.dart` warns once if native ever omits `presence` (the field the whole presence≠visibility distinction rests on). REJECTED: side-aware `_computeAvgPresence` (Fable-confirmed — it averages `presence` which stays 0.988+ on occluded joints, so no side-view drag; switching to visibility would create misfires + re-baseline the anomaly detector). Rationale → decisions.md 07-06. 22 gate tests green, `dart analyze` clean; not device-tested this pass.

**In-flight (2026-07-06):** Pose-throttle-while-paused (ADR in decisions.md 07-06, Option A): new native `setDetectionInterval` drops pose inference to ~1fps during pause, full rate on resume; segmentation feed and camera untouched. Implemented 07-06 (Opus → iOS native, Sonnet → Dart wiring; Fable cross-checked both halves, analyze clean + 22 gate tests green). Sonnet additions beyond spec: orientation-gate manualPause path also throttles; lifecycle re-init force-resyncs the interval (fresh native session forgets it). Pending: Nam line-review, device smoke + thermal/battery pass across a 2-3min pause, canonical-numbers row on ship.

**Last checkpoint:** July 2, 2026 (Progress tab v2 cinematic redesign + Active exercise v9 two-page
swipe redesign, both discovered SHIPPED via local codebase check, previously undocumented). Both live
in the local repo (progress_screen.dart mtime 07-01; active_exercise_page.dart mtime 07-01 23:43) but
never checkpointed. Progress v2: ĐIỂM FORM gauge scoped-average only (direction chip REMOVED,
supersedes the 06-21 decision), ĐƯỜNG TIẾN BỘ trend + BÀI TẬP NỔI BẬT insights fixed to whole-program
scope. New reference doc: Progress Experience. Active exercise v9: PageView camera <-> full-screen-demo
swipe (tap arrows + drag), shared lifted metric layer (rep hero, hold ring, hybrid hold cue, chrome)
persists across both pages, no wave gesture in code (manual swipe/tap only). In Exercise Experience doc
(new 07-02 section). NOT device-tested this pass, discovery was a codebase read. Decisions -> Decision
Log 2026-07-02.

**Prior checkpoint:** July 1, 2026 (debug panel rebuilt as a dev/PT-only debugData dump + PT-review
upgrades). Active-exercise debug overlay rebuilt from the old TrackedMetric + sparkline + dev/user
design into a dev/PT-only flat live dump of exercise.debugData: DebugMode {off,dev}, a ~150ms sampler
decoupled from pose FPS, keys grouped by dot-namespace (metricName.field; undotted -> misc), FPS the
only status-colored row. PT-review flow (one person holds the phone at the PT): host-owned fullscreen
with see-through glass (host gates the camera scrims off so the blur shows camera + skeleton), freeze,
collapsible groups, 2-column when wide, viewport-bound height. Deleted tracked_metric.dart + the
ExerciseBase tracker machinery + all sparklines + user mode. Prod debugData readers (hold-ring
bottomHoldProgress/holdProgress, pose-overlay active-joint labels) fenced + intact. Codex-implemented,
Claude-verified line-by-line on disk (flutter analyze clean); NOT device-tested. Detail -> Debug Panel
Architecture doc (rewritten); decision + supersedes -> Decision Log 07-01.

**Prior checkpoint:** June 29, 2026 (exercise-production team workflow + 3 research-stage prompts
drafted). Team-facing operational workflow on top of the Exercise Build Pipeline spine: each dev takes
one exercise end to end per week (state machine -> think + code cheat metrics -> set logger / report
builder / interpreter), proves correctness via a demo video showing good+fault per metric with the
report rendering right; Nam reviews the logging in code + spot-checks the 53-feature ML log row in
Supabase by session id. Buffer model: >=8 exercises stocked before dev starts, 2 devs x 1
exercise/week. Research stage formalized as 3 chained one-prompt-per-turn deep-research prompts (live in
Google Docs, team-owned): (1) broad source-gathering with archive-or-drop + model self-verification as
anti-fabrication guards; (2) metric extraction grounded ONLY in the attached papers, computability the
sole hard cut, camera-view recorded-not-filtered, built around the 5 named computation primitives read
from the squat code; (3) catalog tag prefill with controlled vocab LOCKED (7-zone pain, goal_fit keys,
fork/body_region enums). Two method changes: camera view chosen post-PT as a coverage tradeoff over the
validated set (no longer a research-time cut), and video_url dropped from exercise_catalog (videos
embedded in-app, ~28MB/34). Both -> Decision Log 06-29; Exercise Build Pipeline 1c + Backend & Auth
catalog section updated. Workflow + prompts stay in Google Docs, not duplicated. Next: dry-run prompts
1->3 on one real exercise before the team uses them.

**Prior checkpoint:** June 27, 2026 (App Store ASO metadata finalized from live VN-storefront testing).
Subtitle + keyword field re-optimized, SUPERSEDE the 06-01 picks: NAME `Vika: HLV AI Tại Nhà`
(unchanged; HLV/AI proven ZERO organic search value, kept only as the conversion hook), SUBTITLE
`Yoga, gym, giảm cân, pilates` (replaces `Sửa tư thế: Yoga & Workout`), KEYWORD FIELD
`nữ,nam,mỡ,bụng,tập,bài,mông,plank,cardio,giãn,cơ,HIIT,thể,dục,workout,hình,múi,ngày,online,luyện`
(96/100). Method: Apple search-hints + iTunes Search API (VN storefront), no paid tools. KEY FINDING:
the pose-correction moat (sửa tư thế, gù lưng, đau vai gáy, bài tập văn phòng) has ZERO App Store
search demand, so ASO is a commodity home-fitness/weight-loss traffic play and the moat must convert
post-install and be discovered via a second channel (content/social), not search. GTM flag. Nam sets
the three fields in App Store Connect at submission. Post-launch: pull real search terms from ASC
Analytics after ~2-4 wks live, swap dead field words. Detail + supersede -> App Store Listing doc +
Decision Log 06-27.

**Prior checkpoint:** June 26, 2026 (PostHog product analytics integrated + verified; in-app S06 policy
updated). PostHog by Codex, Claude-verified line-by-line: single AnalyticsService consent chokepoint
(default OFF, hard no-op until S06 accept), 8 explicit PII-clean events, pseudonymous identity (Supabase
UID only, identify-on-signin + reset-on-signout, anonymous->identified stitch protected by
_onboardingOwnsAuth guard), EU-resident (eu.i.posthog.com, no autocapture/replay/observer), native
AUTO_INIT=false both platforms, withdraw toggle in Profile. S06 privacy policy updated (§02 usage,
§04 account-linked). Pre-ship gates (Nam-only): real phc_ EU token -> assets/env/app.env, flutter
analyze + build, device smoke. Delegated: Khanh -> website privacy.html §5; Anh Doan -> 2 VN policy
lines; Kiet -> confirm bundled S06 consent PDPL-sufficient. Facebook intentionally HIDDEN not removed.
Design -> Analytics (PostHog) doc; decisions -> Decision Log 06-26.

**Prior checkpoint:** June 24, 2026 (App Store reviewer guide REWRITTEN against 13 reviewer comments +
Review Notes FINALIZED + Facebook hidden). English Apple App Review guide now screen-by-screen; the App
Review Notes block for ASC is FINALIZED (discloses the hidden 5s-hold gate, Apple 2.3.1, the skip flow,
the login link, the 3s lock-on gate; access code kept OUT of Notion). DECIDED squat-only demo is
sufficient (no per-exercise or assessment videos). Facebook fully removed in-app + website (button
already hidden); Supabase provider deletion still Nam's call. WATCH: demo Tuan data empties ~Jun 27,
reseed before review.

**Prior checkpoint:** June 23, 2026 (exercise display NAMES = single source of truth in
exercise_catalog). SHIPPED + Claude-verified: every user-facing exercise name resolves from catalog
vietnamese_name via CatalogSource.vietnameseName + new ExerciseDefinition.displayName extension.
Report-builder INPUT stays raw so scoring/fault keys are UNTOUCHED. Convention = AUTHENTIC USAGE (keep
English where it IS the real VN term, idiomatic Vietnamese elsewhere, yoga `Tư thế [x]`). 13 names
corrected in live DB + bundled asset hand-patched. Decision + convention -> Decision Log 06-23; SSOT ->
Backend & Auth.

**Prior checkpoint:** June 23, 2026 (default training volume = single source of truth in
exercise_catalog, offline). SHIPPED + Claude-verified: standalone-exercise 0-target bug fixed; catalog
now single source for default volume; ExerciseDefinition defaultSets/Reps/HoldSeconds deleted (grep
clean, analyze clean, 315 tests green). App reads volume OFFLINE from build-time asset via CatalogSource
indexing every id alias. _resolveVolume precedence prescription > catalog > floor; kFallback 3/8/30 is a
never-crash guard. Catalog migrated 06-23. App Store NOT yet submitted. Also fixed the between-sets rest
screen freeze (ensureVisualUpdate). Also standalone summary parity (streak honest, per-exercise PB
reachable). Also Android distribution via Firebase App Distribution (project vika-ab175) + demo-video
format bug fixed (all clips transcoded to H.264/8-bit/SDR mp4, assets/video now 28.7MB was 479MB).
Android parity hardening A/B/D/E shipped. Decisions -> Decision Log 06-23.

**Prior checkpoint:** June 21, 2026 (App Store reviewer demo path + Progress gauge metric + demo-account
reseed). Reviewer demo-access path (hidden S13 gate -> demo-session edge fn -> read-only ReviewerPlan
reveal); Progress ĐIỂM FORM gauge headline = period AVERAGE; demo account reseeded to 6 completed weeks.
Decisions -> Decision Log 06-21; slope threshold -> Canonical; demo edge fn -> Backend & Auth.

**Compressed history (June 7-20, all shipped/resolved 2+ checkpoints ago, full detail in named docs):**
- Jun 20, App Review + external-tester guides drafted; superseded by 06-24 rewrite.
- Jun 15 (pass 2), Onboarding home-level scorer reworked (duration-banded, degrade-only) + wall push-up
  assessment wired; duration re-bucketed; Facebook descoped for 6/19.
- Jun 15, Report-builder layer CLOSED (all 40 verified, suite green, 3 pain maps filled provisional;
  only surya stays Generic).
- Jun 14 (pass 2), Squat-reference audit fixes executed. Remainder in Codebase Backlog 06-14.
- Jun 13, Rep-accounting integrity sweep + report-builder coverage complete across all 40 + catalog
  seeded.
- Jun 13, Pain-region vocab unified to canonical 7-zone via canonicalPainRegion() gate.
- Jun 12, Yoga data-logging verification pass.
- Jun 9, iPhone heat/lag perf pass (thermal ladder rejected -> flat FPS cap). Effectiveness UNMEASURED.
- Jun 7, Progress page launch-prep. SUPERSEDED by Progress v2.
- Jun 7, Profile page wired + Apple-2.1-hardened (achievements/journey/referral/connectors/reminders
  stripped, restorable).

**Status:** Recommendation Engine v4.4 shipped end-to-end (05-18). Multi-exercise session flow +
session-level WorkoutSummaryScreen SHIPPED (05-25). v5 onboarding 4-beat emotional Phase 1 in
implementation. Privacy v2 shipped on PDPL framework (05-16). iOS native pose pipeline + presence filter
swap + Phase 2a native segmentation LIVE. Landscape shipped iOS; Android device-confirmed (06-05).
TestFlight 1.0.0 (3) live; Google Sign-In verified on physical iPhone (05-26). Transition + active-screen
ambient feedback redesigned (SHIPPED 05-30). Session form-score aggregator (SessionSummaryBuilder,
composite 0-105) built + reviewed (05-31); summary restructured reward-only (06-01); trophy picker +
two-pillar coach WIRED + frozen (06-02). Per-exercise PB rekeyed off persisted exerciseKey.

**Focus this week:** UI launch-prep, page-by-page. Profile DONE. Progress v2 SHIPPED (device-verify
pending). Report-builder layer CLOSED (surya flow-aware builder pending, Nam owns core + doctor pain-map
review). Onboarding home level scorer + wall push-up assessment DONE. Squat-reference audit fixes
SHIPPED. Exercise world-class pass across 7 form-checked exercises. Squat anti-cheat DONE (ROM gate 36,
direction-based SM, baseline-relative DepthMetric). Push-up full interpreter implemented, thresholds
provisional, folded into the Kiet-led HW build+calibrate track. Library expanding via two dev tracks
(target 6/19): Kiet HW (push-up + ~22 camera exercises), Khanh yoga (Sun Salutation chain). Squat stays
the calibrated demo anchor. Persistence write path DONE + verified (05-30). app_events sink DECIDED:
PostHog EU. Also TestFlight verification + team install validation.

## Top todos
1. TestFlight team validation, UNBLOCKED 07-02 (Xcode runs again). Rebuild + push build 4, verify intent
   flow S01->S16 + sample workout end-to-end, add Khanh + Anh + Kiet + Ha as Internal Testers, capture
   feedback. SIWA chain deferred to 5/24-6/19 window.
2. Session-summary intelligence, WIRED (06-02; coach faultCounts bug + perfect-gate fixed 06-03). Trophy
   picker + two-pillar coach wired + frozen. Residual: metricCriticalityOrder() now dead (delete or
   repoint). Pre-beta: verify issue-mode popup doesn't overflow small phones; hero score-climb tween
   fires at build not reveal. Share CTAs still stubbed. Live TODO list: grep -rn "TODO(wiring)" lib/.
3. Onboarding logic refinement sweep. v5 UI locked, several decision points still on v1 hardcoded
   heuristics. Cheap wiring first: painAreas -> exercise mods via painAreaMap (#10), intent_quote at
   Day-1 Closer (#11). Then #1 WHY follow-ups, #3/#4 Phase1 candidates+coach text, #5 yoga ROM scoring,
   #7 schedule freq. Full list in Onboarding Flow doc.
4. Onboarding re-login fix, DECIDED 06-05, Codex prompt handed off, impl + verify pending. Add login
   entry state; move markComplete:true to S13 onAuthenticated; stop clearing local flag on signout.
   Detail + rejected alts -> Decision Log 06-05.
5. Progress page (Tiến bộ) v2, SHIPPED, not device-verified (confirmed 07-02). Trajectory line +
   milestone rail + ranked insights all wired; gauge direction chip REMOVED (supersedes 06-21 Canonical
   decision). Nam to: draft period-ranker scoring (core, Theil-Sen slope, >=3 gate), refine VN copy,
   set MIN_IMPROVEMENT_SLOPE + trajectory "high" cutoff, device-smoke pain feature. Ranked insights
   renders guided-empty until per-exercise builders land (data dependency). Detail -> Progress
   Experience doc.

## Active blockers
- No physical-Android full-session test yet = the Android validation gate. Build + video + Firebase
  distribution all work, but nobody has run a full session (camera + pose + rep-count + set-complete +
  mid-set back-guard) on a real ARM Android phone. Emulator can't test it. ALSO pending Play Store:
  switch flutter build apk -> appbundle, create a real release keystore + register its NEW SHA-1 in
  Google Cloud BEFORE first use (current builds debug-keystore-signed; a new keystore without its SHA
  registered breaks auth for everyone).
- Xcode builds again (07-02), the launch bottleneck cleared for now. Was a stale/paused process; a Mac
  reset fixed it. NOT the underlying Xcode-26 FLUTTER_BUILD_DIR bug (still latent, can recur). Now
  actionable: rebuild + push build 4, validate FPS cap shipped at 24 (vs no-op 30), run 10-min
  Allocations + thermal over 20-min session to confirm/refute the unmeasured native CVPixelBuffer leak,
  device-check resume-mid-rep + rapid bg/fg.
- Coach exercise coverage, RESOLVED 06-13. All 40 resolve to a working builder; only surya_namaskar
  stays Generic (flow-aware builder pending total_safety_triggers surfacing -> Backlog).
- Push-up interpreter, implemented (8 bugs + anti-cheat) + landscape. Anti-cheat thresholds provisional,
  separation test + calibration inside the Kiet-led HW track. Numbers -> Canonical.
- Voice phrase list, not finalized.
- Doctor combo patterns, awaiting doctor meeting; feeds Clinical Patterns doc. Verify whether the
  cross-exercise clinical layer is actually BUILT vs spec-only before launch.
- Provisional clinical decisions await doctor sign-off (06-13): canonical 7-zone pain vocab, fork
  pain->yoga/home weights, S09 region mappings all SHIPPED provisional; VN verification doc prepared for
  doctor. Corrections overwrite provisional when they land. Not blocking 6/19.
- Curl-up trunk_elevation thresholds, provisional 05-04, awaiting PT video calibration (7-clip template
  sent).
- Codemagic CI setup, needed before next TestFlight push. ~1-2h one-time.
- Privacy gaps before external 30-50 user test (internal 5/24 OK). PostHog EU: pending real phc_ token +
  analyze/device smoke. Age-16 gate DONE. Withdraw/export/delete shipped. Remaining: Kiet to confirm
  bundled S06 consent PDPL-sufficient + DPIA/TIA filings, Anthropic integration-intent confirm.
- Kiet confirm Vika VN legal entity, gates Apple Org account + D-U-N-S. Doesn't block 6/19.
- v4.4 catalog calibration SQL ready, not yet applied to DB.
- OAuth redirect verify (GAP-#3): com.vikavn.app://login-callback registered across Supabase + Info.plist
  + AndroidManifest for all 3 providers. Google verified on physical iPhone (05-26). Facebook
  intentionally HIDDEN not removed, WILL return; native config retained ON PURPOSE, NOT cleanup debt.
- Session RPE vs per-exercise difficulty = OPEN redundancy (leaning cut). onSessionRpe retained as an
  unused hook. Held out of Decision Log until resolved.
- Completion-anchored progression gaps: plan_completed_at writer + long-gap guard (provisional 14d, not
  built). Forward gotcha: once plan_completed_at IS written, the active-only snapshot fetch drops
  completed plans, starving BOTH retest and Plan tab; whoever wires plan-completion must keep them fed.
- Flagged-dead code (flag, do not delete unasked; full list -> Codebase Backlog): executive_summary_page,
  exercise_comparison_service (SessionComparison), plan_screen_legacy, the set_data completion cluster,
  widget.program in plan_screen, difficulty_rating_block, several progress mocks.
- vikavn.app landing + /support + /privacy URLs must be live before App Store submission (queue for
  Khanh).
- Demo account reseed watch. Seeded to mid-week 5 as of ~06-27 (UID 6def169a-..., plan cab43878); Tuần
  tab empties ~07-04 if review hasn't happened. Quick date-shift re-anchor fixes it.

## Phase 2 cleanup (post-launch, non-blocking)
MediaPipe version skew iOS 0.10.21 vs Android 0.20230731; simplify iOS visibility-fallback-chain to
visibility-only; delete stale MainActivity.kt orphan; drop frameBytes from Android pose emission
(~42MB/sec); SharedPreferences->Supabase migration audit; per-exercise voice asset migration off Viettel
TTS; legacy onboarding + orphan screen cleanup; drop orphaned profiles.last_workout_at; set-duration
capture deferred; rebrand remaining Supabase auth email templates to Premium Ivory; SMS auth revisit if
beta data shows email-only signup completion hurting.

## Roadmap (at a glance)
Week 5 of build. Phase 1 Contest (Wks 1-5): CANCELLED, both rejected, work carried forward. Phase 2 Build
MVP (now->July): working app on stores, 2,000 downloads. Hard dates: intern test ~6/12 -> 30-50 user beta
-> first App Store submission 6/19 -> live ~mid-July. Phase 3 Launch (Jul->Aug): data-dependent. Phase 4
Monetization (Aug->Dec): PRO paywall, payments, AI coach insights (Haiku), ML threshold personalization
at 200+ sessions, library to 30+, challenges, PT tier.

## Tech snapshot
Flutter/Dart, MediaPipe Pose Landmarker Lite (33 landmarks ~30fps, iOS native + Android), One Euro
Filter, StickyDebouncer, Supabase (auth + profiles + RLS, Singapore), Viettel TTS (squat migrated to
pre-recorded assets), rules-based ML Phase 1. Architecture + gotchas -> Vika Context doc. Interpreter/
exercise pipeline -> Interpreter System + Exercise Implementation Guide. Two UI registers (Premium Ivory
active, legacy v3) -> UI Design System v3 doc.

## Validation
Survey: 151 respondents, ICP office workers 25-45, WTP >=99K. Full stats -> canonical-numbers.md +
vinafit-survey-analysis.docx.

## Team
Tech: Nam (founder/CTO), Anh Doan (voice + exercise specs), 3 exercise devs. 1 tester acting as PT for
threshold review. Mac teammate runs Codemagic CI / iOS builds. Exercise build + calibrate lane: Kiet (HW
track: push-up + ~22 camera exercises) + Khanh (yoga track: Sun Salutation chain), dev-led, target 6/19;
interpreter logic changes route through Nam (core). Business: Kiet (business/legal lead, DPO), Ha
(marketing), +3. Ops: Khanh (PM, ASC Admin + shared Apple ID). Comp: unpaid, plan to pay from PRO
revenue ~6mo in. Equity deferred.

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
judge/investor metrics. Platform Vision (B2B doctor referral flywheel) parked until product one has
paying users. Detail -> ~/vika-ops/.

## Pointers
Decisions + rationale -> docs/decisions.md. Numbers -> docs/canonical-numbers.md. Reference docs ->
docs/reference/. Business/vision/compliance -> ~/vika-ops/. Code bugs / cleanup / ideas -> Codebase
Backlog.
