-- AgriShare Supabase starter schema
-- Run in a NEW Supabase project after reviewing the policies below.
-- This is a foundation, not a complete production booking system.
create extension if not exists pgcrypto;

create table if not exists public.equipment (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 120),
  category text not null check (category in ('Tractor','Rotavator','Harvester','Transplanter','Sprayer','Other')),
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
grant insert (owner_id, name, category, description, rate, rate_unit, village, service_area, image_url, available, equipment_role, horsepower, hitch_type, pto_rpm, hydraulic_capacity_lpm, min_tractor_hp, max_tractor_hp, required_pto_rpm, required_hydraulic_lpm, compatibility_notes)
  on table public.equipment to authenticated;
grant update (name, category, description, rate, rate_unit, village, service_area, image_url, available, equipment_role, horsepower, hitch_type, pto_rpm, hydraulic_capacity_lpm, min_tractor_hp, max_tractor_hp, required_pto_rpm, required_hydraulic_lpm, compatibility_notes)
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
set search_path = public, private, pg_temp
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
