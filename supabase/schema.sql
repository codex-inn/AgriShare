-- AgriShare starter schema for Supabase (PostgreSQL)
-- IMPORTANT: This is a starter only. Run after reviewing your authentication and privacy requirements.
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
  contact_phone text,
  image_url text,
  verified boolean not null default false,
  available boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.group_bookings (
  id uuid primary key default gen_random_uuid(),
  organizer_id uuid not null references auth.users(id) on delete cascade,
  equipment_category text not null,
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

-- Publicly readable listings only; only authenticated owners can manage their own.
create policy "Equipment listings are readable" on public.equipment for select using (true);
create policy "Owners can create equipment listings" on public.equipment for insert to authenticated with check (auth.uid() = owner_id);
create policy "Owners can update own equipment" on public.equipment for update to authenticated using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "Owners can delete own equipment" on public.equipment for delete to authenticated using (auth.uid() = owner_id);

create policy "Open groups are readable" on public.group_bookings for select using (true);
create policy "Authenticated farmers can create groups" on public.group_bookings for insert to authenticated with check (auth.uid() = organizer_id);
create policy "Organizers can update their groups" on public.group_bookings for update to authenticated using (auth.uid() = organizer_id) with check (auth.uid() = organizer_id);
create policy "Organizers can delete their groups" on public.group_bookings for delete to authenticated using (auth.uid() = organizer_id);

create policy "Group members are readable by signed-in users" on public.group_members for select to authenticated using (true);
create policy "Farmers can join as themselves" on public.group_members for insert to authenticated with check (auth.uid() = farmer_id);
create policy "Farmers can edit their own membership" on public.group_members for update to authenticated using (auth.uid() = farmer_id) with check (auth.uid() = farmer_id);
create policy "Farmers can leave their own group" on public.group_members for delete to authenticated using (auth.uid() = farmer_id);

create policy "Farmers can read their own booking requests" on public.booking_requests for select to authenticated using (auth.uid() = farmer_id);
create policy "Farmers can create booking requests" on public.booking_requests for insert to authenticated with check (auth.uid() = farmer_id);
create policy "Farmers can cancel their own pending requests" on public.booking_requests for update to authenticated using (auth.uid() = farmer_id and status = 'pending') with check (auth.uid() = farmer_id and status in ('pending','cancelled'));

-- Owners need to see requests for their equipment; a later production migration should
-- add a carefully tested policy that joins booking_requests to equipment.owner_id.
-- Avoid collecting sensitive data until contact visibility and consent are designed.
