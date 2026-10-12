# AgriShare — Supabase setup guide

The AgriShare frontend contains a username + password interface (no email field), live equipment listing reads, equipment listing creation, booking request creation, group creation, and group joining. Account creation uses a server-side Supabase Edge Function to avoid email confirmation delivery. **These features become live only after the SQL schema has been applied and the connection is verified.**

## 1. Create a Supabase project
1. Create a project in Supabase and save the database password privately.
2. Open **SQL Editor → New query**.
3. Copy all of `supabase/schema.sql`, run it, and check for errors.
4. Open **Table Editor** and confirm these tables exist: `equipment`, `group_bookings`, `group_members`, `booking_requests`, `booking_reviews` and `support_requests`. The SQL also creates `get_group_progress()` to show aggregate group acreage without exposing member records.

## 2. Configure authentication
1. In **Authentication → URL Configuration**, add your deployed site URL: `https://codex-inn.github.io/AgriShare`.
2. In the project’s Auth settings, enable leaked-password protection if it is available on the plan. Supabase’s current security advisor reports that this setting is disabled.
3. Add the same URL to the allowed redirect URLs (and a local development URL only if needed).
4. Apply the SQL in `supabase/username-auth.sql` using **SQL Editor → New query**. This creates a private rate-limit table for signup attempts. Keep RLS enabled.
5. Deploy the Edge Function in `supabase/functions/username-signup/index.ts` to project `xsrrpjkvlodcvlqawrui`. From a machine with Supabase CLI installed and logged in, run:
   ```sh
   supabase link --project-ref xsrrpjkvlodcvlqawrui
   supabase functions deploy username-signup --no-verify-jwt
   ```
   The repo includes `supabase/config.toml` with JWT verification disabled only for this public signup function; the function performs input validation and rate limiting itself.
6. In **Edge Functions → Secrets**, confirm `SUPABASE_SERVICE_ROLE_KEY` is available to the function. The current function reads this name first and supports the older `SERVICE_ROLE_KEY` name as a fallback. If needed, set it from the project’s server-side API keys page. Never paste it into GitHub, chat, or `index.html`. The function uses this secret only on the server to create an Auth user with `email_confirm: true`, so no confirmation email is sent.
7. The form asks only for a username and password. Internally, usernames map to non-routable `username@agrishare.local` identities because Supabase Auth does not natively support username sign-in. Supabase Auth still hashes/manages passwords and issues the session; passwords are never stored in app tables.
8. Username accounts cannot receive password-reset emails. Existing username accounts created earlier through the old email-signup path may remain unconfirmed; do not delete accounts with real data. Check **Authentication → Users** first. If a test username is already registered but unconfirmed, use a new username until you decide how to handle that test account.

## 3. Keep keys safe
The browser integration may use only the Supabase **Project URL** and the **anon/publishable key**. These are designed for client use when Row Level Security is correctly configured.
- **Never** put the `service_role` or secret key in `index.html`, a public GitHub repository, or any browser code.
- Do not put passwords, database connection strings, private farmer phone numbers, or credentials in source control.
- The schema deliberately omits a public owner phone field. Design a consent-based contact flow rather than exposing phone numbers in public listings.

## 4. Understand current limitations
- If the page reports “Database setup required,” run the current `supabase/schema.sql` in the SQL Editor, then refresh the website. The status in the top strip should read “Shared database connected.”
- Group joining uses the `public.join_group` RPC backed by `private.join_group_core`; it locks the group row, checks remaining acreage and duplicate membership, then inserts within one transaction.
- Booking status changes use server-side RPCs. The active equipment/date index prevents more than one pending or accepted booking on the same date, including concurrent/direct API attempts.
- These controls improve integrity but do not replace end-to-end testing with two consenting accounts or a full production security review.
- Do not rely on the `verified` field as proof of identity; verification must be an actual reviewed process.

## 5. Equipment compatibility permissions

The listing form saves owner-declared tractor and implement specifications (role, horsepower, hitch, PTO, hydraulic requirements and compatibility notes). The starter schema grants authenticated owners insert/update access to these specific columns while keeping `verified` protected from owner writes. For an existing project created before these grants were added, apply `supabase/allow-equipment-compatibility-writes.sql` once. Do not rerun the starter schema over the production database.

## 6. Marketplace support, reviews and booking safety

For an existing project, apply `supabase/production-readiness-workflows.sql` once after the core marketplace migrations, then apply `supabase/production-readiness-indexes.sql`. The first file adds the active equipment/date booking guard, participant-only reviews after completion, and a private support/report queue; the second indexes the new review/support foreign keys. Support submissions are insert-only for authenticated users, limited to five per account per hour, and cannot be read through the public client API. Project administrators can review them in the Supabase dashboard. An account-deletion request is manual and does not delete an account automatically.

The migration also fixes the SQL `search_path` on the existing privileged database trigger/workflow functions. Do not re-run `supabase/schema.sql` against production; it is only for a new development project.

## 7. Next integration milestone
After applying the schema and deploying the signup function, test username account creation, sign-in, sign-out, listing creation, booking requests, and group joining with two separate accounts. The configured browser key is a public publishable key; keep Row Level Security enabled and never expose service-role or secret keys. The app still has no self-service username password reset or automatic account deletion. Support requests provide a manual contact path only. Configure real account recovery (which requires routable verified email identities or another recovery provider) before public launch.
