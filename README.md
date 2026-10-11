# AgriShare — Shared Machinery, Stronger Farms

A mobile-first agricultural machinery discovery and group-booking prototype for local farming communities. The visual language follows the clean, green, institutional feel of the user's previous GreenFarm and TNAU RAWE projects.

**Live site:** https://codex-inn.github.io/AgriShare/  
**Repository:** https://github.com/codex-inn/AgriShare

## Current features
- Responsive college-themed landing page for Tamil Nadu Agricultural University, AC&RI Vazhavachanur context.
- Search and filter sample equipment by name, category and rate.
- Booking request submission with field area, preferred date, and explicit contact-sharing consent.
- Group booking creation, acreage progress and join flow.
- Authenticated equipment listing form.
- Mobile navigation, modal forms, accessible labels and keyboard dismissal.
- Supabase client configured with the supplied public publishable key.
- Username + password sign-up/sign-in and sign-out (email address is not requested in the interface).
- Shared equipment listing reads and authenticated listing creation.
- Shared booking requests and group creation/join flows.
- Aggregate group acreage RPC that avoids returning individual membership details.
- PWA manifest and service-worker shell cache.

## Deployment
GitHub Pages deploy workflow: `.github/workflows/pages.yml`. Check its status in the repository's Actions tab.

## Current status and limitations
The Supabase client and username-only interface are configured, and the website reports whether core listing/group reads succeed. The current prototype maps usernames to non-routable Supabase Auth identities because Supabase Auth does not natively support username sign-in. This is not a substitute for a dedicated username-auth backend. Registration, booking writes, group writes, and listing creation still require real account tests. Any seed cards shown before cloud data loads are illustrative, not verified offers. The app is not yet ready for production transactions: group capacity/overbooking needs a server-side transactional guard; there is no full owner/farmer booking-management dashboard, payment processing, verified-provider workflow, or legal/privacy page.

## Supabase backend preparation
- Starter database schema and row-level security policies: `supabase/schema.sql`
- Step-by-step setup and key-safety notes: `supabase/SETUP.md`

The schema is a foundation, not a production security certification. The website frontend is configured for Supabase. The current reported connection status is a useful smoke test, not proof that every authenticated write and role-specific policy works. Test with two accounts and confirm records in Supabase Table Editor. Before public launch, implement server-side booking status/capacity validation, storage rules, contact consent, spam protection, provider verification, and privacy/legal pages.

**Key safety:** browser code may use the Supabase Project URL and anon/publishable key only. Never commit or share a service-role/secret key, database password, or private connection string.

## Project credits
Institution context: Tamil Nadu Agricultural University, Agricultural College & Research Institute, Vazhavachanur, Tiruvannamalai. Student/team names remain placeholders until confirmed.
