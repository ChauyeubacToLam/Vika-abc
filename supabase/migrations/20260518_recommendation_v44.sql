-- Recommendation Engine v4.4 support tables.
-- Matches vinafit-prod public schema as of 2026-05-18.
-- RLS follows the existing pattern: users can select/insert/update own rows.

alter table public.recommendations_log
  add column if not exists generated_at timestamptz not null default now(),
  add column if not exists superseded_at timestamptz,
  add column if not exists plan_started_at timestamptz,
  add column if not exists plan_completed_at timestamptz;

create index if not exists idx_reco_log_user_active
  on public.recommendations_log (user_id, plan_completed_at)
  where plan_completed_at is null;

alter table public.recommendations_log enable row level security;

drop policy if exists "Users can read own recommendations"
  on public.recommendations_log;
create policy "Users can read own recommendations"
  on public.recommendations_log
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own recommendations"
  on public.recommendations_log;
create policy "Users can insert own recommendations"
  on public.recommendations_log
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own recommendation lifecycle"
  on public.recommendations_log;
create policy "Users can update own recommendation lifecycle"
  on public.recommendations_log
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create table if not exists public.user_exercise_capacity (
  user_id uuid not null references public.profiles(id) on delete cascade,
  exercise_id text not null references public.exercise_catalog(id),
  target_hit_streak integer not null default 0 check (target_hit_streak >= 0),
  unlocked_next_id text references public.exercise_catalog(id),
  last_final_reps integer,
  last_final_rest_seconds integer,
  last_avg_difficulty text check (
    last_avg_difficulty in ('easy', 'hard', 'mixed')
  ),
  last_was_deload boolean not null default false,
  last_session_at timestamptz,
  primary key (user_id, exercise_id)
);

alter table public.user_exercise_capacity enable row level security;

drop policy if exists "Users can read own exercise capacity"
  on public.user_exercise_capacity;
create policy "Users can read own exercise capacity"
  on public.user_exercise_capacity
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own exercise capacity"
  on public.user_exercise_capacity;
create policy "Users can insert own exercise capacity"
  on public.user_exercise_capacity
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own exercise capacity"
  on public.user_exercise_capacity;
create policy "Users can update own exercise capacity"
  on public.user_exercise_capacity
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create table if not exists public.weekly_checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  recommendation_id uuid not null references public.recommendations_log(id),
  week_number integer not null check (week_number between 1 and 7),
  phase_number integer not null check (phase_number between 1 and 3),
  responses jsonb not null,
  energy_score integer check (energy_score between 1 and 5),
  pain_flag boolean not null default false,
  difficulty_avg numeric,
  notes text,
  created_at timestamptz not null default now(),
  unique (user_id, recommendation_id, week_number)
);

alter table public.weekly_checkins enable row level security;

drop policy if exists "Users can read own weekly checkins"
  on public.weekly_checkins;
create policy "Users can read own weekly checkins"
  on public.weekly_checkins
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own weekly checkins"
  on public.weekly_checkins;
create policy "Users can insert own weekly checkins"
  on public.weekly_checkins
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own weekly checkins"
  on public.weekly_checkins;
create policy "Users can update own weekly checkins"
  on public.weekly_checkins
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create table if not exists public.fitness_retests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  recommendation_id uuid references public.recommendations_log(id)
    on delete set null,
  squat_reps integer check (squat_reps >= 0),
  wall_pushup_reps integer check (wall_pushup_reps >= 0),
  squat_form_score integer check (squat_form_score between 0 and 100),
  pushup_form_score integer check (pushup_form_score between 0 and 100),
  previous_level text check (
    previous_level in ('beginner', 'intermediate', 'advanced')
  ),
  suggested_level text check (
    suggested_level in ('beginner', 'intermediate', 'advanced')
  ),
  accepted_level text check (
    accepted_level in ('beginner', 'intermediate', 'advanced')
  ),
  user_action text check (
    user_action in ('accepted', 'declined', 'no_change')
  ),
  scoring_version text not null default 'v1',
  raw_scoring_input jsonb,
  created_at timestamptz not null default now()
);

alter table public.fitness_retests enable row level security;

drop policy if exists "Users can read own fitness retests"
  on public.fitness_retests;
create policy "Users can read own fitness retests"
  on public.fitness_retests
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own fitness retests"
  on public.fitness_retests;
create policy "Users can insert own fitness retests"
  on public.fitness_retests
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own fitness retests"
  on public.fitness_retests;
create policy "Users can update own fitness retests"
  on public.fitness_retests
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
