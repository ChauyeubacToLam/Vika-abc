-- Relax profiles.training_duration CHECK to the v5 onboarding buckets.
--
-- The v5 onboarding (lib/screens/onboarding/v5/v5_models.dart V5DurationOption)
-- collects training experience as '<6m' / '6m-2y' / '2y+', and the whole
-- recommendation path (fitness_test_scoring.dart) is built around those ids.
-- The original CHECK predates v5 and only allowed the older '<3m' / '3-11m' /
-- '1y+' buckets, so every v5 profile upsert failed:
--   new row for relation "profiles" violates check constraint
--   "profiles_training_duration_check" (code 23514)
--
-- Fix = a SUPERSET: allow the v5 values AND keep the legacy values. Existing
-- rows (5×'<3m', 2×'3-11m', 2×'1y+') stay valid — the bucket boundaries differ,
-- so remapping them would rewrite real users' experience level on a guess. The
-- app only ever writes the v5 values from here on; legacy values are read-only
-- history.

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_training_duration_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_training_duration_check
  CHECK (
    training_duration = ANY (
      ARRAY['<6m', '6m-2y', '2y+', '<3m', '3-11m', '1y+']
    )
  );
