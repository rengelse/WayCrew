-- Activity Network v0.2.9 - Meeting Point Search & Map Pin
-- Run after 20260913183000_create_activity_rpc.sql.

alter table public.activity_stops
  add column if not exists address text not null default '';

-- Replace the v0.2.8 RPC with a coordinate-aware signature.
drop function if exists public.create_activity(text,text,text,text,text,timestamptz,text,integer,text,text,uuid);

create or replace function public.create_activity(
  p_activity_type text,
  p_title text,
  p_description text,
  p_status text,
  p_participation_mode text,
  p_starts_at timestamptz,
  p_meeting_point text default '',
  p_meeting_address text default '',
  p_meeting_latitude double precision default null,
  p_meeting_longitude double precision default null,
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
  v_address text := trim(coalesce(p_meeting_address, ''));
begin
  if v_user_id is null then raise exception 'auth_required'; end if;
  if not exists (select 1 from public.profiles where id = v_user_id) then raise exception 'profile_required'; end if;
  if not exists (select 1 from public.activity_types where id = p_activity_type) then raise exception 'invalid_activity_type'; end if;
  if char_length(v_title) < 2 or char_length(v_title) > 120 then raise exception 'invalid_title'; end if;
  if p_status not in ('draft','planned','gathering') then raise exception 'invalid_initial_status'; end if;
  if p_participation_mode not in ('open','request','groupOnly','private') then raise exception 'invalid_participation_mode'; end if;
  if p_participation_mode = 'groupOnly' and p_group_id is null then raise exception 'group_required'; end if;
  if p_group_id is not null and not public.can_create_group_activity(p_group_id, v_user_id) then raise exception 'group_activity_not_allowed'; end if;
  if p_max_participants < 2 or p_max_participants > 500 then raise exception 'invalid_max_participants'; end if;
  if (p_meeting_latitude is null) <> (p_meeting_longitude is null) then raise exception 'meeting_coordinates_incomplete'; end if;
  if p_meeting_latitude is not null and (p_meeting_latitude < -90 or p_meeting_latitude > 90) then raise exception 'invalid_meeting_latitude'; end if;
  if p_meeting_longitude is not null and (p_meeting_longitude < -180 or p_meeting_longitude > 180) then raise exception 'invalid_meeting_longitude'; end if;

  insert into public.activities (
    created_by, activity_type, title, description, status, participation_mode,
    starts_at, meeting_point, route_label, max_participants, pace, surface, group_id
  ) values (
    v_user_id, p_activity_type, v_title, coalesce(p_description, ''), p_status,
    p_participation_mode, p_starts_at, v_meeting,
    case when v_meeting = '' then 'Rute ikke satt' else v_meeting end,
    p_max_participants,
    coalesce(nullif(trim(p_pace), ''), 'Normal'),
    coalesce(nullif(trim(p_surface), ''), 'Ikke satt'),
    p_group_id
  ) returning id into v_activity_id;

  insert into public.activity_routes(activity_id, label, is_primary)
  values (v_activity_id, case when v_meeting = '' then 'Rute' else v_meeting end, true);

  if v_meeting <> '' then
    insert into public.activity_stops(activity_id, name, address, stop_type, sort_order, latitude, longitude)
    values (v_activity_id, v_meeting, v_address, 'meeting', 0, p_meeting_latitude, p_meeting_longitude);
  end if;

  return v_activity_id;
end;
$$;

revoke all on function public.create_activity(text,text,text,text,text,timestamptz,text,text,double precision,double precision,integer,text,text,uuid) from public;
grant execute on function public.create_activity(text,text,text,text,text,timestamptz,text,text,double precision,double precision,integer,text,text,uuid) to authenticated;

-- A legacy free-text leader edit must never leave an old pin attached to a new name.
create or replace function public.update_activity_meeting_point(p_activity_id uuid, p_meeting_point text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.is_activity_leader(p_activity_id) then raise exception 'leader_required'; end if;
  update public.activities set meeting_point=trim(p_meeting_point), updated_at=now() where id=p_activity_id;
  update public.activity_stops
    set name=trim(p_meeting_point), address='', latitude=null, longitude=null, updated_at=now()
    where activity_id=p_activity_id and stop_type='meeting';
  if not found and trim(p_meeting_point) <> '' then
    insert into public.activity_stops(activity_id,name,address,stop_type,sort_order)
    values(p_activity_id,trim(p_meeting_point),'','meeting',0);
  end if;
end; $$;

grant execute on function public.update_activity_meeting_point(uuid,text) to authenticated;
