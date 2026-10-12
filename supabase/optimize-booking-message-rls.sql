-- AgriShare booking-message RLS performance update
-- Applied to Supabase as migration 20261012183551.
-- Preserves policy roles and authorization predicates; wraps auth.uid() so
-- PostgreSQL can evaluate the stable user ID once per statement.

ALTER POLICY "Booking participants can read messages"
  ON public.booking_messages
  USING (
    ((SELECT auth.uid()) = sender_id)
    OR ((SELECT auth.uid()) = recipient_id)
  );

ALTER POLICY "Booking participants can send messages"
  ON public.booking_messages
  WITH CHECK (
    (SELECT auth.uid()) = sender_id
    AND EXISTS (
      SELECT 1
      FROM public.booking_requests br
      JOIN public.equipment e ON e.id = br.equipment_id
      WHERE br.id = booking_messages.booking_request_id
        AND (
          (br.farmer_id = booking_messages.sender_id AND e.owner_id = booking_messages.recipient_id)
          OR (e.owner_id = booking_messages.sender_id AND br.farmer_id = booking_messages.recipient_id)
        )
        AND br.status = ANY (ARRAY['pending'::text, 'accepted'::text])
    )
  );

ALTER POLICY "Recipients can mark messages read"
  ON public.booking_messages
  USING ((SELECT auth.uid()) = recipient_id)
  WITH CHECK ((SELECT auth.uid()) = recipient_id);
