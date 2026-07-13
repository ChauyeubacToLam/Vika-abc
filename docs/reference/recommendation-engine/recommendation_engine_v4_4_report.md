# Recommendation Engine v4.4 Implementation Report

## Summary

v4.4 is now implemented as a real recommendation core rather than a concept-only model layer. The engine can generate a templated multi-week plan, prescribe week-by-week volume, apply session carry-over, attach weekly check-ins and an end-of-plan retest, and persist progression state for per-exercise variant unlocks.

The existing filter/score/sample/MMR pieces were only partially present in the repo. I kept the existing scoring and sampler, added the missing template registry and engine orchestrator, and made Stage 5 (`progression_rules.dart`) the stable pure-math spine.

The onboarding journey and Plan tab are now wired to the same Supabase-backed plan path: after signup/login, onboarding persists the collected profile inputs, generates the v4.4 plan, inserts it into `recommendations_log`, and S15 renders the saved plan instead of the old editorial placeholder.

## Architectural Decisions

### Pure Engine Plus Supabase Shell

The core engine is pure:

- `RecommendationEngine.generatePlan()` takes explicit request data and returns a `RecommendationResult`.
- `progression_rules.dart` is pure and unit-tested.
- Supabase reads/writes live in service wrappers (`RecommendationService`, `RecommendationProgressionService`, `WeeklyCheckInService`, `FitnessRetestService`).

Reason: this keeps prescription math testable without Supabase auth or network state.

### Plan Bootstrap

`RecommendationService.ensurePlanForCurrentUser()` is the single app-facing entry point for "make sure this user has a usable plan." It first fetches the latest active `recommendations_log` row ordered by `generated_at`; if none exists, it generates and inserts one.

This is called from:

- S13 signup, immediately after auth completes.
- S15 journey screen, so the onboarding plan preview can retry if generation failed.
- S16 completion, before routing to home.
- App entry for already-onboarded signed-in users.

The signup-time profile write uses `onboarding_complete = false` so users do not skip the remaining onboarding screens if the app closes mid-flow. S16 flips the profile to complete.

### Plan Shape

`plan_structure` remains backward-compatible:

- New rows include `schema_version: "4.4"`.
- Older rows missing `schema_version`, `phase_number`, `is_deload_week`, or slot-level `volume` still deserialize.
- Slot-level volume is now the canonical v4.4 shape.

Additions:

- `weekly_check_in_weeks`: default weeks 2..last week.
- `end_retest`: forced post-deload retest metadata.
- `session_type`: currently `workout`, reserved for future expansion.

### Volume Modality (P1, 2026-07-12)

The catalog now has two legal shapes:

- Rep-based: `base_reps` is set and `base_seconds` is null.
- Hybrid hold: both are set. Reps is the structural hold count; seconds is the per-hold duration.

`base_seconds != null` is the hold discriminator. Hybrid prescriptions carry both fields, but only
seconds progress through tier start, cap interpolation, deload, carry-over, and variant unlock.
Hold count passes through unchanged. During the SQL rollout, a legacy seconds row with null reps is
tolerated as one hold and logged; rows with both fields null still fail loudly.

### Template Registry

Added the 8 launch templates in `templates.dart`:

- `home_health`, `home_body`, `home_strength`, `home_flexible`
- `yoga_health`, `yoga_body`, `yoga_strength`, `yoga_flexible`

All default to 2 phases x 3 weeks + 1 deload week. Phase labels are Vietnamese: `Nền tảng`, `Phát triển`, `Phục hồi`.

### Progression Curve

I used linear interpolation from start target to tier cap across all progression weeks:

```text
t = (week - 1) / (progressionWeeks - 1)
target = ceil(start + (cap - start) * t)
target = clamp(target, start, cap)
```

Why this instead of `+1/week`:

- 4-week plans still move enough to feel like progress.
- 7-week plans reach normal caps cleanly.
- 12-week plans plateau at cap instead of overshooting into unsafe targets.

Set ramp:

- First ~20% of progression weeks are acclimation at 2 sets, capped to 2 weeks.
- Remaining progression weeks use 3 sets.
- Deload uses 2 sets.

Deload:

- Deload target is 75% of the final progression-week target.
- Carry-over is intentionally ignored during deload.

### Carry-Over

Carry-over reads the most recent non-deload session per exercise and applies it as a floor:

- Reps/seconds: `max(planned, lastActual)`, capped at the user tier cap.
- Hybrids apply that floor only to seconds and preserve the catalog hold count.
- Recent `exercise_sessions.set_data` outranks `user_exercise_capacity` when both exist because the
  current capacity schema caches reps but not seconds; capacity remains the older-session fallback.
- Rest: can drop to the last applied rest only if the session was not hard.
- Hard sessions keep planned rest.
- Deload sessions never carry forward.

Important disagreement: I did not allow carry-over to exceed the tier cap. If a beginner cap is 10 and the user did 12 through in-session autoregulation, the next planned target stays 10 and the variant unlock machinery gets the signal. Exceeding the cap would turn a safety ceiling into a suggestion.

### Variant Unlock

Added `user_exercise_capacity`.

Unlock condition:

- Exercise has `progression_to`.
- Most recent session is non-deload.
- Final actual reps/seconds hit the tier cap.
- All answered set difficulty ratings are easy.
- This happens for 3 qualifying sessions.

I chose 3 sessions because 1 is noisy, 2 can still be a good day, and 4+ is likely too slow for a motivational unlock loop during a 7-week plan.

The unlock affects the next plan generation only.

### Session Data

Exercise sessions now write v4.4 metadata into `set_data`:

- `recommendation_id`
- `week_number`
- `is_deload_week`
- `prescribed_reps`
- `actual_reps`
- `prescribed_rest`
- `applied_rest`

Difficulty ratings written to `exercise_sessions.difficulty_ratings` are normalized:

- UI `light` -> engine `easy`
- UI `heavy` -> engine `hard`
- UI `medium` -> engine `ok`

The existing UI labels were not renamed, to avoid widening the UI change.

## Data Model Changes

Migration: `supabase/migrations/20260518_recommendation_v44.sql`

Production schema reference: `docs/reference/supabase-schema/supabase_schema_reference_v4_4.md`

Forward policy fix: `supabase/migrations/202605181630_recommendations_log_client_generation_policy.sql`

Added:

- `user_exercise_capacity`
- `weekly_checkins`
- `fitness_retests`

Altered:

- `recommendations_log.generated_at`
- `recommendations_log.superseded_at`
- `recommendations_log.plan_started_at`
- `recommendations_log.plan_completed_at`

All tables follow own-row SELECT/INSERT/UPDATE RLS. No DELETE policies were added.

`recommendations_log` now has own-row INSERT because generation currently happens in the Flutter client. If plan generation moves server-side later, this can be tightened back to service-role-only insertion.

## Edge Cases Handled

- Existing legacy plan JSON still deserializes.
- Hybrid rows with both reps and seconds generate without a modality error.
- Empty slot muscle match relaxes to body-region match, then minimum safety fallback.
- Pain contraindications are never relaxed.
- Deload sessions do not update carry-over.
- Hard sessions do not reduce rest.
- Repeated exercise in the same week uses the most recent completed non-deload session.
- Carry-over regressed reps do not lower the planned target.
- Missing progression caps fall back to conservative values: beginner/intermediate/advanced reps 10/12/15.

## Things I Disagreed With

### Carry-over Above Cap

I disagree with prescribing above the tier cap. It conflicts with the safety role of cap columns. The code caps carry-over and uses cap hits as unlock evidence.

### Weekly Target Increases

The requirement "every week is higher or at cap" is mathematically incompatible with long plans and low beginner caps unless we intentionally hit the cap very early. I chose interpolation, so long plans can have repeat targets before the cap. The invariant is non-decreasing and never above cap, not strictly increasing.

### "Same Retest as Onboarding"

The brief says retest is the same as onboarding: 60-second squat + 60-second wall push-up. The current onboarding code has 5-rep assessment definitions and form-score thresholds, not a 60-second retest flow. I implemented retest logging and suggestion service, but the actual timed camera UX needs product/design/pose work.

### Variant Unlock Is Worth Keeping

I do not think tier-only is enough. The unlock condition is strict but reachable: cap hit + easy ratings across 3 sessions. If it never fires in test data, loosen the rating requirement before deleting the mechanism.

## Files To Read

1. `lib/services/recommendation/recommendation_engine.dart`
2. `lib/services/recommendation/progression_rules.dart`
3. `lib/services/recommendation/templates.dart`
4. `lib/services/recommendation/progression_service.dart`
5. `lib/services/recommendation/recommendation_service.dart`
6. `lib/services/recommendation/models/plan.dart`
7. `lib/services/recommendation/models/template.dart`
8. `lib/services/recommendation/models/exercise_catalog_entry.dart`
9. `lib/services/recommendation/weekly_check_in_service.dart`
10. `lib/services/recommendation/fitness_retest_service.dart`
11. `lib/screens/exercise/exercise_experience_screen.dart`
12. `lib/screens/plan_screen.dart`
13. `lib/screens/onboarding/v5/screens/s15_journey.dart`
14. `supabase/migrations/20260518_recommendation_v44.sql`
15. `supabase/migrations/202605181630_recommendations_log_client_generation_policy.sql`

## Things Not Done

- Full 60-second retest camera flow: current exercise definitions are 5-rep assessments.
- P1 data rollout: Nam still needs to apply the approved `base_reps = 1` SQL for the four legacy
  seconds rows, then run the catalog generator and commit the regenerated JSON.
- Remote migration execution: SQL is added locally but not applied to Supabase from this workspace.
- ML/autoregulation use of weekly check-ins: v4.4 logs only, per brief.
- Server-side plan generation: the app currently inserts its own `recommendations_log` row under own-row RLS. This unblocks end-to-end testing now; a server function would be cleaner for production control.

## Test Plan

Added targeted tests:

- `test/services/recommendation/progression_rules_test.dart`
  - 7-week interpolation and deload
  - 12-week monotonic cap behavior
  - carry-over floor capped at tier cap
  - hard carry-over does not reduce rest
  - variant unlock qualification
  - hybrid seconds progression, deload, carry-over, hold-count passthrough, null-reps tolerance,
    malformed-row failure, and seconds-cap variant unlock

- `test/services/hybrid_volume_labels_test.dart`
  - count-aware hybrid labels on catalog and workout surfaces
  - direct catalog launch retains both hybrid targets

- `test/services/recommendation/recommendation_engine_test.dart`
  - full 7-week plan generation
  - deload/check-in/retest metadata
  - exercise stability across weeks
  - legacy plan JSON deserialization

Verification:

- `flutter analyze`: clean.
- Focused recommendation/catalog/launch suite: 44 passed.
- Full `flutter test`: 467 passed / 6 failed. All six failures are the pre-existing 12px
  `workout_summary_screen_test.dart` RenderFlex overflow cluster.

Known unrelated verification blockers:

- The six `workout_summary_screen_test.dart` overflow failures remain unrelated to P1.

## Open Questions

- Confirm the 60-second retest thresholds. I used conservative placeholder thresholds: intermediate at 14 squat / 10 wall push-up, advanced at 22 / 16.
- Confirm whether plan sessions should be identical every workout or whether each weekly session should have a different exercise mix. I chose identical exercises across the plan for beginner clarity.
- Confirm whether cap columns should be treated as hard safety ceilings. The implementation does.
- Confirm whether the existing in-session `light -> +2 reps` rule should stay. I left it in place and capped cross-session carry-over, but +2 may be aggressive for camera-gated beginners.
- Confirm whether Vietnamese UI should rename `Nhẹ/Vừa/Nặng` to the brief's `easy/hard` pair or keep the richer existing labels and normalize internally.
- Confirm whether client-side recommendation insertion is acceptable for the pilot, or whether we should move `RecommendationService.generatePlanForCurrentUser()` behind a Supabase Edge Function before launch.
