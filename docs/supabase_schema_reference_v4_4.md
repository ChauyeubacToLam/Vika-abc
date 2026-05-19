# Vika v4.4 Supabase Schema Reference

Project: `vinafit-prod` (`frjtlfzbvdgwgzegfzxh`)
Schema: `public`
Updated: 2026-05-18, after v4.4 migration

This is the data-layer ground truth for recommendation v4.4 work. If code or older reports disagree with this file, this file wins.

## Naming Gotchas

- The variant unlock / carry-over table is `user_exercise_capacity`. Older notes may call it `user_exercise_progressions`; that name is stale.
- `recommendations_log` uses `generated_at`, not `created_at`.
- Active plan = latest `recommendations_log` row for the user where `plan_completed_at IS NULL`, ordered by `generated_at`.
- Engine difficulty labels are `easy` / `ok` / `hard`; UI labels are `light` / `medium` / `heavy`.
- `exercise_sessions` is per exercise, not per workout. A 4-exercise workout creates 4 rows.
- `profiles.created_at` and `profiles.updated_at` are legacy `text`, not `timestamptz`.
- `exercise_catalog.max_reps` and `max_seconds` are stale. Use tier-specific cap columns only.

## Recommendation Tables

### `recommendations_log`

Required columns used by the app:

- `id uuid primary key`
- `user_id uuid not null`
- `generated_at timestamptz not null default now()`
- `trigger text not null`
- `template_key text not null`
- `plan_structure jsonb not null`
- `algorithm_version text not null`
- `rng_seed text not null`
- `parameters jsonb not null`
- `user_snapshot jsonb not null`
- `superseded_at timestamptz null`
- `plan_started_at timestamptz null`
- `plan_completed_at timestamptz null`

`plan_structure` v4.4 shape:

```json
{
  "schema_version": "4.4",
  "plan_scope": "full",
  "weekly_check_in_weeks": [2, 3, 4, 5, 6, 7],
  "end_retest": {
    "trigger_week": 8,
    "scoring_version": "v1"
  },
  "weeks": [
    {
      "week_number": 1,
      "phase_number": 1,
      "phase_name": "Nền tảng",
      "is_deload_week": false,
      "sessions": [
        {
          "session_index": 0,
          "session_type": "workout",
          "slots": [
            {
              "slot_name": "lower_body_strength",
              "exercise_id": "squat_bw",
              "volume": {
                "sets": 2,
                "rest_seconds": 60,
                "reps": 10,
                "seconds": null,
                "is_deload_week": false
              },
              "score": 0.85,
              "top_k_candidates": []
            }
          ]
        }
      ]
    }
  ]
}
```

### `user_exercise_capacity`

Per-user, per-exercise progression state:

- `user_id uuid`
- `exercise_id text`
- `target_hit_streak integer not null default 0`
- `unlocked_next_id text null`
- `last_final_reps integer null`
- `last_final_rest_seconds integer null`
- `last_avg_difficulty text null` in `easy` / `hard` / `mixed`
- `last_was_deload boolean not null default false`
- `last_session_at timestamptz null`

Primary key: `(user_id, exercise_id)`.

### `weekly_checkins`

Weekly wellness logging:

- `id uuid primary key`
- `user_id uuid not null`
- `recommendation_id uuid not null`
- `week_number integer not null`
- `phase_number integer not null`
- `responses jsonb not null`
- `energy_score integer null`
- `pain_flag boolean not null default false`
- `difficulty_avg numeric null`
- `notes text null`
- `created_at timestamptz not null default now()`

Unique: `(user_id, recommendation_id, week_number)`.

`responses` shape:

```json
{
  "energy": 4,
  "soreness": 2,
  "sleep_quality": 4,
  "motivation": 3,
  "pain_change": "same",
  "progress_feel": "yes"
}
```

### `fitness_retests`

End-of-plan retest results:

- `id uuid primary key`
- `user_id uuid not null`
- `recommendation_id uuid null`
- `squat_reps integer null`
- `wall_pushup_reps integer null`
- `squat_form_score integer null`
- `pushup_form_score integer null`
- `previous_level text null`
- `suggested_level text null`
- `accepted_level text null`
- `user_action text null` in `accepted` / `declined` / `no_change`
- `scoring_version text not null default 'v1'`
- `raw_scoring_input jsonb null`
- `created_at timestamptz not null default now()`

## Exercise Session v4.4 Fields

`exercise_sessions.set_data` is an array. Each set should include:

```json
{
  "set_number": 1,
  "prescribed_reps": 10,
  "prescribed_rest": 60,
  "actual_reps": 10,
  "applied_rest": 60,
  "recommendation_id": "uuid-here",
  "week_number": 1,
  "is_deload_week": false,
  "rep_data": []
}
```
