alter table public.loans
  add column if not exists term_months integer
    check (term_months is null or term_months between 1 and 600),
  add column if not exists annual_interest_bps integer not null default 0
    check (annual_interest_bps between 0 and 100000),
  add column if not exists monthly_payment_cents bigint
    check (monthly_payment_cents is null or monthly_payment_cents > 0);

create table if not exists public.user_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  weekly_expense_limit_cents bigint
    check (weekly_expense_limit_cents is null or weekly_expense_limit_cents > 0),
  updated_at timestamptz not null default now()
);

alter table public.user_preferences enable row level security;

drop policy if exists "Users can view their own preferences" on public.user_preferences;
create policy "Users can view their own preferences"
  on public.user_preferences for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can create their own preferences" on public.user_preferences;
create policy "Users can create their own preferences"
  on public.user_preferences for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own preferences" on public.user_preferences;
create policy "Users can update their own preferences"
  on public.user_preferences for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

grant select, insert, update on public.user_preferences to authenticated;
