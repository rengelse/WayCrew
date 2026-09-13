# Supabase notifications & history – v0.2.6

Run `20260913181000_notifications_history.sql` after the v0.2.5 live-tracking migration.

## Tables

- `notifications`: per-user in-app notification inbox. Clients may read, mark their own rows read and delete their own rows; creation is server-side.
- `activity_events`: append-only event/audit stream for activity lifecycle and participant changes.
- `activity_history`: immutable per-user snapshot created when an activity finishes.
- `activity_route_history`: accepted GPS samples captured while live tracking runs, associated with the user's history entry at finish.
- `live_route_preferences`: per-activity/per-user opt-in/out used by the route-history capture trigger.

## Realtime

`notifications` is added to `supabase_realtime`, so the notification center and unread badge update without a manual refresh.

## Route-history privacy

The app's `Lagre rutehistorikk` setting is persisted locally. When live tracking starts, the setting is synchronized to `live_route_preferences`. The server-side GPS capture trigger checks that preference before persisting points. Live location can therefore continue without creating a permanent route history.

## Push notifications

v0.2.6 implements the server-side/in-app notification record and realtime inbox. Native OS push delivery with FCM/APNs and device tokens remains a later production-hardening step.
