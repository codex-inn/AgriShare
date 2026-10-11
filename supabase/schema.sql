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
create policy "Organizers can update their groups"
  on public.group_bookings for update to authenticated
  using (auth.uid() = organizer_id) with check (auth.uid() = organizer_id);
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
create policy "Farmers can edit their own membership"
  on public.group_members for update to authenticated
  using (auth.uid() = farmer_id) with check (auth.uid() = farmer_id);
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
create policy "Farmers can cancel their own pending requests"
  on public.booking_requests for update to authenticated
  using (auth.uid() = farmer_id and status = 'pending')
  with check (auth.uid() = farmer_id and status in ('pending','cancelled'));
create policy "Equipment owners can read booking requests"
  on public.booking_requests for select to authenticated
  using (exists (
    select 1 from public.equipment e
    where e.id = equipment_id and e.owner_id = auth.uid()
  ));
create policy "Equipment owners can update booking status"
  on public.booking_requests for update to authenticated
  using (exists (
    select 1 from public.equipment e
    where e.id = equipment_id and e.owner_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.equipment e
    where e.id = equipment_id and e.owner_id = auth.uid()
  ));

-- Before launch, add server-side validation for status transitions, group capacity,
-- preventing overbooking, image storage policies, abuse controls, and audited owner verification.
