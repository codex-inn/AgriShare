-- Allow authenticated listing owners to save the equipment compatibility fields
-- already collected by the AgriShare listing form. RLS still restricts inserts to
-- the signed-in owner and updates to the existing owner. Keep verified read-only.
grant insert (
  equipment_role, horsepower, hitch_type, pto_rpm, hydraulic_capacity_lpm,
  min_tractor_hp, max_tractor_hp, required_pto_rpm, required_hydraulic_lpm,
  compatibility_notes
) on table public.equipment to authenticated;

grant update (
  equipment_role, horsepower, hitch_type, pto_rpm, hydraulic_capacity_lpm,
  min_tractor_hp, max_tractor_hp, required_pto_rpm, required_hydraulic_lpm,
  compatibility_notes
) on table public.equipment to authenticated;
