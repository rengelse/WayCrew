-- Activity Network v0.2.8 - atomic activity creation / RLS fix
-- Run after 20260913181000_notifications_history.sql.
-- Keeps RLS enabled. Creation is server-owned so created_by can never be spoofed.

create or replace function public.create_activity(
  p_activity_type text,
  p_title text,
  p_description text,
  p_status text,
  p_participation_mode text,
  p_starts_at timestamptz,
  p_meeting_point text default '',
  p_max_participants integer default 12,
  p_pace text default 'Normal',
  p_surface text default 'Ikke satt',
  p_group_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_activity_id uuid;
  v_title text := trim(coalesce(p_title, ''));
  v_meeting text := trim(coalesce(p_meeting_point, ''));
begin
  if v_user_id is null then
    raise exception 'auth_required';
  end if;

  if not exists (select 1 from public.profiles where id = v_user_id) then
    raise exception 'profile_required';
  end if;

  if not exists (select 1 from public.activity_types where id = p_activity_type) then
    raise exception 'invalid_activity_type';
  end if;

  if char_length(v_title) < 2 or char_length(v_title) > 120 then
    raise exception 'invalid_title';
  end if;

  if p_status not in ('draft','planned','gathering') then
    raise exception 'invalid_initial_status';
  end if;

  if p_participation_mode not in ('open','request','groupOnly','private') then
    raise exception 'invalid_participation_mode';
  end if;

  if p_participation_mode = 'groupOnly' and p_group_id is null then
    raise exception 'group_required';
  end if;

  if p_group_id is not null and not public.can_create_group_activity(p_group_id, v_user_id) then
    raise exception 'group_activity_not_allowed';
  end if;

  if p_max_participants < 2 or p_max_participants > 500 then
    raise exception 'invalid_max_participants';
  end if;

  insert into public.activities (
    created_by,
    activity_type,
    title,
    description,
    status,
    participation_mode,
    starts_at,
    meeting_point,
    route_label,
    max_participants,
    pace,
    surface,
    group_id
  ) values (
    v_user_id,
    p_activity_type,
    v_title,
    coalesce(p_description, ''),
    p_status,
    p_participation_mode,
    p_starts_at,
    v_meeting,
    case when v_meeting = '' then 'Rute ikke satt' else v_meeting end,
    p_max_participants,
    coalesce(nullif(trim(p_pace), ''), 'Normal'),
    coalesce(nullif(trim(p_surface), ''), 'Ikke satt'),
    p_group_id
  )
  returning id into v_activity_id;

  -- activities_add_creator_as_leader trigger creates the leader participant.
  insert into public.activity_routes(activity_id, label, is_primary)
  values (
    v_activity_id,
    case when v_meeting = '' then 'Rute' else v_meeting end,
    true
  );

  if v_meeting <> '' then
    insert into public.activity_stops(activity_id, name, stop_type, sort_order)
    values (v_activity_id, v_meeting, 'meeting', 0);
  end if;

  return v_activity_id;
end;
$$;

revoke all on function public.create_activity(text,text,text,text,text,timestamptz,text,integer,text,text,uuid) from public;
grant execute on function public.create_activity(text,text,text,text,text,timestamptz,text,integer,text,text,uuid) to authenticated;
