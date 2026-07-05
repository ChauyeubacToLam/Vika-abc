# Vika — CLAUDE.md

Single shared agent manual. Claude Code reads this as CLAUDE.md; Codex reads the same bytes as
AGENTS.md (symlink). Edit here only, never fork the two.

Two parts:
- Part 1, how we work together. Authored and current, trust it.
- Part 2, the codebase map. Inherited from the old auto-generated file, UNVERIFIED. Orientation
  only: confirm any claim against the actual code before relying on it, and fix it here when you do.

Vika: on-device pose-detection fitness coach for Vietnamese urban professionals. Flutter/Dart,
on-device ML Kit pose detection + selfie segmentation, Supabase (Singapore). All user-facing strings
are Vietnamese.

================================================================
PART 1 — HOW WE WORK  (authored, current)
================================================================

## Voice
Direct, terse, informal. Match my register; short reactions ("Oke", "Ight", "Bruh what") are
approve/reject signals, don't re-explain them. Always give the why behind a call. Don't hedge when
the info supports a clear one. No corporate tone. No em dashes. Be super direct, don't over-explain,
but still flag what I haven't thought about.
User-facing copy (coaching, UI) is Vietnamese and encouraging ("Tốt lắm! Lần sau hạ thấp hơn chút
nhé", never drill-sergeant). Code and docs are English.
Writing prompts for other models (Codex): your plan is a suggestion, not the only way. Give goal +
current-state evidence + suggested approach (not line-by-line) + hard don't-touch fences + what
evidence to report back. Leave room to push back.

## How you work
Think before coding, state assumptions. 2+ interpretations, surface them, don't pick silently.
Simpler path exists, say so. Minimum code that solves it, no speculative abstraction or config.
Surgical: touch only what the request needs, match existing patterns even if you'd do it
differently, flag dead code don't delete it unless asked.

## Answer depth
- Full (new feature, exercise research, architecture, multi-interpretation): restate goal, extract
  constraints, name gaps, 3-5 sentence plan, then execute.
- Light (specific screen/widget, debug, defined task): one-line restate, go.
- Direct (quick fact, error explanation, small fix): just answer.

## Delegation (T1-T4, set by whose muscle the work builds)
- T1 = mine solo. Core algorithms, scoring math, CV/state-machine logic, anti-cheat gates. You review
  and stress-test, never write the paste-ready core body. (native/platform plumbing is the exception.)
- T2 = I draft, you pressure-test. I bring transitions/thresholds/structure; you attack edge cases,
  tradeoffs, keep-vs-cut, test shape. Guide actively, just withhold the finished core.
- T3 = you draft. UI/Flutter, locked patterns, mechanical transcription of a formula I already
  authored against a known-good in-repo reference. Line-by-line recheck is mandatory.
- T4 = you execute. Docs, glue, research, non-core plumbing.
Debug first pass: I bring a written hypothesis; you sharpen my understanding, not hand the fix.
Urgency override: explicit "ship it", you write it, annotate the concept, note the learning debt.

Example:
Me: "Just write the rep-counting state machine for Cobra, I'll plug it in."
You: "That's T1, the state machine is the CS muscle. Send me your transition logic (directions +
thresholds) and I'll stress-test it. Time-boxed? Say 'ship it' and I'll write it with annotations +
a logged learning debt."

## Grounding (before you answer)
Any Vika-specific question about architecture, a number, status, a screen, an algorithm, or a shipped
feature: read the relevant docs/ file or grep the code first. Don't answer from memory; that
overconfidence is the leak. Read docs/canonical-numbers.md before quoting ANY number.
Conflict: canonical-numbers > state.md > reference docs. Conflict, stop and flag, don't pick silently.
"Did we decide / try / discuss X": check docs/decisions.md, then git log, then conversation_search,
then say "no record." Never claim no record without checking.

## Writing docs (one fact, one place)
Numbers, docs/canonical-numbers.md. Status/todos/blockers, docs/state.md. Decisions + rationale,
docs/decisions.md (append-only, mark superseded, never delete). Design/algorithm/schema, the owning
docs/reference/ doc. grep for a fact before writing it; update in place, never a second copy.
docs/state.md is a living snapshot, NOT an append log: date items, move shipped out, delete stale.
If it only grows, it's rotting.

## Data (Supabase — PROD, project frjtlfzbvdgwgzegfzxh, vinafit-prod, Singapore)
Default read-only.
- Reads (SELECT, list tables, inspect schema): run directly.
- Writes + schema (INSERT/UPDATE/DELETE, DDL, migrations): DO NOT execute. Draft the SQL / migration,
  hand it to me, I run it. Read back only after I confirm it applied.
- Seeding: UPDATE placeholder rows, don't INSERT (preserve FKs). Delete children before parents.

## Ask first
- Before any change to the exercise pipeline architecture.
- Before recommending a new dependency or external service.
- Before acting on a decision tagged provisional in docs/decisions.md.
- When a request has more than 1-2 critical unknowns.

## Escalate, then ask
Surface before proceeding: timeline conflict (Vika vs non-Vika), business/revenue call, anything with
a life implication, or a burnout signal. Destination docs: Blueprint + Vision in ~/vika-ops/.

## Heavy tasks
Exercise research, architecture decisions, any "should we" with downstream impact: produce an
Architecture Decision Doc first (problem, 2-3 ranked approaches, recommendation + reasoning,
Vietnamese-market considerations) before any code. File it in docs/decisions.md.

## Product guardrails (general; exercise mechanics are PT-decided and live in the exercise-build skill)
- An exercise is never an isolated feature. Each one touches library, progress, onboarding, and trust.
- Vietnamese market: no Western body-proportion or gym-culture assumptions.
- Never paywall safety.
- Feedback: post-rep coaching by default; real-time alerts only for safety.
- Data honesty: coaching text draws from measured fault counts only. Never tell a user something the
  system didn't actually measure.

## Deliverables
- UI/Flutter: follow the Premium Ivory design system (Part 2).
- Core logic (T1/T2): no scaffolding, signatures, or paste-ready bodies. Urgency override only.
- Research: structured .docx, citations, confidence levels, explicit detection limits.
- Docs: structured headers, tables for thresholds, prose for explanation.

## Self-correction
When I correct a mistake, propose the one-line rule (here or in the owning doc) that prevents the
repeat. When you add a rule, check whether an old one can come out. Keep Part 1 lean.

================================================================
PART 2 — CODEBASE MAP  (inherited, UNVERIFIED, orientation only)
================================================================
Confirm against code before trusting. Fix inline when you verify or find drift.

## Commands
```bash
flutter pub get          # install dependencies
flutter run              # run on connected device/emulator
flutter test             # run tests
flutter analyze          # dart analyzer/linter
flutter clean            # clear build cache (fixes most build issues)
```

## Architecture
Two largely independent halves sharing auth + persistence:
1. Main app shell: `MainShell` (lib/screens/main_shell.dart), IndexedStack of 5 tabs with a frosted
   IvoryBottomNav (lib/widgets/ivory/bottom_nav.dart). Tabs: 0 Trang chủ DashboardHomeScreen, 1 Lộ
   trình PlanScreen, 2 Khám phá LibraryScreen, 3 Tiến bộ ProgressScreen, 4 Hồ sơ ProfileScreen.
2. Real-time exercise capture: full-screen camera + pose pipeline via
   Navigator.pushNamed('/exercise', arguments: ExerciseDefinition).

### Premium Ivory design system
Two parallel theme registers, DO NOT MIX:
- Main app: VikaColors.of(context) in lib/theme/app_colors.dart, auto light/dark. Tokens in
  lib/theme/tokens/colors_light.dart + colors_dark.dart. Plan typography helpers in
  lib/widgets/plan/plan_typography.dart (PlanH1, PlanEyebrow, PlanP). Tabular figures via
  VikaIvoryMain.tabularFigures.
- v5 onboarding: self-contained V5.* namespace in lib/screens/onboarding/v5/v5_theme.dart +
  v5_primitives.dart. Do not import V5 into main-app screens or vice versa.
Legacy jade-green VFTheme still backs exercise/auth screens. Don't extend it.
Stage hero pattern (Home/Plan/Library): full-bleed dark stage hero at top, bleeds past MainShell
SafeArea via MediaQuery.removePadding(removeTop: true); warm-dark gradient, film grain uses
Random(seed) never time-based. Follow the same shape when adding a primary tab.
Pure black/white forbidden on Ivory surfaces: use ink (#1F1812) not black, bgRaised (#FBF7EE) not
white. Yellow #FFB701 reserved for four uses only: stat / dot / underline / CTA.

### Library is data-driven
LibraryScreen iterates librarySections (List<LibrarySection> in lib/data/library_mock.dart).
LibrarySection is a Dart 3 sealed class (Featured/Rail/List/StatBand/Catalog); each declares
filterKinds. Adding content = append to librarySections; the exhaustive switch in _buildSection()
forces a compile error until a new subclass is handled.

### Real-time pose pipeline (per frame)
Camera → ML Kit pose detection → One Euro Filter smoothing → person detection (selfie segmentation)
→ exercise state machine → per-metric analysis → UI feedback.

### Exercise system  (the surface future devs scale)
ExerciseBase (lib/exercise/exercise_base.dart) is the abstract base. Three-state machine:
notActivated → activated → completed. Activation = hold correct start position 3s. Active = compose
multiple Metric objects each analyzing one form aspect. Completion = target reps reached.
Each exercise lives in lib/exercise/<name>/ with a metrics/ subdir. Register new exercises in
ExerciseDefinition (lib/models/exercise_definition.dart) with metadata + factory. Lookup by id via
lookupExerciseDefinition() in lib/models/exercise_lookup.dart.

### Recommendation engine (lib/services/recommendation/)
RecommendationService.ensurePlanForCurrentUser(trigger:) returns PlanSnapshot, persists via Supabase.
Plan model (models/plan.dart): Plan → WeekPlan → SessionPlan → SlotAssignment → VolumePrescription;
v4.3 = 2 phases x 3 weeks + 1 deload = 7 weeks. FitnessRetestService (pending re-test after deload).
WeeklyCheckInService.isDue(recommendationId, weekNumber). Internals: recommendation_engine.dart,
progression_rules.dart, progression_service.dart, scoring.dart, stochastic_sampler.dart, templates.dart.
Plan tab adapts snapshot via _PlanWeekMapper.fromSnapshot() into lib/data/plan_mock.dart display models.

### Persistence + auth
Supabase (supabase_flutter): tables recommendations_log, executive_summary, pending_fitness_retests,
weekly check-ins. AuthService handles Google/Apple/Facebook. SharedPreferences via
OnboardingPersistence for onboarding flag + ephemeral state.

### Key utils (lib/utils/)
PoseSmoother (One Euro Filter), PersonDetector (selfie segmentation ~7Hz, dual-threshold 0.92 strict
/ 0.35 coverage, 650ms presence confirm), FrameBuffer (per-frame snapshots for peak/angle),
ExerciseLogger (per-rep → set summaries), StickyDebouncer/Debouncer (5-frame hysteresis for
orientation), OrientationLock.

### Interpreter + voice
lib/interpreter/ analyzes logged data post-set for form issues + coaching (squats only:
SquatInterpreter). Voice: SquatVoiceCoach + QueuedAssetVoicePlayer for real-time TTS; ViettelTtsService
for cloud Vietnamese lines; assets in assets/voice/.

## Key patterns
No external state management (StatefulWidgets + local state + direct mutation). Camera facing
auto-detection via shoulder-width/torso-height ratio (FRONT >0.57, SIDE <0.35). Scale factor from
shoulder-to-hip distance normalizes metrics across body sizes. Single frameTimestamp per frame.
ResultIssues.feedback cleared every frame (current-frame only); ResultIssues.instructions keyed by
phase, persists across frames.

## Conventions
Constants UPPER_SNAKE_CASE (analyzer ignores constant_identifier_names). Classes PascalCase,
vars/methods camelCase. Exercise dirs may contain spaces (e.g. "glute bridge/"). flutter_lints.
Single font: Be Vietnam Pro (400/500/700/800 + italics), no other fonts. Data-wiring TODOs use
// TODO(wiring): so they're greppable.

## Dependencies
camera, google_mlkit_pose_detection, google_mlkit_selfie_segmentation (transitive), permission_handler,
supabase_flutter, google_sign_in / flutter_facebook_auth / sign_in_with_apple, shared_preferences,
audioplayers, http (Viettel TTS), native_device_orientation.
