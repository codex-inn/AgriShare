# AgriShare — Supabase setup guide

The AgriShare frontend contains a username + password interface (no email field), live equipment listing reads, equipment listing creation, booking request creation, group creation, and group joining. Account creation uses a server-side Supabase Edge Function to avoid email confirmation delivery. **These features become live only after the SQL schema has been applied and the connection is verified.**

## 1. Create a Supabase project
1. Create a project in Supabase and save the database password privately.
2. Open **SQL Editor → New query**.
3. Copy all of `supabase/schema.sql`, run it, and check for errors.
4. Open **Table Editor** and confirm these tables exist: `equipment`, `group_bookings`, `group_members`, and `booking_requests`. The SQL also creates the `get_group_progress()` aggregate function used to show group acreage without exposing individual member records.

## 2. Configure authentication
1. In **Authentication → URL Configuration**, add your deployed site URL: `https://codex-inn.github.io/AgriShare`.
2. Add the same URL to the allowed redirect URLs (and a local development URL only if needed).
3. Apply the SQL in `supabase/username-auth.sql` using **SQL Editor → New query**. This creates a private rate-limit table for signup attempts. Keep RLS enabled.
4. Deploy the Edge Function in `supabase/functions/username-signup/index.ts` to project `xsrrpjkvlodcvlqawrui`. From a machine with Supabase CLI installed and logged in, run:
   ```sh
   supabase link --project-ref xsrrpjkvlodcvlqawrui
   supabase functions deploy username-signup --no-verify-jwt
   ```
   The repo includes `supabase/config.toml` with JWT verification disabled only for this public signup function; the function performs input validation and rate limiting itself.
5. In **Edge Functions → Secrets**, confirm `SUPABASE_SERVICE_ROLE_KEY` is available to the function. The current function reads this name first and supports the older `SERVICE_ROLE_KEY` name as a fallback. If needed, set it from the project’s server-side API keys page. Never paste it into GitHub, chat, or `index.html`. The function uses this secret only on the server to create an Auth user with `email_confirm: true`, so no confirmation email is sent.
6. The form asks only for a username and password. Internally, usernames map to non-routable `username@agrishare.local` identities because Supabase Auth does not natively support username sign-in. Supabase Auth still hashes/manages passwords and issues the session; passwords are never stored in app tables.
7. Username accounts cannot receive password-reset emails. Existing username accounts created earlier through the old email-signup path may remain unconfirmed; do not delete accounts with real data. Check **Authentication → Users** first. If a test username is already registered but unconfirmed, use a new username until you decide how to handle that test account.

## 3. Keep keys safe
The browser integration may use only the Supabase **Project URL** and the **anon/publishable key**. These are designed for client use when Row Level Security is correctly configured.
- **Never** put the `service_role` or secret key in `index.html`, a public GitHub repository, or any browser code.
- Do not put passwords, database connection strings, private farmer phone numbers, or credentials in source control.
- The schema deliberately omits a public owner phone field. Design a consent-based contact flow rather than exposing phone numbers in public listings.

## 4. Understand current limitations
- If the page reports “Database setup required,” run the current `supabase/schema.sql` in the SQL Editor, then refresh the website. The status in the top strip should read “Shared database connected.”
- Group joining uses the `public.join_group` RPC backed by `private.join_group_core`; it locks the group row, checks remaining acreage and duplicate membership, then inserts within one transaction. Validate this with concurrent test accounts before accepting real bookings.
- This schema is a starter. RLS limits who can read or change rows, but it is not a complete production security review. In particular, validate allowed booking status transitions server-side and add capacity/overbooking protection before real transactions.
- Do not rely on the `verified` field as proof of identity; verification must be an actual reviewed process.

## 5. Next integration milestone
After applying the schema and deploying the signup function, test username account creation, sign-in, sign-out, listing creation, booking requests, and group joining with two separate accounts. The configured browser key is a public publishable key; keep Row Level Security enabled and never expose service-role or secret keys. The app currently has no self-service account deletion or username password-reset path; establish an authenticated recovery/deletion process before public launch.
