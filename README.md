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
- The nearby map is a searched regional map, **not a live machine tracker**. Exact equipment coordinates are not currently part of the listing model.
- Payments, identity verification, dispute handling and commercial-grade support are not implemented.

## Data integrity

The production database was checked on 2026-10-12 and contained zero equipment listings, open groups, group members and booking requests. That may mean there is nothing to display until actual users publish listings. No fabricated production records were added.

If a Supabase read fails, the marketplace should show a clear error/empty state rather than substitute demo listings. Generic illustrations are not evidence that a machine exists or is available.

## Security and setup

- Only the Supabase URL and publishable/anon key belong in browser code. Never commit a service-role key, database password or private connection string.
- Keep RLS enabled. Do not expose farmer phone numbers in public listings.
- `supabase/schema.sql` is a starter schema for a new development project, **not** a replayable production migration. Do not run it over the current production database as a reset.
- Use consenting test accounts to verify signup, booking, owner response, cancellation, group joining and messaging end to end.
- Review the privacy notice and terms with appropriate institutional/legal guidance before public commercial use.

## Verify locally

Requires Node.js 20 or later.

```sh
node scripts/validate-project.mjs
```

The validation workflow runs the same static checks on pushes and pull requests. It does not replace browser testing or real Supabase integration tests.
