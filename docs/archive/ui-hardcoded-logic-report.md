# UI Hardcoded Logic Report

Date: 2026-05-23

## Cleaned Up In This Pass

- `lib/screens/exercise/exercise_experience_screen.dart`
  - Replaced generic intro specs for Lunge, Push Up, Plank, Jumping Jack, Glute Bridge, and McGill Curl-up with exercise-specific AI metric thresholds sourced from their metric config classes.
  - Added target labels / estimated work duration per exercise type so Plank no longer reads like normal reps.
- `lib/screens/exercise/exercise_intro_page.dart`
  - Kept the shared Squat-style intro structure for every exercise: stage hero, setup checklist, AI metric spec, session target band, sticky CTA.
  - Made the AI section copy metric-count safe instead of saying "five points" for every exercise.
- `lib/screens/dashboard_home_screen.dart`
  - Home CTA now launches the first launchable exercise from the assigned `UserProgramData` before falling back to Squat.
- `lib/screens/library_screen.dart`
  - Library hero total count now derives from library data lists instead of the hardcoded `100`.
- `lib/screens/library_browse_screen.dart`
  - Added bottom safe-area spacing on the pushed browse route.

## Still Hardcoded / Needs Real Wiring

### App Configuration

- `lib/main.dart:40-42`
  - Supabase URL and anon key are hardcoded in app source.
  - Move these into platform env/config before production release.

### Home Tab

- `lib/screens/dashboard_home_screen.dart:65-67`
  - Comment correctly notes remaining dashboard mock wiring.
- `lib/screens/dashboard_home_screen.dart:137-164`
  - Hero copy, session count, AI count, exercise list, coach quote, vitals, streak, form score, and 7-day chart still render from `homeMock*`.
- `lib/data/home_mock.dart:39-77`
  - Home user, today session, week label, streak, form values, chart, and quote are mock constants.

### Plan Tab

- `lib/screens/plan_screen.dart:245`
  - Plan hero user initial is hardcoded as `'N'`.
- `lib/screens/plan_screen.dart:397-407`
  - Completed-week form score, recap, best-day copy, coach line, and chapter line are generated from static text or fixed values.
- `lib/screens/plan_screen.dart:499`
  - Per-exercise form value is fixed at `78`.
- `lib/data/plan_mock.dart:136`
  - `phaseWeeksMock` remains as legacy/mock plan data and is still used by Progress.

### Library

- `lib/screens/library_screen.dart:103`
  - Cards without `exerciseName` log a stubbed tap instead of opening real program/collection detail screens.
- `lib/screens/library_screen.dart:226`
  - Library hero user initial is hardcoded as `'N'`.
- `lib/screens/library_browse_screen.dart:486`
  - Browse search button is still a phase-6 placeholder.
- `lib/screens/exercise_browser.dart:114,174,244`
  - Legacy exercise browser still has stubbed card taps, hardcoded `100`, and a stubbed AI hero. MainShell no longer uses it, but remove or update before exposing it again.

### Progress Tab

- `lib/screens/progress_screen.dart:105-110`
  - Headline, weekly summaries, score trend, axis labels, and phase progress still come from `progressMock*` / `phaseWeeksMock`.
- `lib/screens/progress_screen.dart:131`
  - Progress hero user initial is hardcoded as `'N'`.
- `lib/screens/progress_screen.dart:170-226`
  - Body heat map, ranked insights, PRs, streak, bars, and milestone are mock-backed.
- `lib/data/progress_mock.dart:25-340`
  - All Progress metrics are mock constants.

### Profile Tab

- `lib/screens/profile_screen.dart:82-298`
  - Profile name, initial, member-since line, phase, inline stats, goal, lifetime stats, achievements, body metrics, referrals, connected services, and version are all `profileMock*`.
- `lib/screens/profile_screen.dart:227-277`
  - Reminder schedule and every settings row action are hardcoded / empty callbacks.
- `lib/data/profile_mock.dart:11-261`
  - All displayed profile content is mock data.

### Exercise Runtime

- `lib/screens/exercise/active_exercise_page.dart:93-109`
  - Active camera UI form score, sparkline data, and fault indices are hardcoded.
- `lib/screens/exercise/active_exercise_page.dart:1600-1708`
  - Those hardcoded form score / sparkline / fault indices are still passed into the Ivory chrome.
- `lib/screens/exercise/widgets/ivory_chrome.dart:144,252,445`
  - Form-score color, real score, and fault-index wiring are TODOs.
- `lib/screens/exercise/executive_summary_page.dart:1905,1921`
  - Best-rep landmark visuals are still TODO placeholders.
- `lib/screens/exercise/exercise_intro_page.dart:189-210`
  - Intro threshold adaptation stories are still default copy, not real recommendation-log deltas.

### Onboarding

- `lib/screens/onboarding/v5/v5_models.dart:282-288`
  - Phase 1 issue candidate generation and coach text still use hardcoded NASM-style mappings.
- `lib/screens/onboarding/v5/v5_models.dart:288-472`
  - Home/yoga assessment result mocks and fallback derivation remain.
- `lib/screens/onboarding/v5/v5_models.dart:320,349,375`
  - Wall Push-Up, Warrior I, and Forward Fold interpreters are still TODOs.
- `lib/screens/onboarding/v5/v5_models.dart:502`
  - Signup/outcomes personalization is still hand-coded if/else logic.
