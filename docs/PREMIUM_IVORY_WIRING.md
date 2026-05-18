# Premium Ivory v1 — Wiring Report

The four main tabs and the Library sheet are now visually complete in the
Premium Ivory v1 design, all running on mock data. This document maps
every screen back to the real logic that still needs to be wired in, with
file pointers.

The shape this whole UI was built against:

- `lib/data/plan_mock.dart`     — `PlanWeek`, `PlanDay`, `PlanExercise`
- `lib/data/home_mock.dart`     — greeting, hero days, streak, journal
- `lib/data/progress_mock.dart` — period headlines, body areas, insights, streak
- `lib/data/profile_mock.dart`  — identity, lifetime stats, body card
- `lib/data/library_mock.dart`  — programs, intent collections, all-exercises rows

**Convention.** Each screen still accepts the legacy parameters it had
before (`program`, `bottomPadding`, etc.) so MainShell keeps compiling. The
parameters are currently unused. Wiring = "stop using mock, start using
the parameter / call the service".

---

## 1. Plan tab — `lib/screens/plan_screen.dart`

Currently runs entirely on `phaseWeeksMock`. The screen already accepts
`program: UserProgramData?` from MainShell.

**To wire:**

| What | Where | Notes |
|---|---|---|
| 4-week plan from real assigned program | `_PlanScreenState.build` | Map `widget.program` (built by `UserProgramService.buildProgram`) to a `List<PlanWeek>`. Need a converter — `UserProgramData.workouts` is one week, no concept of phases. Either extend `UserProgramService` to return 4 weeks (Phase 1 / 2 / 3 / 4), or keep mock for the "phase" framing and only use program data for per-day workout details. |
| Per-day form scores + coach lines | `PlanWeek.days[].form / .coach` | Pull from sessions table once it exists. Currently nothing is logged at session-level. New service: `SessionLogger.weeklyDigest(weekNum)`. |
| "Bắt đầu Buổi NN" CTA | `today_card.dart` `onStart` | Currently `debugPrint`. Replace with `Navigator.pushNamed('/exercise', arguments: definition)` after looking up the first non-rest exercise via `lookupExerciseDefinition()`. |
| Streak bar accent on rail | `done_timeline.dart` left rail | Hardcoded full-yellow trace. Should reflect actual completion ratio of week's workouts. |

---

## 2. Home tab — `lib/screens/dashboard_home_screen.dart`

Runs on `homeMock*` constants. Accepts `program` from MainShell, ignored.

**To wire:**

| What | Where | Notes |
|---|---|---|
| User name + initial | `homeMockUser.name` / `.initial` | From `widget.program?.userName`, fallback "Bạn". Initial is `userName[0]`. |
| Day label / session label | `homeMockUser.dayLabel` / `.sessionLabel` | Use `DateTime.now()` + a Vietnamese weekday formatter (already exists in `plan_screen.dart`'s old `_weekdayLong`). Session number = today's index in `program.workoutDays`. |
| Hero day card content | `homeMockHeroDays` | Needs to come from "today's planned workout" + "tomorrow's planned workout". Use `UserProgramService.buildProgram` output or a future `TodayService.todayAndNext()`. |
| Streak ring days + week dots | `homeMockStreakDays` / `homeMockWeekDots` | Both come from `SessionLogger` — count of consecutive days with at least one completed session, plus a 7-bool array for the current week. Service doesn't exist yet. |
| Form 7-day chart | `homeMockFormToday`, `homeMockFormDelta`, `homeMockFormWeek` | Same source — last 7 days of avg form per session. Today's % is the latest; delta is today vs same-day-last-week. |
| Journal quote | `homeMockJournalQuote` | Stored during onboarding. Persist to SharedPreferences under e.g. `onboarding.goal_quote` and read here. |
| "Bắt đầu" CTA on hero card | `_HeroDayRail.onCta` callback | Same as Plan — push `/exercise` with the first exercise in today's workout. |
| "Khám phá thêm" tap | `BrowseShortcut(onTap: widget.onOpenBrowser)` | Already wired correctly through MainShell. |

---

## 3. Progress tab — `lib/screens/progress_screen.dart`

Runs on `progressMock*`. Period state is local; no real data yet.

**To wire:**

| What | Where | Notes |
|---|---|---|
| Headline metric per period | `progressMockHeadline['week' / 'month' / 'program']` | Aggregate avg form score over each period. Needs `SessionLogger.formStats(period)` returning `{from, to, delta, label, coach}`. The coach line is generated text — start with templates, eventually LLM. |
| Body area deltas | `progressMockBodyAreas` | The 4 areas (Chân / Mông / Ngực & Vai / Cốt lõi) need a region-scoring algorithm. The painter file `body_heat_map.dart` documents the MVP: anchor exercises map 1:1 to a region (Squat→legs, Glute Bridge→glutes, Wall Push-up→shoulders, Plank→core). Algorithm is in `lib/widgets/progress/body_heat_map.dart` doc comments — implement in Dart against the sessions table. |
| Body silhouette gender | `BodyHeatMap(gender: BodyGender.male)` in `progress_screen.dart` | Hardcoded male. Pull from `UserProgramService` once a `gender` field exists on the user profile (currently doesn't). |
| Ranked exercise insights | `progressMockInsights` | The algorithm is documented inline in `vika-main-app-ivory-v1.jsx` and copied to `RankedInsights` doc comments. Needs `delta * sqrt(frequency) / freshness_penalty` over filtered AI-camera exercises. Implement as `SessionLogger.rankedInsights(period)`. |
| Streak card 14-day bars | `progressMockStreakBars` | Same source as Home streak — `SessionLogger.last14DaysCompletion()`. |

---

## 4. Profile tab — `lib/screens/profile_screen.dart`

Runs on `profileMock*`. No connection to real auth or program yet.

**To wire:**

| What | Where | Notes |
|---|---|---|
| User name + initial | `profileMockName` / `profileMockInitial` | From `AuthService` (Supabase user profile). Currently hardcoded to "Nam Trần". |
| Member-since date | `profileMockMemberSince` | Supabase `user.created_at`, formatted DD/M/YYYY. |
| Level + phase | `profileMockLevel` / `profileMockPhase` | From `UserProgramService` (level), and the active phase number. |
| Goal title + quote | `profileMockGoalTitle` / `profileMockGoalQuote` | Persisted during onboarding (SharedPreferences). |
| Coach line | `profileMockCoachLine` | Generated text. Start with templates over the lifetime stats trio. |
| Lifetime stats trio | `profileMockLifetimeStats` | `SessionLogger.lifetimeStats()` returning sessions count, total hours, avg form %. |
| Height / weight / age / BMI | `profileMockHeight`, etc. | Persisted in onboarding. Currently no model field exists; add to `UserProgramData` or a new `UserProfile` model. |
| Settings tap handlers | `SettingRow.onTap` × 6 in `profile_screen.dart` | All currently `() {}`. Each needs its own destination: notif prefs, voice prefs, privacy info, invite flow, help URL, sign-out. |
| Sign-out | The danger SettingRow at the bottom | Wire to `AuthService.signOut()` then `Navigator.pushReplacementNamed('/login')`. |

---

## 5. Library sheet — `lib/screens/exercise_browser.dart`

Runs on `libraryMock*` data. Two callbacks come in (`onClose`,
`onSelectExercise`); only `onClose` is wired through. The
`onSelectExercise(ExerciseDefinition)` callback exists on the constructor
to keep MainShell compiling but isn't called from any of the new widgets.

**To wire:**

| What | Where | Notes |
|---|---|---|
| Programs rail | `libraryMockPrograms` | Build from a `ProgramRegistry` service (doesn't exist). For now, the four shown are static — they'd be hand-curated by a content team anyway. The "Đang chạy" tag should attach to whichever program matches `UserProgramService.loadAssignedProgram()`. |
| Intent collections | `libraryMockCollections` | Hand-curated content. Static data is fine; consider moving to a JSON asset under `assets/library/` once the list grows past 10. |
| All exercises grid | `libraryMockAllExercises` | Currently 8 mock entries. Real list = `exerciseDefinitions` from `models/exercise_lookup.dart`. The new mock has fields `glyph`, `cat`, `diff`, `ai`, `yoga` that don't exist on `ExerciseDefinition` — extend the model or build a converter. |
| Filter chips | `libraryMockFilters` (constant, hardcoded) + `_filter` state in `_AllExercisesGridState` | The state changes but doesn't filter the list. Apply filter to row list before rendering. |
| Search bar | `SheetSearch` is a static widget | Currently displays placeholder text. Wire to a `TextEditingController` + filter by name (case-insensitive, accent-folded for Vietnamese). |
| Tap on an exercise row → start | `_ExerciseRow` in `all_exercises_grid.dart` | Wrap the row's container in `InkWell(onTap: () => onSelect(definition))`. The `onSelectExercise` callback needs to be threaded down from `ExerciseBrowser` → `_SheetBody` → `AllExercisesGrid` → `_ExerciseRow`. |
| Hero card / small card taps | `_HeroCard` / `_SmallCard` in `intent_collection.dart` | Same — wrap in InkWell, fire the same `onSelect`. |
| AI spotlight CTA | `AISpotlight(onEnter: ...)` | Currently `debugPrint`. Should filter the all-exercises grid to AI=true and scroll to it, OR open a dedicated AI subtab. |

---

## 6. Foundation — what landed in shared theme / chrome

Reusable across all main-app screens and not tied to one tab:

- `lib/theme/vf_theme.dart` — added `VikaIvoryMain` color/typography class
- `lib/widgets/ivory/atoms.dart` — `PoseGlyph`, `AIDot`, `PillCTA`
- `lib/widgets/ivory/bottom_nav.dart` — `IvoryBottomNav`
- `lib/widgets/plan/plan_typography.dart` — `PlanEyebrow`, `PlanH1`, `PlanP`, `CoachMark` (named "Plan*" historically; functionally shared)
- `lib/widgets/plan/section_mark.dart` — `SectionMark`
- `lib/widgets/plan/wordmark_header.dart` — `WordmarkHeader`
- `lib/widgets/plan/editorial_closer.dart` — `EditorialCloser`
- `lib/widgets/plan/plan_painters.dart` — `CoachMarkPainter`, `FigureSkeletonPainter`, `BodyDiagramPainter`

**Future cleanup:** the `Plan*` naming on the typography / chrome is
historical. Once we're sure the design is locked, move these to
`lib/widgets/ivory/` and rename to `VikaEyebrow`, `VikaH1`, `VikaP`,
`VikaSectionMark`, etc. The plan-specific files (`week_*.dart`,
`day_timeline_row.dart`, `done_timeline.dart`, `today_card.dart`,
`recheck_card.dart`, `future_chapter_card.dart`, `week_recap_card.dart`)
stay where they are.

---

## 7. Outstanding issues / unknowns

- **Italic font fallback.** If `assets/fonts/PlusJakartaSans-*Italic.ttf` files
  aren't bundled, italic display headlines synthesise oblique. Watch for
  visual quality at first run.
- **MainShell no longer routes Hero CTA → /exercise.** All hero CTAs are
  currently stubbed `debugPrint`. The plumbing existed before (`Navigator.pushNamed('/exercise', arguments: definition)`); reintroduce per-screen as you wire each callback.
- **`UserProgramData.userName` is the user's name.** Used by Profile +
  Home greeting + Plan. No reactive state — if it changes mid-session
  the screens won't update. Wrap MainShell's `_program` in a
  `ValueListenable` or `Provider` if needed.
- **Body silhouette gender hardcoded to male.** Add a `gender` field to
  the user profile model and read from there in
  `progress_screen.dart` where `BodyHeatMap(gender: BodyGender.male)`
  is called.
- **No service-layer logging of completed sessions** (form scores, durations,
  coach text). The whole streak / heatmap / progress story depends on this.
  Building a `SessionLogger` is the highest-leverage next step — it unlocks
  Home's streak ring, Progress's headline + heatmap + insights + streak,
  and Profile's lifetime stats.
