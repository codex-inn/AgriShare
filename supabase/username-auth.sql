-- AgriShare username signup rate-limit storage.
-- Apply in Supabase SQL Editor before deploying username-signup.
-- No anon/authenticated policies are intentionally created; only the Edge Function's
-- server-side service-role client should access this table.
create table if not exists public.username_signup_attempts (
  id bigint generated always as identity primary key,
  username text not null,
  ip_hash text not null,
  created_at timestamptz not null default now()
);

create index if not exists username_signup_attempts_created_at_idx
  on public.username_signup_attempts (created_at desc);
create index if not exists username_signup_attempts_ip_created_idx
  on public.username_signup_attempts (ip_hash, created_at desc);
create index if not exists username_signup_attempts_user_created_idx
  on public.username_signup_attempts (username, created_at desc);

alter table public.username_signup_attempts enable row level security;
revoke all on public.username_signup_attempts from anon, authenticated;
