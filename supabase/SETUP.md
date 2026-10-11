# AgriShare — Supabase setup guide

The AgriShare frontend now contains the Supabase client, email sign-in/sign-up, live equipment listing reads, equipment listing creation, booking request creation, group creation, and group joining. **These features become live only after the SQL schema has been applied and the connection is verified.**

## 1. Create a Supabase project
1. Create a project in Supabase and save the database password privately.
2. Open **SQL Editor → New query**.
3. Copy all of `supabase/schema.sql`, run it, and check for errors.
4. Open **Table Editor** and confirm these tables exist: `equipment`, `group_bookings`, `group_members`, and `booking_requests`. The SQL also creates the `get_group_progress()` aggregate function used to show group acreage without exposing individual member records.

## 2. Configure authentication
1. In **Authentication → URL Configuration**, add your deployed site URL: `https://codex-inn.github.io/AgriShare`.
2. Add the same URL to the allowed redirect URLs (and a local development URL only if needed).
3. **Username-only account workaround:** in **Authentication → Sign In / Providers → Email**, turn off **Confirm email** before creating username accounts. The frontend maps a username to a synthetic `username@agrishare.local` identity so Supabase Auth can issue its normal session/JWT. Passwords remain managed by Supabase Auth; they are never stored in the public app tables.
4. Username accounts cannot receive confirmation or password-reset emails. Users must remember their password; use a real email account if account recovery is important. Do not enter a real person's email as a username. Existing email accounts can still sign in using their email.
5. Test sign-up, sign-in, sign-out, and recovery behavior before inviting real users.

## 3. Keep keys safe
The browser integration may use only the Supabase **Project URL** and the **anon/publishable key**. These are designed for client use when Row Level Security is correctly configured.
- **Never** put the `service_role` or secret key in `index.html`, a public GitHub repository, or any browser code.
- Do not put passwords, database connection strings, private farmer phone numbers, or credentials in source control.
- The schema deliberately omits a public owner phone field. Design a consent-based contact flow rather than exposing phone numbers in public listings.

## 4. Understand current limitations
- If the page reports “Database setup required,” run the current `supabase/schema.sql` in the SQL Editor, then refresh the website. The status in the top strip should read “Shared database connected.”
- Group capacity is checked in the UI but is not transaction-safe; add a database transaction/RPC before real-world bookings.
- This schema is a starter. RLS limits who can read or change rows, but it is not a complete production security review. In particular, validate allowed booking status transitions server-side and add capacity/overbooking protection before real transactions.
- Do not rely on the `verified` field as proof of identity; verification must be an actual reviewed process.

## 5. Next integration milestone
After applying the schema, test sign-up, email confirmation, sign-in, listing creation, booking requests, and group joining with two separate accounts. The configured browser key is a public publishable key; keep Row Level Security enabled and never expose service-role or secret keys.
