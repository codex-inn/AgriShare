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
- Browser-local persistence using `localStorage`.
- PWA manifest and service-worker shell cache.
- Clear demo notices: no real booking, notifications, identity checks, payments or shared cloud records are active.

## Deployment
GitHub Pages deploy workflow: `.github/workflows/pages.yml`. Check its status in the repository's Actions tab.

## Important demo limitations
Browser-local data exists only on the same device/browser and is not shared with other users. The sample machinery and groups are illustrative, not verified offers. Confirm machine availability, rates, service location, and booking directly with the owner. Do not collect or store sensitive personal information in this prototype.

## Supabase backend preparation
- Starter database schema and row-level security policies: `supabase/schema.sql`
- Step-by-step setup and key-safety notes: `supabase/SETUP.md`

The schema is a foundation, not a production security certification. The website is **not yet connected** to Supabase; its forms still use browser-local demo data. Before public launch, implement and test authentication, database-backed flows, server-side booking status/capacity validation, storage rules, contact consent, spam protection, provider verification, and privacy/legal pages.

**Key safety:** browser code may use the Supabase Project URL and anon/publishable key only. Never commit or share a service-role/secret key, database password, or private connection string.

## Project credits
Institution context: Tamil Nadu Agricultural University, Agricultural College & Research Institute, Vazhavachanur, Tiruvannamalai. Student/team names remain placeholders until confirmed.
