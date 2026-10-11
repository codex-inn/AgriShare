# AgriShare — Shared Machinery, Stronger Farms

A mobile-first agricultural machinery discovery and group-booking prototype for local farming communities. The visual language follows the clean, green, institutional feel of the user's previous GreenFarm and TNAU RAWE projects.

**Live repository:** https://github.com/codex-inn/AgriShare  
**GitHub Pages URL after enabling Pages:** https://codex-inn.github.io/AgriShare/

## Current features
- Responsive college-themed landing page for Tamil Nadu Agricultural University, AC&RI Vazhavachanur context.
- Search and filter sample equipment by name, category and rate.
- Demo booking request form with field area, preferred date and contact details.
- Group booking creation, acreage progress and join flow.
- Demo equipment listing form.
- Mobile navigation, modal forms, accessible labels and keyboard dismissal.
- Browser-local persistence using `localStorage`.
- PWA manifest and service worker shell cache.
- Clear demo notices: no real booking, notifications, identity checks, payments or shared cloud records are active.

## Publish with GitHub Pages
1. Open repository **Settings → Pages**.
2. Under **Build and deployment**, choose **Deploy from a branch**.
3. Select branch `main` and folder `/ (root)`, then Save.
4. Wait for the deployment action to finish. The site should appear at the URL above.

## Important demo limitations
Browser-local data exists only on the same device/browser and is not shared with other users. The sample machinery and groups are illustrative, not verified offers. Confirm machine availability, rates, service location, and booking directly with the owner. Do not collect or store sensitive personal information in this prototype.

## Connect a real Supabase backend (next step)
A starter schema is in `supabase/schema.sql`. Create a Supabase project, run that SQL in SQL Editor, then configure a client integration with your project URL and anon/publishable key. Never put a service-role key in browser code. Before public launch, implement authentication, role-based permissions, validation, storage rules, contact-consent, spam protection, provider verification, booking status transitions, and privacy/legal pages. Do not enable public write access to owner or booking records without suitable access controls.

## Project credits
Institution context: Tamil Nadu Agricultural University, Agricultural College & Research Institute, Vazhavachanur, Tiruvannamalai. Student/team names remain placeholders until confirmed.
