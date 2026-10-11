# AgriShare — Shared Machinery, Stronger Farms

A mobile-first agricultural machinery discovery and group-booking prototype for local farming communities. The visual language follows the clean, green, institutional feel of the user's previous GreenFarm and TNAU RAWE projects.

**Live site:** https://codex-inn.github.io/AgriShare/  
**Repository:** https://github.com/codex-inn/AgriShare

## Current features
- Responsive college-themed landing page for Tamil Nadu Agricultural University, AC&RI Vazhavachanur context.
- Search and filter sample equipment by name, category and rate.
- Demo booking request form with field area and preferred date.
- Group booking creation, acreage progress and join flow.
- Demo equipment listing form.
- Mobile navigation, modal forms, accessible labels and keyboard dismissal.
- Supabase client configured with the supplied public publishable key.
- Email sign-up/sign-in and sign-out.
- Shared equipment listing reads and authenticated listing creation.
- Shared booking requests and group creation/join flows.
- Aggregate group acreage RPC that avoids returning individual membership details.
- PWA manifest and service-worker shell cache.

## Deployment
GitHub Pages deploy workflow: `.github/workflows/pages.yml`. Check its status in the repository's Actions tab.

## Important demo limitations
The frontend code is configured, but the database is not confirmed active until `supabase/schema.sql` has been run in the linked Supabase project. Until the top strip says “Shared database connected,” do not assume forms are live. Any sample listings are illustrative, not verified offers. Group capacity/overbooking still needs a server-side transactional guard before real transactions.

## Supabase backend preparation
- Starter database schema and row-level security policies: `supabase/schema.sql`
- Step-by-step setup and key-safety notes: `supabase/SETUP.md`

The schema is a foundation, not a production security certification. The website frontend is configured for Supabase; verify the live connection by applying the schema and testing with two accounts. Before public launch, implement server-side booking status/capacity validation, storage rules, contact consent, spam protection, provider verification, and privacy/legal pages.

**Key safety:** browser code may use the Supabase Project URL and anon/publishable key only. Never commit or share a service-role/secret key, database password, or private connection string.

## Project credits
Institution context: Tamil Nadu Agricultural University, Agricultural College & Research Institute, Vazhavachanur, Tiruvannamalai. Student/team names remain placeholders until confirmed.
