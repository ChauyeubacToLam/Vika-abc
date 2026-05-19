-- Forward fix for app-side v4.4 plan generation.
-- If the base v4.4 migration was already applied, this migration gives the
-- Flutter client the own-row INSERT permission it needs to create a plan after
-- onboarding/login. Move generation server-side later if this policy becomes
-- too broad for production architecture.

alter table public.recommendations_log
  add column if not exists generated_at timestamptz not null default now(),
  add column if not exists superseded_at timestamptz,
  add column if not exists plan_started_at timestamptz,
  add column if not exists plan_completed_at timestamptz;

alter table public.recommendations_log enable row level security;

drop policy if exists "Users can insert own recommendations"
  on public.recommendations_log;
create policy "Users can insert own recommendations"
  on public.recommendations_log
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can read own recommendations"
  on public.recommendations_log;
create policy "Users can read own recommendations"
  on public.recommendations_log
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users can update own recommendation lifecycle"
  on public.recommendations_log;
create policy "Users can update own recommendation lifecycle"
  on public.recommendations_log
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
