-- Activity Network v0.2.11 - Production Hardening I
-- Run after 20260913193000_create_group_rpc.sql.
-- Critical mutations are server-owned. RLS remains enabled.

-- Group administration must not expose arbitrary UPDATE access to the groups row.
create or replace function public.update_group(
  p_group_id uuid,
  p_name text,
  p_region text default '',
  p_description text default '',
  p_visibility text default 'public',
  p_join_mode text default 'request',
  p_members_can_create_activities boolean default false
)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  v_name text := trim(coalesce(p_name,''));
  v_region text := trim(coalesce(p_region,''));
  v_description text := trim(coalesce(p_description,''));
begin
  if auth.uid() is null then raise exception 'auth_required'; end if;
  if not public.is_group_admin(p_group_id, auth.uid()) then raise exception 'group_admin_required'; end if;
  if char_length(v_name) < 2 or char_length(v_name) > 120 then raise exception 'invalid_group_name'; end if;
  if char_length(v_region) > 120 then raise exception 'invalid_region'; end if;
  if char_length(v_description) > 4000 then raise exception 'invalid_description'; end if;
  if p_visibility not in ('public','private') then raise exception 'invalid_visibility'; end if;
  if p_join_mode not in ('open','request','inviteOnly') then raise exception 'invalid_join_mode'; end if;

  update public.groups
  set name=v_name,
      region=v_region,
      description=v_description,
      visibility=p_visibility,
      join_mode=p_join_mode,
      members_can_create_activities=coalesce(p_members_can_create_activities,false),
      updated_at=now()
  where id=p_group_id;

  if not found then raise exception 'group_not_found'; end if;
end;
$$;

-- The official client already uses create_activity/set_activity_status/update_activity_meeting_point.
-- Remove the table-level bypass so a modified client cannot skip RPC validation/state transitions.
revoke insert, update on public.activities from authenticated;

-- Group creation/update are now RPC-owned. Reads remain RLS-protected.
revoke insert, update on public.groups from authenticated;

-- Explicitly constrain client-facing SECURITY DEFINER mutations to authenticated users.
revoke all on function public.create_group(text,text,text,text,text,text) from public;
grant execute on function public.create_group(text,text,text,text,text,text) to authenticated;

revoke all on function public.update_group(uuid,text,text,text,text,text,boolean) from public;
grant execute on function public.update_group(uuid,text,text,text,text,text,boolean) to authenticated;

revoke all on function public.request_to_join_activity(uuid) from public;
revoke all on function public.join_open_activity(uuid) from public;
revoke all on function public.approve_activity_participant(uuid,uuid) from public;
revoke all on function public.set_activity_status(uuid,text) from public;
revoke all on function public.update_activity_meeting_point(uuid,text) from public;
revoke all on function public.leave_activity(uuid) from public;
grant execute on function public.request_to_join_activity(uuid) to authenticated;
grant execute on function public.join_open_activity(uuid) to authenticated;
grant execute on function public.approve_activity_participant(uuid,uuid) to authenticated;
grant execute on function public.set_activity_status(uuid,text) to authenticated;
grant execute on function public.update_activity_meeting_point(uuid,text) to authenticated;
grant execute on function public.leave_activity(uuid) to authenticated;

revoke all on function public.join_open_group(uuid) from public;
revoke all on function public.request_group_membership(uuid) from public;
revoke all on function public.approve_group_membership(uuid,uuid) from public;
revoke all on function public.reject_group_membership(uuid,uuid) from public;
revoke all on function public.change_group_member_role(uuid,uuid,text) from public;
revoke all on function public.remove_group_member(uuid,uuid) from public;
revoke all on function public.leave_group(uuid) from public;
grant execute on function public.join_open_group(uuid) to authenticated;
grant execute on function public.request_group_membership(uuid) to authenticated;
grant execute on function public.approve_group_membership(uuid,uuid) to authenticated;
grant execute on function public.reject_group_membership(uuid,uuid) to authenticated;
grant execute on function public.change_group_member_role(uuid,uuid,text) to authenticated;
grant execute on function public.remove_group_member(uuid,uuid) to authenticated;
grant execute on function public.leave_group(uuid) to authenticated;

revoke all on function public.ensure_activity_chat(uuid) from public;
revoke all on function public.ensure_group_chat(uuid) from public;
grant execute on function public.ensure_activity_chat(uuid) to authenticated;
grant execute on function public.ensure_group_chat(uuid) to authenticated;

revoke all on function public.ensure_live_session(uuid) from public;
revoke all on function public.publish_live_position(uuid,bigint,double precision,double precision,double precision,double precision,double precision,timestamptz,boolean,boolean,boolean) from public;
revoke all on function public.stop_live_sharing(uuid) from public;
revoke all on function public.set_live_privacy(uuid,boolean,boolean,boolean) from public;
grant execute on function public.ensure_live_session(uuid) to authenticated;
grant execute on function public.publish_live_position(uuid,bigint,double precision,double precision,double precision,double precision,double precision,timestamptz,boolean,boolean,boolean) to authenticated;
grant execute on function public.stop_live_sharing(uuid) to authenticated;
grant execute on function public.set_live_privacy(uuid,boolean,boolean,boolean) to authenticated;

revoke all on function public.set_route_history_preference(uuid,boolean) from public;
grant execute on function public.set_route_history_preference(uuid,boolean) to authenticated;
