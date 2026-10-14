-- AgriShare Supabase starter schema
-- Run in a NEW Supabase project after reviewing the policies below.
-- This is a foundation, not a complete production booking system.
create extension if not exists pgcrypto;

create table if not exists public.equipment (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 120),
  category text not null check (category in ('Tractor','Rotavator','Harvester','Transplanter','Sprayer','Other')),
  implement_type text,
  description text,
  rate numeric(10,2) not null check (rate > 0),
  rate_unit text not null default 'acre' check (rate_unit in ('acre','hour','trip','day')),
  village text not null,
  service_area text,
  image_url text,
  verified boolean not null default false,
  available boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.group_bookings (
  id uuid primary key default gen_random_uuid(),
  organizer_id uuid not null references auth.users(id) on delete cascade,
  equipment_category text not null check (equipment_category in ('Tractor','Rotavator','Harvester','Transplanter','Sprayer','Other')),
  village text not null,
  preferred_date date not null,
  target_acres numeric(10,2) not null check (target_acres > 0),
  rate_per_acre numeric(10,2) not null check (rate_per_acre > 0),
  status text not null default 'open' check (status in ('open','full','scheduled','completed','cancelled')),
  created_at timestamptz not null default now()
);

create table if not exists public.group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.group_bookings(id) on delete cascade,
  farmer_id uuid not null references auth.users(id) on delete cascade,
  acres numeric(10,2) not null check (acres > 0),
  notes text,
  created_at timestamptz not null default now(),
  unique(group_id, farmer_id)
);

create table if not exists public.booking_requests (
  id uuid primary key default gen_random_uuid(),
  farmer_id uuid not null references auth.users(id) on delete cascade,
  equipment_id uuid not null references public.equipment(id) on delete restrict,
  preferred_date date not null,
  acres numeric(10,2) not null check (acres > 0),
  village text not null,
  notes text,
  status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled','completed')),
  created_at timestamptz not null default now()
);

alter table public.equipment enable row level security;
alter table public.group_bookings enable row level security;
alter table public.group_members enable row level security;
alter table public.booking_requests enable row level security;

-- Foreign-key indexes help joins, deletes and owner/member lookups as data grows.
create index if not exists equipment_owner_id_idx on public.equipment(owner_id);
create index if not exists group_bookings_organizer_id_idx on public.group_bookings(organizer_id);
create index if not exists group_members_farmer_id_idx on public.group_members(farmer_id);
create index if not exists booking_requests_farmer_id_idx on public.booking_requests(farmer_id);
create index if not exists booking_requests_equipment_id_idx on public.booking_requests(equipment_id);

-- Do not automatically drop legacy contact columns here: dropping a column can
-- permanently delete existing owner contact data. If a legacy contact_phone column
-- exists, migrate its values into a reviewed private/consent-based contact flow first.


-- Drop named policies first so this script can be re-run in development.
drop policy if exists "Equipment listings are readable" on public.equipment;
drop policy if exists "Owners can create equipment listings" on public.equipment;
drop policy if exists "Owners can update own equipment" on public.equipment;
drop policy if exists "Owners can delete own equipment" on public.equipment;
drop policy if exists "Open groups are readable" on public.group_bookings;
drop policy if exists "Authenticated farmers can create groups" on public.group_bookings;
drop policy if exists "Organizers can update their groups" on public.group_bookings;
drop policy if exists "Organizers can delete their groups" on public.group_bookings;
drop policy if exists "Members and organizers can read group members" on public.group_members;
drop policy if exists "Farmers can join open groups as themselves" on public.group_members;
drop policy if exists "Farmers can edit their own membership" on public.group_members;
drop policy if exists "Farmers can leave their own group" on public.group_members;
drop policy if exists "Farmers can read their own booking requests" on public.booking_requests;
drop policy if exists "Farmers can create booking requests" on public.booking_requests;
drop policy if exists "Farmers can cancel their own pending requests" on public.booking_requests;
drop policy if exists "Equipment owners can read booking requests" on public.booking_requests;
drop policy if exists "Equipment owners can update booking status" on public.booking_requests;

drop policy if exists "Available equipment listings are readable" on public.equipment;
drop policy if exists "Owners can create equipment listings" on public.equipment;
drop policy if exists "Owners can update own equipment" on public.equipment;
drop policy if exists "Owners can delete own equipment" on public.equipment;
drop policy if exists "Open groups are readable" on public.group_bookings;
drop policy if exists "Authenticated farmers can create groups" on public.group_bookings;
drop policy if exists "Organizers can update their groups" on public.group_bookings;
drop policy if exists "Organizers can delete their groups" on public.group_bookings;
drop policy if exists "Members and organizers can read group members" on public.group_members;
drop policy if exists "Farmers can join open groups as themselves" on public.group_members;
drop policy if exists "Farmers can edit their own membership" on public.group_members;
drop policy if exists "Farmers can leave their own group" on public.group_members;
drop policy if exists "Farmers can read their own booking requests" on public.booking_requests;
drop policy if exists "Farmers can create booking requests" on public.booking_requests;
drop policy if exists "Farmers can cancel their own pending requests" on public.booking_requests;
drop policy if exists "Equipment owners can read booking requests" on public.booking_requests;
drop policy if exists "Equipment owners can update booking status" on public.booking_requests;

-- Public listing fields contain no owner phone number. Use a consent-based contact flow later.
create policy "Available equipment listings are readable"
  on public.equipment for select to anon, authenticated
  using (available = true or auth.uid() = owner_id);
create policy "Owners can create equipment listings"
  on public.equipment for insert to authenticated
  with check (auth.uid() = owner_id);
create policy "Owners can update own equipment"
  on public.equipment for update to authenticated
  using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "Owners can delete own equipment"
  on public.equipment for delete to authenticated
  using (auth.uid() = owner_id);

create policy "Open groups are readable"
  on public.group_bookings for select to anon, authenticated
  using (status = 'open' or auth.uid() = organizer_id);
create policy "Authenticated farmers can create groups"
  on public.group_bookings for insert to authenticated
  with check (auth.uid() = organizer_id);
create policy "Organizers can delete their groups"
  on public.group_bookings for delete to authenticated
  using (auth.uid() = organizer_id);

-- Only the member and the group organizer can read a membership row.
create policy "Members and organizers can read group members"
  on public.group_members for select to authenticated
  using (
    auth.uid() = farmer_id or exists (
      select 1 from public.group_bookings g
      where g.id = group_id and g.organizer_id = auth.uid()
    )
  );
create policy "Farmers can join open groups as themselves"
  on public.group_members for insert to authenticated
  with check (
    auth.uid() = farmer_id and exists (
      select 1 from public.group_bookings g
      where g.id = group_id and g.status = 'open' and g.organizer_id <> auth.uid()
    )
  );
create policy "Farmers can leave their own group"
  on public.group_members for delete to authenticated
  using (auth.uid() = farmer_id);

-- A farmer sees their own request; the owner sees requests for their own equipment.
create policy "Farmers can read their own booking requests"
  on public.booking_requests for select to authenticated
  using (auth.uid() = farmer_id);
create policy "Farmers can create booking requests"
  on public.booking_requests for insert to authenticated
  with check (
    auth.uid() = farmer_id and exists (
      select 1 from public.equipment e
      where e.id = equipment_id and e.available = true
    )
  );
create policy "Equipment owners can read booking requests"
  on public.booking_requests for select to authenticated
  using (exists (
    select 1 from public.equipment e
    where e.id = equipment_id and e.owner_id = auth.uid()
  ));


-- Explicit least-privilege grants. RLS policies do not replace SQL privileges.
-- Equipment listings are public-read, but owners cannot self-mark as verified or
-- change the owner_id. Column grants also prevent clients setting protected fields.
revoke all on table public.equipment from anon, authenticated;
grant select on table public.equipment to anon, authenticated;
grant insert (owner_id, name, category, description, rate, rate_unit, village, service_area, image_url, available, equipment_role, horsepower, hitch_type, pto_rpm, hydraulic_capacity_lpm, min_tractor_hp, max_tractor_hp, required_pto_rpm, required_hydraulic_lpm, compatibility_notes, implement_type)
  on table public.equipment to authenticated;
grant update (name, category, description, rate, rate_unit, village, service_area, image_url, available, equipment_role, horsepower, hitch_type, pto_rpm, hydraulic_capacity_lpm, min_tractor_hp, max_tractor_hp, required_pto_rpm, required_hydraulic_lpm, compatibility_notes, implement_type)
  on table public.equipment to authenticated;
grant delete on table public.equipment to authenticated;

-- Group booking creation and read are supported by the current UI. Status changes
-- and group edits need a server-side workflow; do not permit direct client updates.
revoke all on table public.group_bookings from anon, authenticated;
grant select on table public.group_bookings to anon, authenticated;
grant insert (organizer_id, equipment_category, village, preferred_date, target_acres, rate_per_acre)
  on table public.group_bookings to authenticated;
grant delete on table public.group_bookings to authenticated;

-- Membership rows are private to members/organizers under RLS. Farmers may join
-- and leave groups, but cannot move/edit membership rows after creation.
revoke all on table public.group_members from anon, authenticated;
grant select, delete on table public.group_members to authenticated;
grant insert (group_id, farmer_id, acres) on table public.group_members to authenticated;

-- Booking requests may be created and read by the farmer and equipment owner.
-- Direct updates are disabled until a server-validated status transition exists.
revoke all on table public.booking_requests from anon, authenticated;
grant select on table public.booking_requests to authenticated;
grant insert (farmer_id, equipment_id, preferred_date, acres, village, notes)
  on table public.booking_requests to authenticated;

-- Before launch, add server-side validation for status transitions, group capacity,
-- preventing overbooking, image storage policies, abuse controls, and audited owner verification.


-- Return only aggregate acreage, never individual farmer identities or notes.

-- Safe public aggregate: expose only acreage totals, not farmer identities.
-- The cache is maintained by a private trigger function so the API caller does
-- not need direct SELECT access to group_members.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
create table if not exists public.group_progress_cache (
  group_id uuid primary key references public.group_bookings(id) on delete cascade,
  joined_acres numeric not null default 0 check (joined_acres >= 0),
  updated_at timestamptz not null default now()
);
alter table public.group_progress_cache enable row level security;
drop policy if exists "Public can read aggregate group progress" on public.group_progress_cache;
create policy "Public can read aggregate group progress"
  on public.group_progress_cache for select to anon, authenticated using (true);
revoke all on public.group_progress_cache from public, anon, authenticated;
grant select on public.group_progress_cache to anon, authenticated;
insert into public.group_progress_cache(group_id, joined_acres)
select g.id, coalesce(sum(m.acres),0)::numeric
from public.group_bookings g left join public.group_members m on m.group_id=g.id
group by g.id
on conflict(group_id) do update set joined_acres=excluded.joined_acres, updated_at=now();

create or replace function private.refresh_group_progress_cache()
returns trigger language plpgsql security definer
set search_path = ''
as $$
declare v_group_id uuid;
begin
  if tg_op = 'DELETE' then
    v_group_id := old.group_id;
    insert into public.group_progress_cache(group_id, joined_acres, updated_at)
    select g.id, coalesce(sum(m.acres),0)::numeric, now()
    from public.group_bookings g left join public.group_members m on m.group_id=g.id
    where g.id=v_group_id group by g.id
    on conflict(group_id) do update set joined_acres=excluded.joined_acres, updated_at=now();
    return old;
  end if;
  v_group_id := new.group_id;
  insert into public.group_progress_cache(group_id, joined_acres, updated_at)
  select g.id, coalesce(sum(m.acres),0)::numeric, now()
  from public.group_bookings g left join public.group_members m on m.group_id=g.id
  where g.id=v_group_id group by g.id
  on conflict(group_id) do update set joined_acres=excluded.joined_acres, updated_at=now();
  if tg_op='UPDATE' and old.group_id is distinct from new.group_id then
    insert into public.group_progress_cache(group_id, joined_acres, updated_at)
    select g.id, coalesce(sum(m.acres),0)::numeric, now()
    from public.group_bookings g left join public.group_members m on m.group_id=g.id
    where g.id=old.group_id group by g.id
    on conflict(group_id) do update set joined_acres=excluded.joined_acres, updated_at=now();
  end if;
  return new;
end;
$$;
revoke all on function private.refresh_group_progress_cache() from public, anon, authenticated;
drop trigger if exists refresh_group_progress_cache_after_membership on public.group_members;
create trigger refresh_group_progress_cache_after_membership
after insert or update or delete on public.group_members
for each row execute function private.refresh_group_progress_cache();

create or replace function public.get_group_progress()
returns table(group_id uuid, joined_acres numeric)
language sql stable security invoker
set search_path = public, pg_temp
as $$
  select g.id, coalesce(c.joined_acres,0)::numeric
  from public.group_bookings g
  left join public.group_progress_cache c on c.group_id=g.id
  where g.status='open';
$$;
revoke all on function public.get_group_progress() from public;
grant execute on function public.get_group_progress() to anon, authenticated;


-- Marketplace production-readiness workflows.
create unique index if not exists booking_requests_active_equipment_date_uidx
  on public.booking_requests(equipment_id, preferred_date)
  where status in ('pending', 'accepted');

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
create index if not exists booking_reviews_reviewer_created_idx
  on public.booking_reviews(reviewer_id, created_at desc);
alter table public.booking_reviews enable row level security;
revoke all on table public.booking_reviews from public, anon, authenticated;
grant select on table public.booking_reviews to authenticated;
grant insert (booking_request_id, reviewer_id, reviewee_id, rating, comment)
  on public.booking_reviews to authenticated;
drop policy if exists "Booking participants can read their reviews" on public.booking_reviews;
drop policy if exists "Completed booking participants can leave reviews" on public.booking_reviews;
create policy "Booking participants can read their reviews"
  on public.booking_reviews for select to authenticated
  using ((select auth.uid()) = reviewer_id or (select auth.uid()) = reviewee_id);

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
create index if not exists support_requests_equipment_id_idx
  on public.support_requests(equipment_id);
alter table public.support_requests enable row level security;
revoke all on table public.support_requests from public, anon, authenticated;
grant insert (requester_id, request_type, equipment_id, details)
  on public.support_requests to authenticated;
drop policy if exists "Signed-in users can submit their own support requests" on public.support_requests;
create policy "Signed-in users can submit their own support requests"
  on public.support_requests for insert to authenticated
  with check ((select auth.uid()) = requester_id);

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


-- Smart compatibility, private owner evidence, grouped booking requests and task-aware groups.
-- Keep this section aligned with supabase/smart-equipment-bundle-workflows.sql.
-- Smart tractor/implement matching, private specification evidence and atomic bundle requests.
-- Additive migration: no equipment, booking or group rows are seeded or rewritten.
begin;

alter table public.equipment add column if not exists implement_type text;
alter table public.equipment add constraint equipment_implement_type_check
  check (implement_type is null or implement_type = any (array['Rotavator','Rotary tiller','Plough','Seed drill','Disc harrow','Baler','Harvester','Sprayer','Other']));
grant select (implement_type) on public.equipment to anon, authenticated;
grant insert (implement_type) on public.equipment to authenticated;
grant update (implement_type) on public.equipment to authenticated;

alter table public.group_bookings add column if not exists work_type text not null default 'general';
alter table public.group_bookings add constraint group_bookings_work_type_check
  check (work_type = any (array['general','ploughing','tilling','seeding','harvesting','spraying','baling','other']));
grant select (work_type) on public.group_bookings to anon, authenticated;
grant insert (work_type) on public.group_bookings to authenticated;

create table if not exists public.booking_bundles (
  id uuid primary key default gen_random_uuid(),
  farmer_id uuid not null references auth.users(id) on delete cascade,
  preferred_date date not null,
  acres numeric(10,2) not null check (acres > 0 and acres <= 10000),
  village text not null check (char_length(trim(village)) between 1 and 120),
  task text not null check (task = any (array['general','ploughing','tilling','seeding','harvesting','spraying','baling','other'])),
  item_count integer not null check (item_count between 2 and 5),
  created_at timestamptz not null default now()
);
alter table public.booking_requests add column if not exists bundle_id uuid;
alter table public.booking_requests add column if not exists requested_rate_snapshot numeric(10,2);
alter table public.booking_requests add column if not exists requested_rate_unit_snapshot text;
alter table public.booking_requests add constraint booking_requests_requested_rate_snapshot_check
  check (requested_rate_snapshot is null or requested_rate_snapshot > 0);
alter table public.booking_requests add constraint booking_requests_requested_rate_unit_snapshot_check
  check (requested_rate_unit_snapshot is null or requested_rate_unit_snapshot = any (array['acre','hour','trip','day']));
do $$
begin
  if not exists (select 1 from pg_constraint where conname='booking_requests_bundle_id_fkey' and conrelid='public.booking_requests'::regclass) then
    alter table public.booking_requests add constraint booking_requests_bundle_id_fkey
      foreign key (bundle_id) references public.booking_bundles(id) on delete set null;
  end if;
end $$;
create index if not exists booking_requests_bundle_id_idx on public.booking_requests(bundle_id) where bundle_id is not null;
alter table public.booking_bundles enable row level security;
create policy "Farmers and participating owners can read bundles"
  on public.booking_bundles for select to authenticated
  using (
    farmer_id = (select auth.uid())
    or exists (
      select 1 from public.booking_requests br
      join public.equipment e on e.id = br.equipment_id
      where br.bundle_id = booking_bundles.id and e.owner_id = (select auth.uid())
    )
  );
revoke all on public.booking_bundles from anon, authenticated;
grant select on public.booking_bundles to authenticated;
grant select (bundle_id, requested_rate_snapshot, requested_rate_unit_snapshot) on public.booking_requests to authenticated;

create table if not exists public.equipment_compatibility_reviews (
  equipment_id uuid primary key references public.equipment(id) on delete cascade,
  status text not null default 'unverified' check (status in ('unverified','pending','approved','rejected')),
  reviewed_at timestamptz,
  updated_at timestamptz not null default now(),
  check ((status = 'approved' and reviewed_at is not null) or status <> 'approved')
);
alter table public.equipment_compatibility_reviews enable row level security;
create policy "Visible listings expose compatibility review state"
  on public.equipment_compatibility_reviews for select to anon, authenticated
  using (
    exists (
      select 1 from public.equipment e
      where e.id = equipment_id and (e.available = true or e.owner_id = (select auth.uid()))
    )
  );
revoke all on public.equipment_compatibility_reviews from anon, authenticated;
grant select on public.equipment_compatibility_reviews to anon, authenticated;

create table if not exists public.equipment_spec_evidence (
  id uuid primary key default gen_random_uuid(),
  equipment_id uuid not null references public.equipment(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  object_path text not null unique check (char_length(object_path) between 1 and 1024),
  submitted_at timestamptz not null default now()
);
create index if not exists equipment_spec_evidence_equipment_id_idx on public.equipment_spec_evidence(equipment_id);
alter table public.equipment_spec_evidence enable row level security;
create policy "Owners can read their private specification evidence metadata"
  on public.equipment_spec_evidence for select to authenticated using (owner_id = (select auth.uid()));
revoke all on public.equipment_spec_evidence from anon, authenticated;
grant select on public.equipment_spec_evidence to authenticated;

insert into public.equipment_compatibility_reviews (equipment_id, status)
select e.id, 'unverified' from public.equipment e
on conflict (equipment_id) do nothing;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('equipment-spec-evidence','equipment-spec-evidence',false,5242880,array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do update set name=excluded.name, public=false, file_size_limit=excluded.file_size_limit, allowed_mime_types=excluded.allowed_mime_types;

create or replace function public.delete_equipment_spec_evidence_object()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  delete from storage.objects
  where bucket_id = 'equipment-spec-evidence' and name = old.object_path;
  return old;
end;
$function$;
revoke all on function public.delete_equipment_spec_evidence_object() from public, anon, authenticated;
create trigger equipment_spec_evidence_cleanup_object
  after delete on public.equipment_spec_evidence for each row
  execute function public.delete_equipment_spec_evidence_object();

create policy "Owners read private equipment specification evidence"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'equipment-spec-evidence'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and array_length(storage.foldername(name),1) = 2
    and exists (
      select 1 from public.equipment e
      where e.id::text = (storage.foldername(name))[2] and e.owner_id = (select auth.uid())
    )
  );
create policy "Owners upload private equipment specification evidence"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'equipment-spec-evidence'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and array_length(storage.foldername(name),1) = 2
    and exists (
      select 1 from public.equipment e
      where e.id::text = (storage.foldername(name))[2] and e.owner_id = (select auth.uid())
    )
  );

create or replace function public.submit_equipment_spec_evidence(p_equipment_id uuid, p_object_path text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_id uuid;
  v_prefix text;
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  if p_equipment_id is null or p_object_path is null or char_length(p_object_path) > 1024 then
    raise exception 'A valid equipment ID and evidence file are required';
  end if;
  if not exists (
    select 1 from public.equipment e where e.id = p_equipment_id and e.owner_id = v_user
  ) then raise exception 'You can submit evidence only for your own equipment'; end if;
  v_prefix := v_user::text || '/' || p_equipment_id::text || '/';
  if left(p_object_path, char_length(v_prefix)) <> v_prefix
     or split_part(p_object_path,'/',3) = ''
     or split_part(p_object_path,'/',4) <> '' then
    raise exception 'Evidence path must be inside your private equipment folder';
  end if;
  if not exists (
    select 1 from storage.objects o
    where o.bucket_id = 'equipment-spec-evidence' and o.name = p_object_path
  ) then raise exception 'Upload the evidence file before submitting it'; end if;

  insert into public.equipment_spec_evidence (equipment_id, owner_id, object_path)
  values (p_equipment_id, v_user, p_object_path)
  returning id into v_id;

  insert into public.equipment_compatibility_reviews (equipment_id, status, reviewed_at, updated_at)
  values (p_equipment_id, 'pending', null, now())
  on conflict (equipment_id) do update
    set status = 'pending', reviewed_at = null, updated_at = now();
  return v_id;
end;
$function$;
revoke all on function public.submit_equipment_spec_evidence(uuid,text) from public, anon, authenticated;
grant execute on function public.submit_equipment_spec_evidence(uuid,text) to authenticated;

create or replace function public.reset_equipment_compatibility_review()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.category is distinct from old.category
     or new.equipment_role is distinct from old.equipment_role
     or new.implement_type is distinct from old.implement_type
     or new.horsepower is distinct from old.horsepower
     or new.hitch_type is distinct from old.hitch_type
     or new.pto_rpm is distinct from old.pto_rpm
     or new.hydraulic_capacity_lpm is distinct from old.hydraulic_capacity_lpm
     or new.min_tractor_hp is distinct from old.min_tractor_hp
     or new.max_tractor_hp is distinct from old.max_tractor_hp
     or new.required_pto_rpm is distinct from old.required_pto_rpm
     or new.required_hydraulic_lpm is distinct from old.required_hydraulic_lpm
     or new.compatibility_notes is distinct from old.compatibility_notes then
    insert into public.equipment_compatibility_reviews (equipment_id, status, reviewed_at, updated_at)
    values (new.id, 'unverified', null, now())
    on conflict (equipment_id) do update
      set status = 'unverified', reviewed_at = null, updated_at = now();
  end if;
  return new;
end;
$function$;
revoke all on function public.reset_equipment_compatibility_review() from public, anon, authenticated;
create trigger equipment_compatibility_changes_reset_review
  after update of category, equipment_role, implement_type, horsepower, hitch_type, pto_rpm, hydraulic_capacity_lpm,
    min_tractor_hp, max_tractor_hp, required_pto_rpm, required_hydraulic_lpm, compatibility_notes
  on public.equipment for each row execute function public.reset_equipment_compatibility_review();

create or replace function public.get_equipment_availability(p_equipment_ids uuid[], p_preferred_date date)
returns table(equipment_id uuid, is_available boolean)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_count integer;
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  if p_preferred_date is null or p_preferred_date < current_date or p_preferred_date > current_date + 120 then
    raise exception 'Choose a date from today through the next 120 days';
  end if;
  if p_equipment_ids is null or cardinality(p_equipment_ids) < 1 or cardinality(p_equipment_ids) > 50 then
    raise exception 'Check between 1 and 50 equipment listings at a time';
  end if;
  select count(distinct x) into v_count from unnest(p_equipment_ids) as x where x is not null;
  if v_count <> cardinality(p_equipment_ids) then raise exception 'Equipment IDs must be unique and valid'; end if;

  return query
    select e.id,
      (e.available and not exists (
        select 1 from public.booking_requests br
        where br.equipment_id = e.id
          and br.preferred_date = p_preferred_date
          and br.status in ('pending','accepted')
      )) as is_available
    from public.equipment e
    where e.id = any(p_equipment_ids);
end;
$function$;
revoke all on function public.get_equipment_availability(uuid[],date) from public, anon, authenticated;
grant execute on function public.get_equipment_availability(uuid[],date) to authenticated;

create or replace function public.create_equipment_bundle(
  p_equipment_ids uuid[],
  p_preferred_date date,
  p_acres numeric,
  p_village text,
  p_task text,
  p_notes text,
  p_allow_unverified boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_task text := lower(trim(coalesce(p_task,'')));
  v_id uuid;
  v_bundle_id uuid;
  v_request_id uuid;
  v_item_count integer;
  v_tractor_count integer;
  v_implement_count integer;
  v_tractor public.equipment%rowtype;
  v_equipment public.equipment%rowtype;
  v_unknown boolean := false;
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  if p_equipment_ids is null or cardinality(p_equipment_ids) < 2 or cardinality(p_equipment_ids) > 5 then
    raise exception 'Select one tractor and one to four implements';
  end if;
  select count(distinct x) into v_item_count from unnest(p_equipment_ids) as x where x is not null;
  if v_item_count <> cardinality(p_equipment_ids) then raise exception 'Equipment IDs must be unique and valid'; end if;
  if p_preferred_date is null or p_preferred_date < current_date or p_preferred_date > current_date + 120 then
    raise exception 'Choose a date from today through the next 120 days';
  end if;
  if p_acres is null or p_acres <= 0 or p_acres > 10000 then raise exception 'Enter acreage between 0 and 10000'; end if;
  if nullif(trim(p_village),'') is null or char_length(trim(p_village)) > 120 then raise exception 'Enter a valid field village'; end if;
  if p_notes is not null and char_length(p_notes) > 1000 then raise exception 'Notes must be 1000 characters or fewer'; end if;
  if v_task not in ('general','ploughing','tilling','seeding','harvesting','spraying','baling','other') then raise exception 'Choose a valid farm task'; end if;

  perform 1 from public.equipment e where e.id = any(p_equipment_ids) order by e.id for update;
  select count(*) into v_item_count from public.equipment e where e.id = any(p_equipment_ids) and e.available = true;
  if v_item_count <> cardinality(p_equipment_ids) then raise exception 'One or more selected listings are no longer available'; end if;
  if exists (select 1 from public.equipment e where e.id = any(p_equipment_ids) and e.owner_id = v_user) then
    raise exception 'You cannot bundle your own equipment';
  end if;
  select count(*) filter (where e.equipment_role = 'tractor'),
         count(*) filter (where e.equipment_role = 'implement')
    into v_tractor_count, v_implement_count
    from public.equipment e where e.id = any(p_equipment_ids);
  if v_tractor_count <> 1 or v_implement_count < 1 or v_tractor_count + v_implement_count <> cardinality(p_equipment_ids) then
    raise exception 'Select exactly one tractor and one or more implement listings';
  end if;
  select e.* into v_tractor from public.equipment e where e.id = any(p_equipment_ids) and e.equipment_role = 'tractor';

  if v_task = 'ploughing' and exists (select 1 from public.equipment e where e.id = any(p_equipment_ids) and e.equipment_role='implement' and coalesce(e.implement_type,e.category) not in ('Plough')) then raise exception 'Ploughing bundles must use plough listings'; end if;
  if v_task = 'tilling' and exists (select 1 from public.equipment e where e.id = any(p_equipment_ids) and e.equipment_role='implement' and coalesce(e.implement_type,e.category) not in ('Rotavator','Rotary tiller','Disc harrow')) then raise exception 'Tilling bundles must use tillage implement listings'; end if;
  if v_task = 'seeding' and exists (select 1 from public.equipment e where e.id = any(p_equipment_ids) and e.equipment_role='implement' and coalesce(e.implement_type,e.category) <> 'Seed drill') then raise exception 'Seeding bundles must use seed drill listings'; end if;
  if v_task = 'harvesting' and exists (select 1 from public.equipment e where e.id = any(p_equipment_ids) and e.equipment_role='implement' and coalesce(e.implement_type,e.category) <> 'Harvester') then raise exception 'Harvesting bundles must use harvester listings'; end if;
  if v_task = 'spraying' and exists (select 1 from public.equipment e where e.id = any(p_equipment_ids) and e.equipment_role='implement' and coalesce(e.implement_type,e.category) <> 'Sprayer') then raise exception 'Spraying bundles must use sprayer listings'; end if;
  if v_task = 'baling' and exists (select 1 from public.equipment e where e.id = any(p_equipment_ids) and e.equipment_role='implement' and coalesce(e.implement_type,e.category) <> 'Baler') then raise exception 'Baling bundles must use baler listings'; end if;

  foreach v_id in array p_equipment_ids loop
    select e.* into v_equipment from public.equipment e where e.id = v_id;

    if not exists (
      select 1 from public.equipment_compatibility_reviews r
      where r.equipment_id = v_id and r.status = 'approved' and r.reviewed_at is not null
    ) then v_unknown := true; end if;

    if v_equipment.equipment_role = 'implement' then
      if v_tractor.horsepower is null or v_equipment.min_tractor_hp is null then
        v_unknown := true;
      elsif v_tractor.horsepower < v_equipment.min_tractor_hp then
        raise exception 'Tractor horsepower is below an implement minimum';
      end if;
      if v_tractor.horsepower is not null and v_equipment.max_tractor_hp is not null and v_tractor.horsepower > v_equipment.max_tractor_hp then
        raise exception 'Tractor horsepower is above an implement maximum';
      end if;

      if v_tractor.hitch_type is null or v_tractor.hitch_type = 'unknown'
         or v_equipment.hitch_type is null or v_equipment.hitch_type = 'unknown' then
        v_unknown := true;
      elsif v_tractor.hitch_type <> v_equipment.hitch_type then
        raise exception 'Tractor hitch does not match an implement hitch';
      end if;

      if v_equipment.required_pto_rpm is null or v_tractor.pto_rpm is null then
        v_unknown := true;
      elsif v_tractor.pto_rpm <> v_equipment.required_pto_rpm then
        raise exception 'Tractor PTO speed does not match an implement requirement';
      end if;

      if v_equipment.required_hydraulic_lpm is null or v_tractor.hydraulic_capacity_lpm is null then
        v_unknown := true;
      elsif v_tractor.hydraulic_capacity_lpm < v_equipment.required_hydraulic_lpm then
        raise exception 'Tractor hydraulic flow is below an implement requirement';
      end if;
    end if;
  end loop;

  if v_unknown and coalesce(p_allow_unverified,false) is not true then
    raise exception 'Some specifications are missing or not manually reviewed. Confirm them and acknowledge before requesting this bundle.';
  end if;

  insert into public.booking_bundles (farmer_id,preferred_date,acres,village,task,item_count)
  values (v_user,p_preferred_date,round(p_acres,2),trim(p_village),v_task,cardinality(p_equipment_ids))
  returning id into v_bundle_id;

  foreach v_id in array p_equipment_ids loop
    select e.* into v_equipment from public.equipment e where e.id = v_id;
    v_request_id := public.create_booking_request(v_id,p_preferred_date,p_acres,p_village,p_notes);
    update public.booking_requests br
      set bundle_id = v_bundle_id,
          requested_rate_snapshot = v_equipment.rate,
          requested_rate_unit_snapshot = v_equipment.rate_unit
      where br.id = v_request_id and br.farmer_id = v_user;
    if not found then raise exception 'Could not attach a request to the equipment bundle'; end if;
  end loop;

  return v_bundle_id;
end;
$function$;
revoke all on function public.create_equipment_bundle(uuid[],date,numeric,text,text,text,boolean) from public, anon, authenticated;
grant execute on function public.create_equipment_bundle(uuid[],date,numeric,text,text,text,boolean) to authenticated;

commit;

-- Follow-up indexes for smart tractor/implement bundle workflows.
-- This migration is safe to reapply.
begin;
create index if not exists booking_bundles_farmer_id_idx
  on public.booking_bundles(farmer_id);
create index if not exists equipment_spec_evidence_owner_id_idx
  on public.equipment_spec_evidence(owner_id);
commit;


-- Operations features for the AgriShare starter schema.
-- AgriShare operations: private maintenance history, booking progress, and quoted units.
-- Additive only. Existing marketplace rows are preserved; no sample data is created.
begin;

alter table public.booking_requests
  add column if not exists requested_quantity numeric(10,2);

do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conname = 'booking_requests_requested_quantity_check'
      and conrelid = 'public.booking_requests'::regclass
  ) then
    alter table public.booking_requests
      add constraint booking_requests_requested_quantity_check
      check (requested_quantity is null or (requested_quantity > 0 and requested_quantity <= 100000));
  end if;
end
$$;

grant select (requested_quantity) on public.booking_requests to authenticated;

-- Keep owner-entered maintenance notes and operating hours private. Public rows
-- expose only dates and service categories when an owner explicitly shares them.
create table if not exists public.equipment_maintenance_records (
  id uuid primary key default gen_random_uuid(),
  equipment_id uuid not null references public.equipment(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  performed_on date not null,
  service_type text not null check (service_type in ('service','repair','inspection','other')),
  next_due_on date,
  shared_with_renters boolean not null default false,
  created_at timestamptz not null default now(),
  check (next_due_on is null or next_due_on >= performed_on)
);
create index if not exists equipment_maintenance_records_equipment_date_idx
  on public.equipment_maintenance_records(equipment_id, performed_on desc);
create index if not exists equipment_maintenance_records_owner_date_idx
  on public.equipment_maintenance_records(owner_id, performed_on desc);
alter table public.equipment_maintenance_records enable row level security;
revoke all on table public.equipment_maintenance_records from public, anon, authenticated;
grant select (id, equipment_id, performed_on, service_type, next_due_on, shared_with_renters, created_at)
  on public.equipment_maintenance_records to anon, authenticated;
grant insert (equipment_id, owner_id, performed_on, service_type, next_due_on, shared_with_renters)
  on public.equipment_maintenance_records to authenticated;
grant delete on public.equipment_maintenance_records to authenticated;

drop policy if exists "Shared maintenance dates are public for active listings" on public.equipment_maintenance_records;
create policy "Shared maintenance dates are public for active listings"
  on public.equipment_maintenance_records for select to anon
  using (
    shared_with_renters
    and exists (
      select 1 from public.equipment e
      where e.id = equipment_id and e.available = true
    )
  );
drop policy if exists "Owners and renters can read shared maintenance dates" on public.equipment_maintenance_records;
create policy "Owners and renters can read shared maintenance dates"
  on public.equipment_maintenance_records for select to authenticated
  using (
    owner_id = (select auth.uid())
    or (
      shared_with_renters
      and exists (
        select 1 from public.equipment e
        where e.id = equipment_id and (e.available = true or e.owner_id = (select auth.uid()))
      )
    )
  );
drop policy if exists "Equipment owners can add maintenance records" on public.equipment_maintenance_records;
create policy "Equipment owners can add maintenance records"
  on public.equipment_maintenance_records for insert to authenticated
  with check (
    owner_id = (select auth.uid())
    and exists (
      select 1 from public.equipment e
      where e.id = equipment_id and e.owner_id = (select auth.uid())
    )
  );
drop policy if exists "Equipment owners can delete maintenance records" on public.equipment_maintenance_records;
create policy "Equipment owners can delete maintenance records"
  on public.equipment_maintenance_records for delete to authenticated
  using (
    owner_id = (select auth.uid())
    and exists (
      select 1 from public.equipment e
      where e.id = equipment_id and e.owner_id = (select auth.uid())
    )
  );

create table if not exists public.equipment_maintenance_details (
  record_id uuid primary key references public.equipment_maintenance_records(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  operating_hours numeric(10,1) check (operating_hours is null or operating_hours >= 0),
  notes text not null default '' check (char_length(notes) <= 1000)
);
create index if not exists equipment_maintenance_details_owner_idx
  on public.equipment_maintenance_details(owner_id);
alter table public.equipment_maintenance_details enable row level security;
revoke all on table public.equipment_maintenance_details from public, anon, authenticated;
grant select (record_id, operating_hours, notes) on public.equipment_maintenance_details to authenticated;
grant insert (record_id, owner_id, operating_hours, notes) on public.equipment_maintenance_details to authenticated;
grant update (operating_hours, notes) on public.equipment_maintenance_details to authenticated;
grant delete on public.equipment_maintenance_details to authenticated;

drop policy if exists "Owners read their private maintenance details" on public.equipment_maintenance_details;
create policy "Owners read their private maintenance details"
  on public.equipment_maintenance_details for select to authenticated
  using (
    owner_id = (select auth.uid())
    and exists (
      select 1 from public.equipment_maintenance_records mr
      join public.equipment e on e.id = mr.equipment_id
      where mr.id = record_id and e.owner_id = (select auth.uid())
    )
  );
drop policy if exists "Owners add private maintenance details" on public.equipment_maintenance_details;
create policy "Owners add private maintenance details"
  on public.equipment_maintenance_details for insert to authenticated
  with check (
    owner_id = (select auth.uid())
    and exists (
      select 1 from public.equipment_maintenance_records mr
      join public.equipment e on e.id = mr.equipment_id
      where mr.id = record_id and mr.owner_id = (select auth.uid()) and e.owner_id = (select auth.uid())
    )
  );
drop policy if exists "Owners update private maintenance details" on public.equipment_maintenance_details;
create policy "Owners update private maintenance details"
  on public.equipment_maintenance_details for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
drop policy if exists "Owners delete private maintenance details" on public.equipment_maintenance_details;
create policy "Owners delete private maintenance details"
  on public.equipment_maintenance_details for delete to authenticated
  using (owner_id = (select auth.uid()));

-- Only booking participants can see progress. Only the equipment owner can
-- set the manual stage; this stores no live or precise location.
create table if not exists public.booking_progress_updates (
  booking_request_id uuid primary key references public.booking_requests(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  stage text not null check (stage in ('travelling','work_started','completed')),
  updated_at timestamptz not null default now()
);
alter table public.booking_progress_updates enable row level security;
revoke all on table public.booking_progress_updates from public, anon, authenticated;
grant select on public.booking_progress_updates to authenticated;
grant insert (booking_request_id, owner_id, stage) on public.booking_progress_updates to authenticated;
grant update (stage) on public.booking_progress_updates to authenticated;

drop policy if exists "Booking participants read progress" on public.booking_progress_updates;
create policy "Booking participants read progress"
  on public.booking_progress_updates for select to authenticated
  using (
    exists (
      select 1 from public.booking_requests br
      where br.id = booking_request_id
        and (
          br.farmer_id = (select auth.uid())
          or exists (
            select 1 from public.equipment e
            where e.id = br.equipment_id and e.owner_id = (select auth.uid())
          )
        )
    )
  );
drop policy if exists "Equipment owners create booking progress" on public.booking_progress_updates;
create policy "Equipment owners create booking progress"
  on public.booking_progress_updates for insert to authenticated
  with check (
    owner_id = (select auth.uid())
    and exists (
      select 1 from public.booking_requests br
      join public.equipment e on e.id = br.equipment_id
      where br.id = booking_request_id
        and e.owner_id = (select auth.uid())
        and br.status in ('accepted','completed')
    )
  );
drop policy if exists "Equipment owners update booking progress" on public.booking_progress_updates;
create policy "Equipment owners update booking progress"
  on public.booking_progress_updates for update to authenticated
  using (
    owner_id = (select auth.uid())
    and exists (
      select 1 from public.booking_requests br
      join public.equipment e on e.id = br.equipment_id
      where br.id = booking_request_id
        and e.owner_id = (select auth.uid())
        and br.status in ('accepted','completed')
    )
  )
  with check (owner_id = (select auth.uid()));

create or replace function private.set_booking_progress_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  new.updated_at := pg_catalog.now();
  return new;
end;
$function$;
revoke all on function private.set_booking_progress_updated_at() from public, anon, authenticated;
drop trigger if exists booking_progress_updated_at on public.booking_progress_updates;
create trigger booking_progress_updated_at
  before update on public.booking_progress_updates
  for each row execute function private.set_booking_progress_updated_at();

create or replace function private.create_booking_request_with_quote(
  p_equipment_id uuid,
  p_preferred_date date,
  p_acres numeric,
  p_village text,
  p_notes text,
  p_requested_quantity numeric
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_equipment public.equipment%rowtype;
  v_quantity numeric(10,2);
  v_id uuid;
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  if p_preferred_date is null or p_preferred_date < current_date or p_preferred_date > current_date + 120 then
    raise exception 'Choose a date from today through the next 120 days';
  end if;
  if p_acres is null or p_acres <= 0 or p_acres > 10000 then raise exception 'Enter acreage between 0 and 10000'; end if;
  if nullif(pg_catalog.btrim(p_village),'') is null or pg_catalog.char_length(pg_catalog.btrim(p_village)) > 120 then
    raise exception 'Enter a valid service location';
  end if;
  if p_notes is not null and pg_catalog.char_length(p_notes) > 1000 then raise exception 'Notes must be 1000 characters or fewer'; end if;

  select e.* into v_equipment
  from public.equipment e
  where e.id = p_equipment_id
  for update;
  if not found or not v_equipment.available then raise exception 'This equipment is no longer available'; end if;
  if v_equipment.owner_id = v_user then raise exception 'You cannot book your own equipment'; end if;
  if v_equipment.rate_unit not in ('acre','hour','trip','day') then raise exception 'This listing has an unsupported rate unit'; end if;

  if v_equipment.rate_unit = 'acre' then
    v_quantity := pg_catalog.round(p_acres,2);
  else
    if p_requested_quantity is null or p_requested_quantity <= 0 or p_requested_quantity > 100000 then
      raise exception 'Enter a valid quantity for the listed rate unit';
    end if;
    v_quantity := pg_catalog.round(p_requested_quantity,2);
  end if;

  insert into public.booking_requests (
    farmer_id, equipment_id, preferred_date, acres, village, notes,
    requested_rate_snapshot, requested_rate_unit_snapshot, requested_quantity
  )
  values (
    v_user, p_equipment_id, p_preferred_date, pg_catalog.round(p_acres,2),
    pg_catalog.btrim(p_village), nullif(pg_catalog.btrim(p_notes),''),
    v_equipment.rate, v_equipment.rate_unit, v_quantity
  )
  returning id into v_id;

  insert into public.user_notifications(user_id,kind,title,body,related_id)
  values (v_equipment.owner_id,'booking','New booking request',v_equipment.name||' · '||p_preferred_date::text,v_id);

  return v_id;
end;
$function$;
revoke all on function private.create_booking_request_with_quote(uuid,date,numeric,text,text,numeric) from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.create_booking_request_with_quote(uuid,date,numeric,text,text,numeric) to authenticated;

create or replace function public.create_booking_request_with_quote(
  p_equipment_id uuid,
  p_preferred_date date,
  p_acres numeric,
  p_village text,
  p_notes text,
  p_requested_quantity numeric
)
returns uuid
language sql
security invoker
set search_path = ''
as $function$
  select private.create_booking_request_with_quote(
    p_equipment_id,p_preferred_date,p_acres,p_village,p_notes,p_requested_quantity
  );
$function$;
revoke all on function public.create_booking_request_with_quote(uuid,date,numeric,text,text,numeric) from public, anon, authenticated;
grant execute on function public.create_booking_request_with_quote(uuid,date,numeric,text,text,numeric) to authenticated;

commit;


-- Follow-up index for the booking progress owner foreign key.
-- Add the owner foreign-key index for progress-stage retention and cleanup.
begin;
create index if not exists booking_progress_updates_owner_id_idx
  on public.booking_progress_updates(owner_id);
commit;
