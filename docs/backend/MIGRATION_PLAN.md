# Backend migration plan

The UI stays in place. Repositories are replaced one domain at a time.

## v0.2.0 – Foundation ✅
- Supabase client
- Auth
- Profile schema
- Activity type registry
- RLS baseline

## v0.2.1 – Real profile ✅
- profile repository
- interests
- activity profiles
- avatar storage

## v0.2.2 – Real activities ✅
- activities
- participants
- routes/stops foundation
- join/request/approve RPCs
- lifecycle/status RPC
- activity discovery RLS

## v0.2.3 – Groups ✅
- groups
- memberships
- group posts
- group activity permissions

## v0.2.4 – Chat ✅
- chats
- chat_members
- messages
- realtime delivery

## v0.2.5 – Live ✅
- live_sessions
- live_participants
- Realtime participant position streams with RLS
- public anonymized/rounded activity state
- real GPS + Android foreground-service tracking

## v0.2.6 – Notifications/history ✅
- realtime in-app notifications
- activity events/audit log
- immutable per-user activity history
- optional GPS route history
- real history UI and route map

## Later production hardening
- FCM/APNs push delivery and device tokens
- offline GPS queue
- catch-up routing/ETA
- iOS background tracking hardening
