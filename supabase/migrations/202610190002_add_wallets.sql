create table if not exists public.wallets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  type text not null check (type in ('gcash', 'bank', 'cash', 'other')),
  opening_balance_cents bigint not null default 0 check (opening_balance_cents >= 0),
  opening_balance_on date not null default date '1900-01-01',
  created_at timestamptz not null default now()
);

create index if not exists wallets_user_created_idx
  on public.wallets (user_id, created_at);

alter table public.wallets enable row level security;

drop policy if exists "Users can view their own wallets" on public.wallets;
create policy "Users can view their own wallets"
  on public.wallets for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can create their own wallets" on public.wallets;
create policy "Users can create their own wallets"
  on public.wallets for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own wallets" on public.wallets;
create policy "Users can update their own wallets"
  on public.wallets for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

grant select, insert, update on public.wallets to authenticated;

-- Give existing accounts a starting wallet before requiring a wallet on ledger rows.
insert into public.wallets (user_id, name, type, opening_balance_cents)
select users.id, 'Cash', 'cash', 0
from auth.users as users
where not exists (
  select 1 from public.wallets as existing where existing.user_id = users.id
);

alter table public.transactions
  add column if not exists wallet_id uuid references public.wallets(id) on delete restrict;

update public.transactions as transaction_row
set wallet_id = (
  select wallet.id
  from public.wallets as wallet
  where wallet.user_id = transaction_row.user_id
  order by wallet.created_at, wallet.id
  limit 1
)
where transaction_row.wallet_id is null;

alter table public.transactions alter column wallet_id set not null;

create index if not exists transactions_wallet_date_idx
  on public.transactions (wallet_id, occurred_on desc, created_at desc);

drop policy if exists "Users can create their own transactions" on public.transactions;
create policy "Users can create their own transactions"
  on public.transactions for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.wallets as wallet
      where wallet.id = wallet_id and wallet.user_id = (select auth.uid())
    )
  );

drop policy if exists "Users can update their own transactions" on public.transactions;
create policy "Users can update their own transactions"
  on public.transactions for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.wallets as wallet
      where wallet.id = wallet_id and wallet.user_id = (select auth.uid())
    )
  );
