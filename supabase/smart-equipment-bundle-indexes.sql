-- Follow-up indexes for smart tractor/implement bundle workflows.
-- This migration is safe to reapply.
begin;
create index if not exists booking_bundles_farmer_id_idx
  on public.booking_bundles(farmer_id);
create index if not exists equipment_spec_evidence_owner_id_idx
  on public.equipment_spec_evidence(owner_id);
commit;
