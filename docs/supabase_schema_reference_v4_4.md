# Vika v4.4 Supabase Schema Reference

Project: `vinafit-prod` (`frjtlfzbvdgwgzegfzxh`)
Schema: `public`
Updated: 2026-05-24, from live table snapshot

This is the data-layer ground truth for recommendation v4.4 work. If code
or older reports disagree with this file, this file wins.

## Implementation Notes

- Active plan = latest `recommendations_log` row for the user where
  `plan_completed_at IS NULL`, ordered by `generated_at`.
- `profiles.schedule_sessions` is the user's real calendar schedule, e.g.
  `T2_afternoon`, `T4_afternoon`, `T6_afternoon`. UI calendar projections
  should use these weekday keys instead of guessing from session count.
- `exercise_sessions` is per exercise, not per workout. A multi-exercise
  workout creates multiple rows.
- `exercise_sessions` already has `recommendation_id` and `slot_name`, so
  per-exercise rows can be related back to a recommendation slot without a
  new workout-run table.
- `exercise_sessions` has no top-level `week_number` or `session_index`
  column. Week lives inside `set_data` JSONB. New app writes should also
  include `session_index` inside each set row so session completion can be
  counted exactly without a new table.
- `exercise_catalog.is_form_checked` is the real gate for AI form checking.
  Use it for real-vs-stub summary decisions instead of a hand-written list.
- `profiles.created_at` and `profiles.updated_at` are legacy `text`, not
  `timestamptz`; parsing code must handle this defensively.
- Engine difficulty labels are `easy` / `ok` / `hard`; UI labels are
  `light` / `medium` / `heavy`.

## Tables

### `profiles` (10 rows)

Primary key: `id`
Foreign key: `id -> auth.users.id`

- `id uuid`
- `display_name text null`
- `avatar_url text null`
- `fitness_level text null` in `beginner` / `intermediate` / `advanced`
- `goals text[] null`
- `onboarding_complete boolean default false`
- `subscription_status text default 'free'` in `free` / `pro` / `cancelled`
- `subscription_expires_at timestamptz null`
- `created_at text default now()`
- `updated_at text default now()`
- `streak int8 >= 0`
- `last_workout_at timestamptz null`
- `is_staff boolean`
- `gender text null` in `male` / `female`
- `height_cm numeric null` between 100 and 250
- `weight_kg numeric null` between 25 and 250
- `age integer null` between 16 and 100
- `training_duration text null` in `<6m` / `6m-2y` / `2y+`
- `fork text null` in `home` / `yoga`
- `schedule_sessions text[] null`
- `problem_resonance text[] default {}`

### `exercise_sessions` (7 rows)

Primary key: `id`
Foreign keys:

- `user_id -> profiles.id`
- `recommendation_id -> recommendations_log.id`

Columns:

- `id uuid`
- `user_id uuid`
- `exercise_id text`
- `started_at timestamptz`
- `completed_at timestamptz default now()`
- `form_score integer null`
- `total_reps integer null`
- `total_good_reps integer null`
- `total_sets integer null`
- `calories integer null`
- `fault_counts jsonb default {}`
- `difficulty_ratings text[] null`
- `set_data jsonb null`
- `created_at timestamptz`
- `issue_shown text null`
- `issue_response text null`
- `interpreter_output jsonb null`
- `device_fps int2 null`
- `app_version text null`
- `overall_difficulty text null` in `light` / `medium` / `heavy`
- `recommendation_id uuid null`
- `slot_name text null`

`set_data` stores per-set recommendation context, including `week_number`.

### `user_detected_issues` (2 rows)

Primary key: `id`
Foreign keys:

- `user_id -> profiles.id`
- `session_id -> exercise_sessions.id`

Columns:

- `id`
- `user_id`
- `session_id null`
- `exercise_id null`
- `issue_id null`
- `body_region`
- `source` in `self_reported` / `camera`
- `confidence float null`
- `priority integer default 99`
- `trigger_reason null`
- `trigger_rep_numbers int[] null`
- `trigger_metric_values jsonb null`
- `trigger_thresholds jsonb null`
- `cofire_context jsonb null`
- `interpreter_version null`
- `app_version null`
- `detected_at`
- `asked_at null`
- `expires_at null`
- `response null` in `yes` / `no`
- `reported_severity null` between 1 and 5
- `aggravated_by_exercise boolean null`
- `status default 'queued'` in `queued` / `asked` / `confirmed` / `declined` / `expired`

### `user_pain_areas` (13 rows)

Primary key: `id`
Foreign key: `user_id -> profiles.id`

- `id`
- `user_id`
- `body_region`
- `source` in `self_reported` / `confirmed`
- `status default 'active'` in `active` / `resolved` / `escalated`
- `first_flagged_at`
- `last_reaffirmed_at`
- `resolved_at null`
- `escalated_at null`
- `improvement_signal_count default 0`
- `reask_count default 0`
- `notes null`
- `flag_count default 1`

### `fork_decisions` (34 rows)

Primary key: `id`
Foreign key: `user_id -> profiles.id`

- `id`
- `user_id`
- `created_at`
- `fork_recommended` in `yoga` / `home`
- `raw_score numeric`
- `confidence numeric`
- `dominant_signal text`
- `reason_text text`
- `fork_chosen` in `yoga` / `home`
- `override boolean generated as chosen != recommended`
- `contribution_goal null`
- `contribution_pain null`
- `contribution_why null`
- `contribution_duration null`
- `algorithm_version default 'v1.0'`

### `exercise_catalog` (10 rows)

Primary key: `id`

- `id text`
- `vietnamese_name`
- `english_name`
- `fork` in `home` / `yoga` / `both`
- `body_regions text[]`
- `muscle_groups text[]`
- `difficulty_tier integer` between 1 and 3
- `goal_fit jsonb`
- `pain_safe text[]`
- `pain_contraindicated text[]`
- `is_form_checked boolean default false`
- `is_corrective boolean default false`
- `corrective_for text[]`
- `class_key null`
- `video_url null`
- `base_reps integer null`
- `base_seconds integer null`
- `progression_from text null` references `exercise_catalog.id`
- `progression_to text null` references `exercise_catalog.id`
- `metadata jsonb`
- `created_at`
- `updated_at`
- `max_reps_beginner integer null`
- `max_reps_intermediate integer null`
- `max_reps_advanced integer null`
- `max_seconds_beginner integer null`
- `max_seconds_intermediate integer null`
- `max_seconds_advanced integer null`

### `recommendations_log` (4 rows)

Primary key: `id`
Foreign key: `user_id -> profiles.id`

- `id`
- `user_id`
- `generated_at`
- `trigger` in `onboarding` / `reassessment` / `profile_change`
- `template_key text`
- `plan_structure jsonb`
- `algorithm_version text`
- `rng_seed text`
- `parameters jsonb`
- `user_snapshot jsonb`
- `superseded_at null`
- `plan_started_at null`
- `plan_completed_at null`

### `user_exercise_capacity` (0 rows)

Primary key: `(user_id, exercise_id)`
Foreign keys:

- `user_id -> profiles.id`
- `exercise_id -> exercise_catalog.id`
- `unlocked_next_id -> exercise_catalog.id`

Columns:

- `user_id`
- `exercise_id`
- `target_hit_streak default 0`
- `unlocked_next_id null`
- `last_final_reps null`
- `last_final_rest_seconds null`
- `last_avg_difficulty null` in `easy` / `hard` / `mixed`
- `last_was_deload boolean`
- `last_session_at null`

### `weekly_checkins` (0 rows)

Primary key: `id`
Foreign keys:

- `user_id -> profiles.id`
- `recommendation_id -> recommendations_log.id`

Columns:

- `id`
- `user_id`
- `recommendation_id`
- `week_number integer` between 1 and 7
- `phase_number integer` between 1 and 3
- `responses jsonb`
- `energy_score integer null`
- `pain_flag boolean default false`
- `difficulty_avg numeric null`
- `notes null`
- `created_at`

### `fitness_retests` (0 rows)

Primary key: `id`
Foreign keys:

- `user_id -> profiles.id`
- `recommendation_id -> recommendations_log.id`

Columns:

- `id`
- `user_id`
- `recommendation_id null`
- `squat_reps null >= 0`
- `wall_pushup_reps null >= 0`
- `squat_form_score null` between 0 and 100
- `pushup_form_score null` between 0 and 100
- `previous_level null`
- `suggested_level null`
- `accepted_level null`
- `user_action null` in `accepted` / `declined` / `no_change`
- `scoring_version default 'v1'`
- `raw_scoring_input jsonb null`
- `created_at`
