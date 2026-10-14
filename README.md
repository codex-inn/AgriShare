# AgriShare — Shared Machinery, Stronger Farms

- **Live site:** https://codex-inn.github.io/AgriShare/
- **Repository:** https://github.com/codex-inn/AgriShare
- **Backend:** Supabase project `xsrrpjkvlodcvlqawrui`
- **Hosting:** GitHub Pages from `main`

## Project structure

- `index.html` — responsive farmer app, marketplace, bookings, group bookings, profile, weather and crop-analysis screens.
- `manifest.json`, `agri-icon.svg`, `sw.js` — installable PWA metadata, app icon and shell caching.
- `supabase/functions/username-signup/index.ts` — username signup Edge Function source.
- `supabase/schema.sql` — starter schema for a **new development project only**; not a production reset script.
- `supabase/production-readiness-workflows.sql` — one-time migration for existing projects; adds booking-date protection, private reviews and a support request queue.
- `supabase/production-readiness-indexes.sql` — adds indexes for new review and support foreign keys.
- `supabase/smart-equipment-bundle-workflows.sql` — additive migration adding a separate implement type, task-aware group requests, atomic tractor/implement bundle requests, date availability checks and private specification evidence.
- `supabase/smart-equipment-bundle-indexes.sql` — small follow-up migration indexing the bundle and evidence owner foreign keys.
- `supabase/marketplace-operations-workflows.sql` — additive maintenance history, booking-progress updates, quoted quantities and secure price snapshots.
- `supabase/SETUP.md` — backend setup and deployment precautions.
- `privacy.html`, `terms.html` — prototype privacy notice and use terms.
- `scripts/validate-project.mjs` — static integrity checks for required screens and inline JavaScript syntax.
- `.github/workflows/validate.yml` — validation runs on pull requests and pushes.
- `.github/workflows/pages.yml` — GitHub Pages deployment.

## Live features and limitations

- Username/password authentication uses Supabase Auth and the `username-signup` Edge Function.
- Equipment listings and group bookings are loaded from Supabase. Owners publish their own listings; the app must not seed example equipment into production.
- Booking requests and owner/farmer status changes use Supabase data and database functions.
- Group joining uses the existing transactional database RPC.
- Weather lookup uses Open-Meteo's public geocoding and forecast APIs.
- CropSight analysis requires a deployed HTTPS inference API with trained weights; no predictions are fabricated if it is unavailable.
- Booking messages use a private Supabase table and participant policies; validate the full send/read flow with two real accounts before relying on it.
- Group requests can be filtered by village, farm task and date; farmers choose whether to join, and matching does not reserve a machine.
- Owners can keep maintenance and repair history. Operating hours and notes remain private; only the service date/type/next due date are shared when an owner opts in.
- Owners can manually mark an accepted booking as travelling or work started. Only the booking participants can read progress; the app does not track live location.
- Booking forms calculate a listed-rate estimate for per-acre, per-hour, per-trip or per-day listings when the matching quantity is entered. Receipts and history use saved rates and quantities; estimates are not proof of payment.
- Weather warnings are optional, use a five-day live Open-Meteo forecast, and send only the village/town name after the farmer enables the consent checkbox. Forecasts never cancel or change a booking.
- Tractor/implement recommendations compare owner-entered HP, hitch, PTO and hydraulics. Only manually reviewed matching specs receive the “Compatible” label; unknown data stays “Needs verification,” and mismatches are blocked.
- Bundle booking submits one tractor and up to four implements in a database transaction. Every owner receives a separate request; each owner responds separately, so the bundle is not reserved or confirmed until all agree.
- The app checks same-date availability and rechecks it while creating the bundle. It shows listed rates and computes a combined estimate only when every item is priced per acre; transport, operator charges and discounts are never assumed.
- Owners may submit photos or PDFs of machine specifications to private storage for manual review. Changing technical specs resets the review to unverified. A review is not a safety guarantee.
- Group requests now record the farm task, but they coordinate farmers and do not reserve equipment.
- Active booking requests are limited to one pending/accepted request per equipment item and date at the database level.
- Saved equipment is stored locally per browser and signed-in account; it does not sync across devices or reserve a machine.
- Completed-booking reviews are private to the two participants and are not identity or quality verification.
- Signed-in users can send listing-safety, support and account-deletion requests to a restricted manual review queue.
- The nearby map is a searched regional map, **not a live machine tracker**. Exact equipment coordinates are not currently part of the listing model.
- Payments, automated identity verification, dispute resolution and password recovery/account deletion are not fully implemented. Account deletion requests go to maintainers for manual handling.
- CropSight still needs a deployed, trained inference API. Each photo now requires consent and is sent to the user-configured HTTPS endpoint.

## Data integrity

The production database was checked on 2026-10-14 and contained zero equipment listings, open groups, group members and booking requests. The new operations tables were added without demo records. That may mean there is nothing to display until actual users publish listings. No fabricated production records were added.

If a Supabase read fails, the marketplace should show a clear error/empty state rather than substitute demo listings. Generic illustrations are not evidence that a machine exists or is available.

## Security and setup

- Only the Supabase URL and publishable/anon key belong in browser code. Never commit a service-role key, database password or private connection string.
- Keep RLS enabled. Do not expose farmer phone numbers in public listings. Booking owners see only their own request lines, and the support queue has no client read policy; only project administrators should review it.
- Specification evidence is stored in the private `equipment-spec-evidence` bucket. Only the equipment owner can read the file; project maintainers review it through authenticated project administration. Review status does not prove safe or suitable operation.
- Supabase currently reports leaked-password protection disabled. Enable it in the project Auth security settings before inviting more users.
- `supabase/schema.sql` is a starter schema for a new development project, **not** a replayable production migration. Do not run it over the current production database as a reset.
- Use consenting test accounts to verify signup, single and bundle booking, separate owner responses, cancellation, group joining, evidence privacy and messaging end to end. Production currently has no real equipment listings or booking requests, so the two-account booking flow still needs real user testing.
- Review the privacy notice and terms with appropriate institutional/legal guidance before public commercial use.

## Verify locally

Requires Node.js 20 or later.

```sh
node scripts/validate-project.mjs
```

The validation workflow runs the same static checks on pushes and pull requests. It does not replace browser testing or real Supabase integration tests.
