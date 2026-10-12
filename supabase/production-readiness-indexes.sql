-- Index the new foreign keys without changing or deleting marketplace data.
-- These indexes are also included in the new-project starter schema.
create index if not exists booking_reviews_reviewer_created_idx
  on public.booking_reviews(reviewer_id, created_at desc);
create index if not exists support_requests_equipment_id_idx
  on public.support_requests(equipment_id);
