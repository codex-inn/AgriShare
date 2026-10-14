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
