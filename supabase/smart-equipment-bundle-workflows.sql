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
