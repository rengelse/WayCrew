# Supabase live tracking

Migration: `20260913174000_live_tracking.sql`

## Tables

### live_sessions
One lifecycle-bound live session per activity. `active` during an active/paused activity and `ended` when the activity finishes/cancels.

### live_participants
Latest GPS sample per participant/session. Stores sequence, coordinates, accuracy, optional heading/speed, recorded/received timestamps and sharing/privacy flags.

Exact rows are readable only by approved/active participants of that activity through RLS.

### activity_public_state
Reduced map state for discovery/detail surfaces. It contains only an approximate aggregate group center rounded to three decimal degrees, participant count and update timestamp. It never exposes a user id.

## RPCs

- `ensure_live_session(activity_id)`
- `publish_live_position(...)`
- `stop_live_sharing(activity_id)`
- `set_live_public_approximate(activity_id, enabled)`

`publish_live_position` verifies authentication, approved participation, live activity state, plausible coordinates/accuracy/speed, timestamp freshness and monotonic sequence before accepting an update.

## Lifecycle

Changing an activity to `active` creates/activates its live session. `paused` keeps it alive. `finished`/`cancelled` ends the session, disables all participant sharing and deletes `activity_public_state`.

## Realtime

`live_participants` and `activity_public_state` are added to `supabase_realtime`. The Flutter app subscribes to table streams with RLS still enforced by Supabase.
