alter table public.wallets
  add column if not exists account_last4 text,
  add column if not exists sms_alias text not null default '';

alter table public.wallets
  drop constraint if exists wallets_account_last4_check;
alter table public.wallets
  add constraint wallets_account_last4_check
  check (account_last4 is null or account_last4 ~ '^[0-9]{4}$');

alter table public.transactions
  add column if not exists transfer_to_wallet_id uuid
    references public.wallets(id) on delete restrict;

alter table public.transactions
  drop constraint if exists transactions_type_check;
alter table public.transactions
  add constraint transactions_type_check
  check (type in ('income', 'expense', 'transfer'));

alter table public.transactions
  drop constraint if exists transactions_transfer_wallet_check;
alter table public.transactions
  add constraint transactions_transfer_wallet_check
  check (
    (type = 'transfer' and transfer_to_wallet_id is not null and transfer_to_wallet_id <> wallet_id)
    or (type <> 'transfer' and transfer_to_wallet_id is null)
  );

drop policy if exists "Users can create their own transactions" on public.transactions;
create policy "Users can create their own transactions"
  on public.transactions for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.wallets as source_wallet
      where source_wallet.id = wallet_id and source_wallet.user_id = (select auth.uid())
    )
    and (
      transfer_to_wallet_id is null
      or exists (
        select 1 from public.wallets as destination_wallet
        where destination_wallet.id = transfer_to_wallet_id
          and destination_wallet.user_id = (select auth.uid())
      )
    )
  );

drop policy if exists "Users can update their own transactions" on public.transactions;
create policy "Users can update their own transactions"
  on public.transactions for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.wallets as source_wallet
      where source_wallet.id = wallet_id and source_wallet.user_id = (select auth.uid())
    )
    and (
      transfer_to_wallet_id is null
      or exists (
        select 1 from public.wallets as destination_wallet
        where destination_wallet.id = transfer_to_wallet_id
          and destination_wallet.user_id = (select auth.uid())
      )
    )
  );

create index if not exists transactions_transfer_destination_idx
  on public.transactions (transfer_to_wallet_id, occurred_on desc, created_at desc)
  where transfer_to_wallet_id is not null;
