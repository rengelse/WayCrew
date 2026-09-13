# v0.2.2 Supabase Activities

Run `supabase/migrations/20260913153000_real_activities.sql` after the v0.2.0 and v0.2.1 migrations.

The migration creates:
- `activities`
- `activity_participants`
- `activity_routes`
- `activity_stops`

Critical mutations are RPC-based rather than direct client updates:
- `request_to_join_activity`
- `join_open_activity`
- `approve_activity_participant`
- `set_activity_status`
- `update_activity_meeting_point`
- `leave_activity`

The activity creator is automatically added as the leader by a database trigger. RLS is enabled on every table.

Group-only activity authorization is intentionally staged until v0.2.3. In authenticated mode, the v0.2.2 create flow therefore does not attach a mock group to a real Supabase activity.
