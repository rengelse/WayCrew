-- WayCrew v0.4.0 - Production audit cleanup
-- Tighten function exposure without changing application-visible behaviour.

-- Internal trigger/server helpers must never be directly callable by clients.
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = any(array[
        'handle_new_user',
        'set_updated_at',
        'activity_add_creator_as_leader',
        'group_add_creator_as_owner',
        'create_activity_chat',
        'create_group_chat',
        'sync_activity_chat_member',
        'sync_group_chat_member',
        'capture_live_route_point',
        'sync_live_session_from_activity',
        'sync_live_sharing_from_participation',
        'refresh_activity_public_state',
        'create_notification',
        'log_activity_created',
        'log_activity_change_and_notify',
        'activity_participant_event_notify',
        'group_member_notify',
        'message_notify_members',
        'snapshot_finished_activity',
        'validate_activity_schedule'
      ])
  loop
    execute format('revoke all on function %s from public', r.signature);
    execute format('revoke all on function %s from anon', r.signature);
    execute format('revoke all on function %s from authenticated', r.signature);
  end loop;
end $$;

-- RLS/helper functions are needed while authenticated policies are evaluated,
-- but anonymous/public callers should not be able to probe application state.
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = any(array[
        'activity_confirmed_count',
        'can_create_group_activity',
        'can_send_important_chat_message',
        'can_view_activity',
        'can_view_activity_profile',
        'can_view_group',
        'group_role',
        'is_activity_chat_participant',
        'is_activity_leader',
        'is_activity_participant',
        'is_chat_member',
        'is_group_admin',
        'is_group_member',
        'is_live_activity_participant',
        'group_active_member_count',
        'group_upcoming_count'
      ])
  loop
    execute format('revoke all on function %s from public', r.signature);
    execute format('revoke all on function %s from anon', r.signature);
    execute format('grant execute on function %s to authenticated', r.signature);
  end loop;
end $$;
