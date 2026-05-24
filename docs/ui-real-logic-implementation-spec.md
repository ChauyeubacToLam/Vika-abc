# Vika UI Real Logic Implementation Spec

Date: 2026-05-23
Audience: Vika engineering/product
Purpose: Replace every remaining mock/hardcoded UI surface with real Supabase-backed logic in a way that stays scalable, testable, and calm to maintain.

This spec builds on:

- `docs/ui-hardcoded-logic-report.md`
- `docs/supabase_schema_reference_v4_4.md`
- `docs/recommendation_engine_v4_4_report.md`
- `docs/PREMIUM_IVORY_WIRING.md`
- Existing services in `lib/services/session_persistence.dart`, `lib/services/recommendation/*`, `lib/services/onboarding_persistence.dart`, and `lib/services/issues_service.dart`

## Executive Summary

The current redesigned UI is visually ready, but several pages still render from mock constants. The right fix is not to sprinkle Supabase calls inside widgets. The right fix is to create a small "UI data layer" that turns raw Supabase rows into screen-ready snapshots:

- Home needs a `HomeDashboardSnapshot`.
- Plan needs a `PlanUiSnapshot`.
- Progress needs a `ProgressSnapshot`.
- Profile needs a `ProfileSnapshot`.
- Library needs a real catalog/content source.
- Exercise runtime needs live session telemetry wired into the Ivory chrome.
- Onboarding needs remaining interpreters and less hand-authored result logic.

Think of it like this:

```text
Supabase rows / plan JSON / local prefs
        ↓
repository/service methods
        ↓
screen snapshot DTOs
        ↓
widgets render pure data
```

Widgets should stay almost boring. The intelligence belongs in services, mappers, and tests.

## Source Of Truth

### Supabase Tables Already Documented

From `docs/supabase_schema_reference_v4_4.md`:

- `recommendations_log`
  - Active plan = latest row for user where `plan_completed_at IS NULL`, ordered by `generated_at`.
  - `plan_structure` contains weeks, sessions, slots, volumes, check-in weeks, and end retest metadata.
- `exercise_sessions`
  - One row per exercise, not one row per workout.
  - A 4-exercise workout creates 4 rows.
  - `set_data` is an array with prescribed/actual reps, rest, recommendation id, week number, and deload flag.
- `user_exercise_capacity`
  - Per-exercise progression state, carry-over, and unlocks.
- `weekly_checkins`
  - Weekly wellness snapshots.
- `fitness_retests`
  - End-of-plan retest results.
- `profiles`
  - Onboarding writes `gender`, `height_cm`, `weight_kg`, `age`, `goals`, `training_duration`, `fork`, `fitness_level`, and `schedule_sessions`.
  - `profiles.created_at` and `profiles.updated_at` are legacy text, so parse carefully.

### Existing App Services

Use these first:

- `RecommendationService`
  - Fetches/generates active plans from `recommendations_log`.
- `SessionPersistence`
  - Saves exercise sessions.
  - Fetches per-exercise history.
  - Updates `profiles.streak` and `profiles.last_workout_at`.
- `RecommendationProgressionService`
  - Reads carry-over and unlock state.
  - Updates `user_exercise_capacity` after session saves.
- `WeeklyCheckInService`
  - Reads/submits `weekly_checkins`.
- `FitnessRetestService`
  - Reads pending retests and submits `fitness_retests`.
- `OnboardingPersistence`
  - Writes profile, pain areas, fork decisions, and camera-detected issues.
- `IssuesService`
  - Reads/writes `user_detected_issues` and reflects confirmed issues into `user_pain_areas`.

## Quality Bar

Before touching each screen, hold these rules:

1. A screen receives one snapshot object and renders it.
2. Supabase querying lives in services, not widgets.
3. Every aggregate has a deterministic test with fake rows.
4. Real data failures show graceful empty/loading states, not mock data that lies.
5. We keep mock constants only for preview/dev fixtures, never production rendering.
6. Every number on screen should answer: "Which table/field produced me?"

## Foundation: Add A UI Data Layer

Create this structure:

```text
lib/models/ui/
  home_dashboard_snapshot.dart
  plan_ui_snapshot.dart
  progress_snapshot.dart
  profile_snapshot.dart
  library_content_snapshot.dart

lib/services/ui_data/
  session_analytics_service.dart
  workout_plan_service.dart
  home_dashboard_service.dart
  progress_summary_service.dart
  profile_summary_service.dart
  library_content_service.dart
```

### Why This Layer Exists

Supabase data is storage-shaped. UI is story-shaped.

For example, `exercise_sessions` says:

```text
exercise_id=squat_bw, form_score=78, completed_at=...
```

The Progress page wants:

```text
"Chân +18 · Squat sâu hơn"
```

That translation should be in `ProgressSummaryService`, not in `ProgressScreen`.

## Foundation: Fix Workout Grouping

### Context

The schema says `exercise_sessions` is per exercise. The UI wants "Buổi 03" as a workout containing multiple exercises. Today the Plan CTA launches the first slot only; Home now launches the first launchable exercise from the assigned program. That is enough to open the camera, but not enough to finish a full workout flow.

### Proposed Approach

Add a workout grouping contract. You can do this without creating a new table at first by adding fields to `exercise_sessions`, but a separate `workout_sessions` table is cleaner.

Recommended production model:

```sql
create table public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  recommendation_id uuid references public.recommendations_log(id),
  week_number integer,
  session_index integer,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  status text not null default 'in_progress',
  total_exercises integer not null default 0,
  completed_exercises integer not null default 0,
  avg_form_score integer,
  total_reps integer not null default 0,
  total_good_reps integer not null default 0,
  total_seconds integer,
  calories integer
);
```

Then add nullable columns to `exercise_sessions`:

```sql
alter table public.exercise_sessions
  add column if not exists workout_session_id uuid references public.workout_sessions(id),
  add column if not exists session_index integer,
  add column if not exists slot_index integer;
```

### How To Do It

1. Create the migration.
2. Add RLS policies: users can select/insert/update rows where `auth.uid() = user_id`.
3. Create `WorkoutRunService`.
4. When user taps "Bắt đầu Buổi N":
   - Create a `workout_sessions` row.
   - Push first exercise with `workoutSessionId`, `sessionIndex`, and `slotIndex`.
5. After each exercise completes:
   - Save `exercise_sessions.workout_session_id`.
   - Navigate to next slot.
   - When last slot completes, update `workout_sessions.completed_at`, `status='completed'`, aggregates.

Teaching note: this is the keystone. Once workouts are grouped, Home/Plan/Progress/Profile can reason about "sessions completed" without guessing from individual exercise rows.

## Shared Analytics Service

### Context

Home, Progress, Profile, and Plan all need similar aggregates:

- sessions completed
- streak days
- average form
- form trend
- last 7/14/30 days
- per-exercise changes
- per-body-region changes

### Proposed API

Create `SessionAnalyticsService`.

Core methods:

```dart
Future<List<ExerciseSessionRow>> fetchSessions({
  required DateTime from,
  DateTime? to,
  String? recommendationId,
  String? exerciseId,
});

Future<FormTrend> formTrend({required PeriodWindow period});

Future<List<bool>> completionBars({required int days});

Future<int> currentStreakDays();

Future<LifetimeStats> lifetimeStats();

Future<List<ExerciseProgressInsight>> rankedExerciseInsights({
  required PeriodWindow period,
});

Future<List<BodyRegionScore>> bodyRegionScores({
  required PeriodWindow period,
});
```

### Data Row Shape

Make a typed row model. Do not pass raw maps around.

```dart
class ExerciseSessionRow {
  final String id;
  final String exerciseId;
  final String? recommendationId;
  final String? slotName;
  final int? weekNumber;
  final int formScore;
  final int totalReps;
  final int totalGoodReps;
  final int totalSets;
  final int? calories;
  final DateTime startedAt;
  final DateTime completedAt;
  final Map<String, int> faultCounts;
  final List<String?> difficultyRatings;
  final List<Map<String, dynamic>> setData;
}
```

### Query

Use the existing table:

```dart
final rows = await client
  .from('exercise_sessions')
  .select('id, exercise_id, recommendation_id, slot_name, started_at, completed_at, form_score, total_reps, total_good_reps, total_sets, calories, fault_counts, difficulty_ratings, set_data, overall_difficulty')
  .eq('user_id', userId)
  .gte('completed_at', from.toUtc().toIso8601String())
  .lte('completed_at', to.toUtc().toIso8601String())
  .order('completed_at', ascending: true);
```

### Tests

Test each aggregate with hand-built rows:

- empty history
- one session
- multiple sessions on same day
- missing form score
- sessions across week boundary
- sessions with different `recommendation_id`
- deload sessions

## Home Tab Spec

### Current Hardcoded Areas

- `homeMockToday`
- `homeMockWeekLabel`
- `homeMockPhaseLabel`
- `homeMockSessionsDone`
- `homeMockSessionsTotal`
- `homeMockStreakDays`
- `homeMockFormToday`
- `homeMockFormDelta`
- `homeMockFormWeek`
- `homeMockCoachQuote`
- user initial/name

### Context

Home is the user's "what do I do now?" page. It should not be a generic summary. It should answer:

- What is today's planned workout?
- How many exercises?
- Which exercises use AI?
- How far am I through this week?
- Is my form improving?
- What should I focus on today?

### Proposed Data Contract

Create `HomeDashboardSnapshot`:

```dart
class HomeDashboardSnapshot {
  final String userName;
  final String userInitial;
  final String eyebrow;
  final String titleLine1;
  final String titleLine2;
  final String duration;
  final int totalCount;
  final int aiCount;
  final List<HomeStageExercise> exercises;
  final String ctaLabel;
  final String weekLabel;
  final String phaseLabel;
  final int sessionsDone;
  final int sessionsTotal;
  final int streakDays;
  final int formPercent;
  final int formDelta;
  final List<int> formWeek;
  final String statusLine;
  final String coachQuote;
  final ExerciseLaunchPlan launchPlan;
}
```

### Data Sources

- Active plan: `RecommendationService.fetchLatestActivePlanSnapshotForCurrentUser()`
- Profile: `profiles`
- Completed workouts: `workout_sessions` if added, otherwise group `exercise_sessions`
- Form trend: `SessionAnalyticsService.formTrend(last7Days)`
- Streak: `profiles.streak` or analytics fallback
- Exercise definitions: `lookupExerciseDefinition(slot.exerciseId)`

### Algorithm

1. Fetch active plan snapshot.
2. Determine current week from `PlanSnapshot.currentWeekNumber`.
3. Pick today's session:
   - Use `week.sessions`.
   - Map sessions to days with the same logic currently in `_PlanWeekMapper._sessionDayIndexes`.
   - If today is a scheduled day, use today's session.
   - If not, use the next upcoming session in the current week.
   - If no upcoming session, use first session of next week.
4. Convert slots to `HomeStageExercise`.
5. Count AI slots by `lookupExerciseDefinition(slot.exerciseId) != null`.
6. Compute sessions done / total:
   - Best: count completed `workout_sessions` for recommendation/week.
   - MVP: count distinct local dates or distinct slot groups in `exercise_sessions`.
7. Build coach quote from simple templates:
   - If form down: "Hôm nay nhẹ lại một nhịp..."
   - If streak active: "Đang giữ nhịp..."
   - If pain flag from weekly check-in: "Ưu tiên chậm và sạch..."
8. Build launch plan for full workout sequence.

### How To Implement

1. Add `HomeDashboardService.load()`.
2. Replace the direct `homeMock*` usage in `DashboardHomeScreen` with a `FutureBuilder<HomeDashboardSnapshot>`.
3. Keep a skeleton/loading hero using the same visual shell.
4. Keep `homeMock*` only for widget previews/tests.
5. Add tests:
   - no active plan
   - active plan with today scheduled
   - active plan with no workout today
   - plan has unsupported exercise
   - sessions done from DB rows

## Plan Tab Spec

### Current Hardcoded Areas

- user initial `'N'`
- completed-week average form `78`
- per-exercise form `78`
- static recap, best-day, coach, chapter copy
- partial workout launch: starts the first slot only

### Context

Plan is the calendar contract. It should show what the algorithm prescribed and what the user actually completed.

### Proposed Data Contract

Keep the existing `PlanWeek`, `PlanDay`, and `PlanExercise` UI models if they are stable. Add a mapper service:

```dart
class PlanUiSnapshot {
  final String userInitial;
  final List<PlanWeek> weeks;
  final int currentWeekIndex;
}
```

### Data Sources

- Active plan: `recommendations_log.plan_structure`
- Completion/form: `workout_sessions` or grouped `exercise_sessions`
- Profile initial: `profiles` or `auth.user.userMetadata`
- Pending retest: `FitnessRetestService.fetchPendingRetestForCurrentUser()`

### Algorithm

1. Fetch active plan snapshot.
2. Fetch sessions for this `recommendation_id`.
3. For each `WeekPlan`:
   - status = done/current/future.
   - sessions = `week.sessions.length`.
   - completed = completed workout count for week.
   - avgForm = average completed workout `avg_form_score`; fallback average exercise `form_score`.
4. For each `SessionPlan`:
   - Convert slots to `PlanExercise`.
   - `form` = latest form score for that slot in that week if completed.
   - `hasAi` = local `ExerciseDefinition` exists.
5. Generate coach copy from real status:
   - not started
   - partially complete
   - complete with high form
   - complete with low form
   - deload
6. CTA creates a `WorkoutRun` for all slots, not just first slot.

### How To Implement

1. Move `_PlanWeekMapper` out of `plan_screen.dart` into `WorkoutPlanService`.
2. Inject analytics into mapper.
3. Add `WorkoutRunService.startSession(WeekPlan week, SessionPlan session)`.
4. Update `ExerciseLaunchArgs` to carry:
   - `workoutSessionId`
   - `sessionIndex`
   - `slotIndex`
   - `remainingSlots` or a `WorkoutRunPlan`
5. After an exercise summary, route to the next slot automatically.
6. Tests:
   - week status
   - completion count
   - form score mapping
   - deload copy
   - unsupported exercise handling

Teaching note: Plan should never compute from mock calendar state. It should be a pure projection of the active plan plus completion rows.

## Library Spec

### Current Hardcoded Areas

- library filters still have hardcoded counts
- programs/collections/albums are static
- some cards do not open real detail pages
- search button is placeholder
- legacy `exercise_browser.dart` is stale

### Context

Library has two kinds of content:

1. Exercises the camera can run today.
2. Curated editorial content: programs, collections, albums, yoga series.

These are different. Exercises should be generated from canonical definitions/catalog. Curated content can stay content-managed/static, but it should live in a real registry, not scattered mock constants.

### Proposed Data Contract

Create:

```dart
class LibraryContentSnapshot {
  final List<LibraryFilter> filters;
  final List<LibrarySection> sections;
  final int totalCount;
}
```

### Data Sources

- AI exercise definitions: `exerciseDefinitions`
- Full exercise catalog: Supabase `exercise_catalog`
- Curated sections: start with JSON asset, later Supabase table or CMS
- Active program tag: active `recommendations_log.template_key`

### Approach

MVP:

- Keep curated program/collection/album lists local but rename them from "mock" to "content".
- Generate all AI exercise rows from `exerciseDefinitions`.
- If Supabase `exercise_catalog` is available, enrich rows with:
  - Vietnamese name
  - category/body region
  - difficulty tier
  - `is_form_checked`
  - variant/progression metadata

Later:

- Move curated content to `library_content` table or JSON assets.

### How To Implement

1. Create `LibraryContentService.load()`.
2. Convert `libraryMockAllExercises` to generated rows.
3. Compute filter counts from rows/sections.
4. Wire search:
   - Add `TextEditingController`.
   - Normalize accents and lowercase.
   - Filter by title/name/category.
5. Wire card taps:
   - exercise card -> `/exercise`
   - program card -> program detail page
   - collection card -> `LibraryBrowseScreen` or collection detail
   - album card -> album detail
6. Delete or quarantine `exercise_browser.dart` once MainShell is stable.

### Tests

- filters count correctly
- search finds Vietnamese/accentless queries
- unsupported content card does not crash
- exercise row maps to correct `ExerciseDefinition`

## Progress Tab Spec

### Current Hardcoded Areas

- `progressMockHeadline`
- body heat map areas
- weekly/month/program summary stats
- score trend
- ranked insights
- personal records
- streak bars and milestone
- hardcoded user initial
- `phaseWeeksMock`

### Context

Progress is not just a dashboard. It is a translation layer from raw session data into "what changed in my body and form?"

### Proposed Data Contract

```dart
class ProgressSnapshot {
  final String userInitial;
  final String phaseLabel;
  final String weekLabel;
  final HeadlineForPeriod headline;
  final List<WeeklyStat> summary;
  final List<int> scoreTrend;
  final (String, String, String) trendAxis;
  final List<BodyHeatArea> bodyAreas;
  final BodyGender gender;
  final List<ExerciseInsightMock> insights;
  final List<PersonalRecord> records;
  final int streakDays;
  final List<bool> streakBars;
  final String streakSummary;
  final int nextMilestone;
}
```

You can later rename `ExerciseInsightMock`; for the first refactor, reuse the visual model to reduce blast radius.

### Data Sources

- Sessions: `exercise_sessions`
- Active plan: `recommendations_log`
- Profile: `profiles.gender`, `profiles.streak`
- PRs: derived from session history and metric values
- Body area mapping: local canonical map

### Period Windows

Define:

```dart
enum ProgressPeriod { week, month, program }
```

Mapping:

- week = last 7 days
- month = last 30 days
- program = from active plan `plan_started_at ?? generated_at`

### Algorithms

#### Headline

1. Fetch sessions in period.
2. Group by date or chronological order.
3. `from` = average form score of first bucket.
4. `to` = average form score of last bucket.
5. `delta` = `to - from`.
6. Coach copy:
   - positive: mention best improving exercise
   - flat: mention consistency
   - negative: recommend deload/technique

#### Weekly Summary

- sessions completed = count workouts or exercise sessions depending on grouping availability
- time = sum workout duration; if missing, estimate from set data
- PRs = count personal records detected in period
- streak = profile streak or analytics-computed streak

#### Score Trend

- For week: 7 daily buckets, fill missing days with previous value or omit. The chart expects a list of ints.
- For month: weekly or session buckets.
- For program: one point per week or session.

#### Body Heat Map

Start with a canonical map:

```dart
const exerciseToRegion = {
  'squat': 'legs',
  'squat_bw': 'legs',
  'lunge': 'legs',
  'glute_bridge': 'glutes',
  'glute_bridge_bw': 'glutes',
  'push_up': 'shoulders',
  'wall_pushup': 'shoulders',
  'plank': 'core',
  'mcgill_curl_up': 'core',
  'curl_up': 'core',
};
```

Score each region:

```text
region_delta = avg_recent_form - avg_baseline_form
```

Intensity:

- `strong`: delta >= 12
- `medium`: delta >= 6
- `mild`: delta > 0
- hidden or neutral if <= 0

#### Ranked Insights

For each exercise:

1. Need at least 2 sessions.
2. Compute form delta.
3. Compute volume delta.
4. Compute fault reduction for key faults.
5. Score:

```text
score = form_delta * sqrt(session_count) + volume_delta_bonus + fault_reduction_bonus - recency_penalty
```

6. Pick top 3-5.

#### Personal Records

MVP records:

- highest `total_reps`
- highest `total_good_reps`
- best `form_score`
- longest hold if `set_data.actual_seconds` exists
- lowest fault count for an exercise

### How To Implement

1. Create `ProgressSummaryService.load(period)`.
2. Move all `progressMock*` access behind snapshot loading.
3. Add empty state: "Chưa đủ buổi để vẽ tiến bộ."
4. Add tests for each algorithm.
5. Once stable, remove `progress_mock.dart` from production imports.

## Profile Spec

### Current Hardcoded Areas

- name, initial, member since
- phase/level
- goal title and quote
- lifetime stats
- achievements
- journey timeline
- body card
- referrals
- connected services
- settings actions

### Context

Profile is the user's account and identity. It should be accurate, boring in the best way, and never pretend a referral/service is connected when it is not.

### Proposed Data Contract

```dart
class ProfileSnapshot {
  final String name;
  final String initial;
  final String memberSinceLine;
  final String phaseLabel;
  final int goalProgress;
  final List<String> inlineStats;
  final String goalTitle;
  final String goalQuote;
  final String goalDaysLeft;
  final List<ProfileLifetimeStat> lifetimeStats;
  final String coachLine;
  final List<Achievement> achievements;
  final List<JourneyMilestone> journey;
  final int? heightCm;
  final int? weightKg;
  final int? age;
  final String bmi;
  final String bmiCategory;
  final int referralCount;
  final List<ConnectedService> connections;
  final String appVersion;
}
```

### Data Sources

- `profiles`
- `auth.currentUser.userMetadata`
- `exercise_sessions` / `workout_sessions`
- `recommendations_log`
- local app metadata
- future tables: referrals, integrations, notification preferences

### Algorithms

#### Identity

Name priority:

1. `profiles.full_name` if added
2. `auth.user.userMetadata['full_name']`
3. email prefix
4. "Bạn"

Initial = first visible character of name.

#### Member Since

Use `auth.currentUser.createdAt` if available. If using `profiles.created_at`, parse as text defensively.

#### Goal

Title templates:

- `health` -> "Khoẻ đều, bền lâu"
- `body` -> "Gọn hơn, chắc hơn"
- `strength` -> "Mạnh hơn từng tuần"
- `flexible` -> "Linh hoạt mỗi ngày"

Quote:

- Add `why_primary` / problem resonance from profile.
- If absent, use neutral copy.

#### Lifetime Stats

From sessions:

- completed workouts or exercise rows
- total time
- average form
- best streak

#### BMI

From `profiles.height_cm`, `profiles.weight_kg`.

Formula:

```text
bmi = kg / (meters * meters)
```

Category:

- < 18.5: "Thiếu cân"
- 18.5-24.9: "Cân đối"
- 25-29.9: "Hơi cao"
- >= 30: "Cần chú ý"

#### Achievements

Make achievements deterministic:

- first session
- 7-day streak
- 14-day streak
- form >= 70
- form >= 80
- 10 sessions
- 30 sessions
- first PR
- phase completed

#### Journey Timeline

Build from events:

- joined
- first completed workout
- streak milestones
- PR events
- form milestones
- today

### How To Implement

1. Create `ProfileSummaryService.load()`.
2. Add missing profile field support to `UserProgramService` or make a new `UserProfileService`.
3. Replace `profileMock*` in `ProfileScreen` with snapshot.
4. Wire settings:
   - reminders -> notification preference screen
   - coach voice -> voice preference screen
   - privacy -> static privacy explanation route
   - download data -> export JSON/CSV from Supabase rows
   - help -> support route/link
   - about -> version/license route
   - sign out -> `AuthService().signOut()` or expose a public sign-out wrapper
5. Tests:
   - BMI
   - achievements
   - journey events
   - missing profile data

## Exercise Runtime Spec

### Current Hardcoded Areas

- `_hardcodedFormScore = 82`
- `_hardcodedSparkData`
- `_hardcodedFaultIndices`
- Ivory chrome TODOs
- Executive summary best-rep landmark visuals
- Intro adaptation text still default, not real recommendation-log deltas

### Context

The camera screen needs live telemetry, not decorative telemetry. If form score says 82, it must come from the current exercise/set.

### Proposed Data Contract

Create a `LiveExerciseTelemetry` object owned by `ActiveExercisePage`:

```dart
class LiveExerciseTelemetry {
  final int currentFormScore;
  final List<int> sparkline;
  final List<int> faultRepIndices;
  final String? caption;
  final Map<String, String> liveFeedback;
}
```

### How To Compute

#### Current Form Score

MVP:

```text
good reps / total reps * 100
```

If no completed reps yet, show neutral "AI" state instead of a fake score.

Better:

```text
score = weighted average of metric statuses over rolling frames
```

#### Sparkline

Use one of:

- per-rep form score
- primary metric angle normalized to 0-100
- rolling average form score

For first implementation, use per-rep score:

```dart
sparkline = logger.repLogs.map((rep) => rep.correctForm ? 100 : 45).toList();
```

Then improve per exercise.

#### Fault Indices

Map rep logs:

```dart
faultIndices = logger.repLogs
  .where((rep) => !rep.correctForm)
  .map((rep) => rep.repNumber)
  .toList();
```

#### Caption

Take the highest-priority current `resultIssues.feedback` or most recent instruction. Debounce it so text does not flicker every frame.

#### Best Rep Visuals

Need captured landmarks. Add optional best-rep snapshot:

```dart
class BestRepSnapshot {
  final int repNumber;
  final int formScore;
  final Map<String, dynamic> landmarks;
  final Map<String, dynamic> metrics;
}
```

Store in `set_data` or a future `rep_data` JSONB payload.

### Intro Adaptation Logic

Current intro adaptation defaults should come from history:

1. Fetch latest session for exercise.
2. Read `fault_counts`, `difficulty_ratings`, and `set_data`.
3. For each metric:
   - if fault count high -> loosen or focus coaching
   - if no faults for 3+ sessions -> tighten
   - if first session -> baseline
4. Display actual previous value if available.

Do not invent "failed 3 times" unless the data says it.

### Tests

- no reps yet
- all good reps
- mixed reps
- fault index mapping
- intro adaptation first session
- intro adaptation repeated fault
- intro adaptation streak success

## Onboarding Spec

### Current Hardcoded Areas

- `homeResultsMock`
- `yogaResultsMock`
- hardcoded issue candidates and coach body
- Wall Push-Up / Warrior I / Forward Fold interpreter TODOs
- hand-coded personalization logic

### Context

Onboarding is where Vika earns trust. It can use templates, but the templates must be selected from actual assessment results and profile data.

### Proposed Approach

Keep a rules engine first. Do not jump straight to LLM.

Create:

```text
lib/services/onboarding_assessment/
  assessment_result_service.dart
  issue_candidate_service.dart
  onboarding_outcome_service.dart
```

### Data Sources

- `OnboardingData`
- squat interpreter result
- future push-up/yoga/fold interpreters
- `interpretingMap`
- `user_pain_areas`
- `user_detected_issues`

### How To Implement

1. Define a normalized `AssessmentSignal`:

```dart
class AssessmentSignal {
  final String exerciseId;
  final String metricId;
  final double value;
  final MetricStatus status;
  final String? issueId;
  final double confidence;
}
```

2. Each interpreter outputs signals.
3. `IssueCandidateService` maps signals to issue candidates through `interpretingMap`.
4. `OnboardingOutcomeService` creates result cards:
   - detected pattern
   - coach body
   - chart
   - candidates
5. Replace `homeResultsMock` and `yogaResultsMock` with service output.
6. Add missing interpreters one at a time:
   - Wall Push-Up
   - Warrior I
   - Forward Fold
7. Persist every confirmed issue through `IssuesService` / `OnboardingPersistence`.

### Tests

- no assessment data -> gentle fallback
- squat ankle issue -> ankle mobility candidate
- push-up shoulder asymmetry -> shoulder candidate
- no issues -> positive result
- conflicting self-report/camera issue -> self-report wins in copy, camera stays as evidence

## Supabase Config Spec

### Current Hardcoded Area

`lib/main.dart` hardcodes Supabase URL and anon key.

### Context

Anon keys are not secrets in the same way service-role keys are, but hardcoding environment config makes staging/production separation fragile.

### Proposed Approach

Use `--dart-define`:

```dart
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
```

Then:

```bash
flutter run \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

For CI/build:

```bash
flutter build ios --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

### Tests

- app throws clear error in debug if missing config
- staging build points to staging
- production build points to production

## Implementation Order

Do this in this order. It minimizes rework.

1. Add `SessionAnalyticsService` and typed `ExerciseSessionRow`.
2. Add workout grouping (`workout_sessions` or exercise session grouping fields).
3. Wire Plan completion/form and full workout sequencing.
4. Wire Home snapshot from active plan + analytics.
5. Wire Progress snapshot from analytics.
6. Wire Profile snapshot from profile + analytics.
7. Wire Library generated exercise catalog, counts, search, and detail routes.
8. Wire Exercise runtime chrome telemetry.
9. Replace intro adaptation defaults with history-backed logic.
10. Refactor Onboarding result mocks into assessment services.
11. Move Supabase config to dart-define.
12. Delete or quarantine unused legacy mock/orphan screens.

## Teaching Walkthrough: How To Build One Screen

Use Home as the pattern.

### Step 1: Make A Snapshot

Create the model first. Do not touch UI yet.

```dart
class HomeDashboardSnapshot {
  const HomeDashboardSnapshot({...});
}
```

### Step 2: Make A Service

```dart
class HomeDashboardService {
  HomeDashboardService({
    RecommendationService? recommendations,
    SessionAnalyticsService? analytics,
    SupabaseClient? client,
  });

  Future<HomeDashboardSnapshot> load() async {}
}
```

### Step 3: Write Tests Against Fake Inputs

Before Supabase integration, test the mapper:

```dart
test('uses next scheduled session when today is rest day', () {});
test('counts AI exercises from local definitions', () {});
test('builds form delta from 7-day trend', () {});
```

### Step 4: Replace Widget Data Source

Convert:

```dart
HomeStageHero(eyebrow: homeMockToday.eyebrow)
```

to:

```dart
HomeStageHero(eyebrow: snapshot.eyebrow)
```

### Step 5: Keep The Visual Contract

Do not redesign while wiring. The task is data correctness. If the snapshot fits the old widget props, the screen should barely change visually.

## Empty And Error States

Every screen needs these:

- Loading: skeleton or quiet centered copy.
- Empty:
  - Home: "Chưa có buổi hôm nay" with CTA to Plan/Library.
  - Plan: existing retry state.
  - Progress: "Cần thêm 2 buổi để vẽ tiến bộ."
  - Profile: show identity and editable body info; hide achievements needing sessions.
  - Library: show catalog even if curated content fails.
- Error:
  - Log debug.
  - Show retry button.
  - Never silently fall back to fake mock values in production.

## Production Readiness Checklist

Before deploy:

- `flutter analyze`
- `flutter test`
- No production import from `home_mock.dart`, `progress_mock.dart`, `profile_mock.dart`, `plan_mock.dart` except in tests/dev previews.
- Supabase config comes from dart-define.
- RLS policies exist for any new table.
- Home CTA starts full workout sequence.
- Plan shows real completion.
- Progress shows empty state for new users.
- Profile sign-out works.
- Exercise chrome does not show fake form score before first rep.
- Onboarding can complete even if non-critical side writes fail.

## A Note On Scope

Not every content item needs to be dynamic on day one. Curated library content can stay static if it is intentionally editorial. But user-specific stats, progress, scores, streaks, body metrics, exercise telemetry, and plan state must be real. That is the line.

