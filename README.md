# AgriShare — Shared Machinery, Stronger Farms

AgriShare is a mobile-first agricultural machinery discovery and group-booking web app for local farming communities.

- **Live site:** https://codex-inn.github.io/AgriShare/
- **Repository:** https://github.com/codex-inn/AgriShare
- **Backend:** Supabase project `xsrrpjkvlodcvlqawrui`
- **Hosting:** GitHub Pages from `main` via `.github/workflows/pages.yml`

## Current app features

- Responsive landing page, mobile navigation, equipment search, category and rate filters.
- Username + password sign-in through Supabase Auth, with account creation via the `username-signup` Edge Function.
- Live equipment listings from Supabase and authenticated listing creation.
- Booking requests with date, acreage, field location and explicit consent to share contact details with the relevant owner.
- Owner accept/decline and farmer cancellation through database RPCs.
- Group booking creation and joining, with public aggregate acreage progress.
- PWA manifest and service-worker shell caching.

## Data integrity

The marketplace now starts with empty lists and only displays equipment and groups loaded from Supabase. If the cloud read fails, those lists are cleared rather than showing cached demo offers. This prevents farmers from mistaking sample machinery for real, available equipment.

The production tables were checked on 2026-10-12 and contained zero equipment, group bookings, group members and booking requests. The site will remain empty until real users publish listings or create groups. No fabricated production records were added.

## Backend security and limits

The production project has row-level security enabled on the core tables. Booking status transitions and group joining use database functions; group joining calls a private transactional core that checks the authenticated user, group status and capacity while locking the group row. Public group progress is aggregated without exposing individual member records. The `username-signup` Edge Function is active.

This project is **not certified for commercial production**. Before real-world transactions, run end-to-end tests with two real, consenting accounts and review provider verification/moderation, privacy and terms pages, abuse reporting, support, backups and dispute handling. The database `verified` flag alone is not proof of provider identity. Payments are not implemented.

## Supabase files

- `supabase/schema.sql` is a **starter schema for a new development project**, not a replayable production migration and not a complete description of the deployed database.
- `supabase/SETUP.md` describes the connection and setup precautions.
- `supabase/functions/username-signup/index.ts` contains the signup function source.
- Production database changes should remain versioned in Supabase migrations.

**Do not run the starter schema over the existing production project as a reset.** It contains baseline policies and can diverge from the hardened production migrations.

## Key safety

Only the Supabase project URL and publishable/anon key belong in browser code. Never commit a service-role/secret key, database password or private connection string. Do not expose farmer phone numbers in public equipment listings.

## Deployment

A push to `main` triggers the GitHub Pages workflow. Check the repository's Actions tab for the latest Pages deployment before assuming a change is live.
