# AgriShare — Supabase setup guide

This guide prepares the database foundation. **The public GitHub Pages site is still a local-storage prototype until the front-end integration is implemented and tested.** Running SQL alone does not connect the website.

## 1. Create a Supabase project
1. Create a project in Supabase and save the database password privately.
2. Open **SQL Editor → New query**.
3. Copy all of `supabase/schema.sql`, run it, and check for errors.
4. Open **Table Editor** and confirm these tables exist: `equipment`, `group_bookings`, `group_members`, and `booking_requests`.

## 2. Configure authentication
1. In **Authentication → URL Configuration**, add your deployed site URL: `https://codex-inn.github.io/AgriShare`.
2. Add the same URL to the allowed redirect URLs (and a local development URL only if needed).
3. Choose sign-in methods and configure email confirmation for your intended audience.
4. Test sign-up, sign-in, sign-out, and password recovery before inviting real users.

## 3. Keep keys safe
The browser integration may use only the Supabase **Project URL** and the **anon/publishable key**. These are designed for client use when Row Level Security is correctly configured.
- **Never** put the `service_role` or secret key in `index.html`, a public GitHub repository, or any browser code.
- Do not put passwords, database connection strings, private farmer phone numbers, or credentials in source control.
- The schema deliberately omits a public owner phone field. Design a consent-based contact flow rather than exposing phone numbers in public listings.

## 4. Understand current limitations
- The site currently saves demo records in each browser's `localStorage`; another user/device will not see them.
- Supabase is not yet connected to the website. Forms are not yet creating shared database records.
- This schema is a starter. RLS limits who can read or change rows, but it is not a complete production security review. In particular, validate allowed booking status transitions server-side and add capacity/overbooking protection before real transactions.
- Do not rely on the `verified` field as proof of identity; verification must be an actual reviewed process.

## 5. Next integration milestone
After the database is created, provide the **Project URL** and **anon/publishable key only** if you want the website integration implemented. Do not share the service-role key. The next code change should add the Supabase client, authentication UI, and database-backed listing/group/booking flows, then test each flow with two separate accounts.
