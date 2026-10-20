create table if not exists public.sms_import_tokens (
  user_id uuid primary key references auth.users(id) on delete cascade,
  token_hash text not null,
  created_at timestamptz not null default now()
);

alter table public.sms_import_tokens enable row level security;
revoke all on public.sms_import_tokens from anon, authenticated;

create or replace function public.create_sms_import_token()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  new_token text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  new_token := encode(gen_random_bytes(32), 'hex');
  insert into public.sms_import_tokens (user_id, token_hash)
  values (auth.uid(), encode(digest(new_token, 'sha256'), 'hex'))
  on conflict (user_id) do update
    set token_hash = excluded.token_hash,
        created_at = now();
  return new_token;
end;
$$;

create or replace function public.revoke_sms_import_token()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  delete from public.sms_import_tokens where user_id = auth.uid();
end;
$$;

revoke all on function public.create_sms_import_token() from public, anon;
revoke all on function public.revoke_sms_import_token() from public, anon;
grant execute on function public.create_sms_import_token() to authenticated;
grant execute on function public.revoke_sms_import_token() to authenticated;

alter table public.transactions
  add column if not exists sms_fingerprint text;

create unique index if not exists transactions_user_sms_fingerprint_idx
  on public.transactions (user_id, sms_fingerprint);
