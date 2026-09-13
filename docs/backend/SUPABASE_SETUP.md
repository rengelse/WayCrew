# Supabase setup – v0.2.0

Project: `activity-network-dev`

## 1. Apply the foundation migration

In Supabase Dashboard:

1. Open **SQL Editor**.
2. Create a new query.
3. Paste the complete contents of:
   `supabase/migrations/20260913140000_supabase_foundation.sql`
4. Run it once.

This creates:

- `profiles`
- `activity_types`
- `user_interests`
- `activity_profiles`
- automatic profile creation for new Auth users
- RLS policies for all foundation tables
- the private `avatars` Storage bucket

## 2. Authentication

The app uses Supabase email/password Auth.

For fast development you may temporarily disable **Confirm email** in the Supabase Auth settings. If it remains enabled, signup succeeds but the user must confirm the email before logging in.

Do not put a secret/service-role key in the Flutter app.

## 3. Flutter configuration

The development Project URL and publishable key are built in as development defaults. They can be overridden without changing source code:

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
```

Later, staging and production will use their own values.

## 4. What is real in v0.2.0?

Real:

- Supabase client bootstrap
- Auth signup/login/logout/password reset
- Auth session persistence
- automatic `profiles` row creation
- foundation database and RLS
- prepared avatar bucket

Still local mock repositories:

- activities
- groups
- chat
- live tracking
- notifications
- history

The development login screen includes **Fortsett i lokal demo** so the UI can still be tested while backend modules are migrated.
