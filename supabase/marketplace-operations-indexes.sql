-- Add the owner foreign-key index for progress-stage retention and cleanup.
begin;
create index if not exists booking_progress_updates_owner_id_idx
  on public.booking_progress_updates(owner_id);
commit;
