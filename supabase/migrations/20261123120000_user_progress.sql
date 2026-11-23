-- Each user's profile and progress (the app's UserStore.Profile as JSON), one row per user.
-- Only the owner can read or write their row; deleting the account (auth.users) deletes it.
create table public.user_progress (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  profile jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.user_progress enable row level security;

grant select, insert, update, delete on public.user_progress to authenticated;

create policy "own row: read" on public.user_progress for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "own row: insert" on public.user_progress for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "own row: update" on public.user_progress for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "own row: delete" on public.user_progress for delete to authenticated
  using ((select auth.uid()) = user_id);
