-- AgriShare marketplace safety, private support queue and participant-only reviews.
-- Apply once to an existing AgriShare project after the core booking migrations.
-- No user/listing data is created or changed by this migration.

-- Prevent two pending/accepted requests for one machine on the same date.
-- Production was checked before applying this index; booking_requests was empty.
create unique index if not exists booking_requests_active_equipment_date_uidx
  on public.booking_requests(equipment_id, preferred_date)
  where status in ('pending', 'accepted');

-- Harden existing SECURITY DEFINER functions by removing caller-controlled schemas.
-- Their bodies already qualify table/function references.
alter function private.join_group_core(uuid, numeric) set search_path = '';
alter function private.mark_group_full_when_capacity_reached() set search_path = '';
alter function private.refresh_group_progress_cache() set search_path = '';
alter function public.notify_booking_status_change() set search_path = '';
alter function public.notify_group_status_change() set search_path = '';

create table if not exists public.booking_reviews (
  id uuid primary key default gen_random_uuid(),
  booking_request_id uuid not null references public.booking_requests(id) on delete cascade,
  reviewer_id uuid not null references auth.users(id) on delete cascade,
  reviewee_id uuid not null references auth.users(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  comment text not null default '' check (comment = pg_catalog.btrim(comment) and char_length(comment) <= 1000),
  created_at timestamptz not null default now(),
  constraint booking_reviews_no_self_review check (reviewer_id <> reviewee_id),
  constraint booking_reviews_one_per_reviewer unique (booking_request_id, reviewer_id)
);
create index if not exists booking_reviews_reviewee_created_idx
  on public.booking_reviews(reviewee_id, created_at desc);
alter table public.booking_reviews enable row level security;
revoke all on table public.booking_reviews from public, anon, authenticated;
grant select on table public.booking_reviews to authenticated;
grant insert (booking_request_id, reviewer_id, reviewee_id, rating, comment)
  on table public.booking_reviews to authenticated;
drop policy if exists "Booking participants can read their reviews" on public.booking_reviews;
drop policy if exists "Completed booking participants can leave reviews" on public.booking_reviews;
create policy "Booking participants can read their reviews"
  on public.booking_reviews for select to authenticated
  using ((select auth.uid()) = reviewer_id or (select auth.uid()) = reviewee_id);

-- This private SECURITY DEFINER predicate can see equipment rows hidden by the
-- listing RLS policy. It returns only whether this caller may review this booking.
create or replace function private.can_submit_booking_review(
  p_booking_request_id uuid, p_reviewer_id uuid, p_reviewee_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    p_reviewer_id = (select auth.uid()) and exists (
      select 1
      from public.booking_requests br
      join public.equipment e on e.id = br.equipment_id
      where br.id = p_booking_request_id
        and br.status = 'completed'
        and (
          (br.farmer_id = p_reviewer_id and e.owner_id = p_reviewee_id)
          or (e.owner_id = p_reviewer_id and br.farmer_id = p_reviewee_id)
        )
    ),
    false
  );
$$;
revoke all on function private.can_submit_booking_review(uuid, uuid, uuid) from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.can_submit_booking_review(uuid, uuid, uuid) to authenticated;
create policy "Completed booking participants can leave reviews"
  on public.booking_reviews for insert to authenticated
  with check (private.can_submit_booking_review(booking_request_id, reviewer_id, reviewee_id));

create table if not exists public.support_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid references auth.users(id) on delete set null,
  request_type text not null check (request_type in ('general','listing_safety','account_access','account_deletion','other')),
  equipment_id uuid references public.equipment(id) on delete set null,
  details text not null check (details = pg_catalog.btrim(details) and char_length(details) between 10 and 1200),
  status text not null default 'open' check (status in ('open','in_review','resolved','closed')),
  created_at timestamptz not null default now()
);
create index if not exists support_requests_requester_created_idx
  on public.support_requests(requester_id, created_at desc);
alter table public.support_requests enable row level security;
revoke all on table public.support_requests from public, anon, authenticated;
grant insert (requester_id, request_type, equipment_id, details)
  on public.support_requests to authenticated;
drop policy if exists "Signed-in users can submit their own support requests" on public.support_requests;
create policy "Signed-in users can submit their own support requests"
  on public.support_requests for insert to authenticated
  with check ((select auth.uid()) = requester_id);

-- Allow at most five support submissions per account per rolling hour. The
-- trigger function is private, has a fixed empty search_path, and cannot be
-- invoked directly through the client API.
create or replace function private.enforce_support_request_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  request_count integer;
begin
  if new.requester_id is null or new.requester_id is distinct from (select auth.uid()) then
    raise exception using errcode = '42501', message = 'Sign in required to send a support request';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.requester_id::text, 0));
  select pg_catalog.count(*) into request_count
  from public.support_requests sr
  where sr.requester_id = new.requester_id
    and sr.created_at > pg_catalog.now() - interval '1 hour';
  if request_count >= 5 then
    raise exception using errcode = 'P0001', message = 'Support request limit reached. Try again later.';
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_support_request_rate_limit() from public, anon, authenticated;
drop trigger if exists enforce_support_request_rate_limit on public.support_requests;
create trigger enforce_support_request_rate_limit
  before insert on public.support_requests
  for each row execute function private.enforce_support_request_rate_limit();
