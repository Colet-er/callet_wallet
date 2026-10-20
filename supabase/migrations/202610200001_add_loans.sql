create table if not exists public.loans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  lender text not null check (char_length(lender) between 1 and 60),
  original_amount_cents bigint not null check (original_amount_cents >= 0),
  balance_cents bigint not null check (balance_cents >= 0),
  due_on date,
  created_at timestamptz not null default now()
);

create index if not exists loans_user_created_idx
  on public.loans (user_id, created_at desc);

alter table public.loans enable row level security;

drop policy if exists "Users can view their own loans" on public.loans;
create policy "Users can view their own loans"
  on public.loans for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can create their own loans" on public.loans;
create policy "Users can create their own loans"
  on public.loans for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own loans" on public.loans;
create policy "Users can update their own loans"
  on public.loans for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own loans" on public.loans;
create policy "Users can delete their own loans"
  on public.loans for delete to authenticated
  using ((select auth.uid()) = user_id);

grant select, insert, update, delete on public.loans to authenticated;
