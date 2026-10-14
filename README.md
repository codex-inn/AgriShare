# AgriShare

**Agricultural machinery sharing and booking platform.**

- **Live demo:** https://codex-inn.github.io/AgriShare/
- **Repository:** https://github.com/codex-inn/AgriShare
- **Stack:** HTML, CSS, JavaScript, Supabase, GitHub Pages

## Features

- Equipment listings and booking requests
- Farmer group coordination
- Tractor and implement compatibility checks
- Weather forecasts and maintenance records
- Booking progress, messaging, reviews and support requests
- Progressive Web App (PWA) support

Some features depend on a correctly configured Supabase backend. CropSight analysis requires a separately deployed, trained HTTPS inference API.

## Setup

1. Review [Supabase setup instructions](supabase/SETUP.md).
2. Apply database migrations in the documented order.
3. Configure the Supabase URL and publishable key for the frontend.
4. Deploy through GitHub Pages.

**Security:** Never expose the Supabase service-role key in browser code. Keep Row Level Security enabled. Do not run `supabase/schema.sql` against the production database; it is for new development projects only.

## Validation

Requires Node.js 20 or later:

```sh
node scripts/validate-project.mjs
```

The automated checks validate project structure and JavaScript syntax; they do not replace browser testing or end-to-end Supabase tests.

## Current limitations

- Payments, automated identity verification, dispute handling and self-service password recovery/account deletion are not fully implemented.
- Group booking requests require each equipment owner to respond separately.
- CropSight predictions are unavailable until its inference API is deployed.
- Test signup, booking, messaging and storage privacy with consenting accounts before public production use.

---

**Project by Kowshik S** · AC&RI Vazhavachanur, TNAU
