-- Activity Network v0.2.13 - Group deletion, route endpoints and place-search creation flow
-- Run after 20260913200000_production_hardening.sql.

-- Owner-only permanent group deletion. Related memberships/posts/chats cascade;
-- existing activities are preserved because activities.group_id uses ON DELETE SET NULL.
create or replace function public.delete_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  v_owner uuid;
begin
  if auth.uid() is null then raise exception 'auth_required'; end if;

  select created_by into v_owner from public.groups where id=p_group_id;
  if v_owner is null then raise exception 'group_not_found'; end if;
  if v_owner <> auth.uid() then raise exception 'group_owner_required'; end if;

  delete from public.groups where id=p_group_id;
end;
$$;

revoke all on function public.delete_group(uuid) from public;
grant execute on function public.delete_group(uuid) to authenticated;

-- Replace the v0.2.9 activity creation RPC with a real route-aware signature.
drop function if exists public.create_activity(
  text,text,text,text,text,timestamptz,text,text,double precision,double precision,integer,text,text,uuid
);

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
  p_route_start_name text default '',
  p_route_start_address text default '',
  p_route_start_latitude double precision default null,
  p_route_start_longitude double precision default null,
  p_route_destination_name text default '',
  p_route_destination_address text default '',
  p_route_destination_latitude double precision default null,
  p_route_destination_longitude double precision default null,
  p_max_participants integer default 12,
  p_pace text default 'Normal',
  p_surface text default 'Ikke satt',
  p_group_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_user_id uuid := auth.uid();
  v_activity_id uuid;
  v_title text := trim(coalesce(p_title, ''));
  v_meeting text := trim(coalesce(p_meeting_point, ''));
  v_meeting_address text := trim(coalesce(p_meeting_address, ''));
  v_start text := trim(coalesce(p_route_start_name, ''));
  v_start_address text := trim(coalesce(p_route_start_address, ''));
  v_destination text := trim(coalesce(p_route_destination_name, ''));
  v_destination_address text := trim(coalesce(p_route_destination_address, ''));
  v_route_label text;
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

  if v_start = '' or v_destination = '' then raise exception 'route_endpoints_required'; end if;
  if p_route_start_latitude is null or p_route_start_longitude is null then raise exception 'route_start_coordinates_required'; end if;
  if p_route_destination_latitude is null or p_route_destination_longitude is null then raise exception 'route_destination_coordinates_required'; end if;
  if p_route_start_latitude < -90 or p_route_start_latitude > 90 then raise exception 'invalid_route_start_latitude'; end if;
  if p_route_start_longitude < -180 or p_route_start_longitude > 180 then raise exception 'invalid_route_start_longitude'; end if;
  if p_route_destination_latitude < -90 or p_route_destination_latitude > 90 then raise exception 'invalid_route_destination_latitude'; end if;
  if p_route_destination_longitude < -180 or p_route_destination_longitude > 180 then raise exception 'invalid_route_destination_longitude'; end if;

  if (p_meeting_latitude is null) <> (p_meeting_longitude is null) then raise exception 'meeting_coordinates_incomplete'; end if;
  if p_meeting_latitude is not null and (p_meeting_latitude < -90 or p_meeting_latitude > 90) then raise exception 'invalid_meeting_latitude'; end if;
  if p_meeting_longitude is not null and (p_meeting_longitude < -180 or p_meeting_longitude > 180) then raise exception 'invalid_meeting_longitude'; end if;

  v_route_label := v_start || ' → ' || v_destination;

  insert into public.activities (
    created_by, activity_type, title, description, status, participation_mode,
    starts_at, meeting_point, route_label, max_participants, pace, surface, group_id
  ) values (
    v_user_id, p_activity_type, v_title, coalesce(p_description, ''), p_status,
    p_participation_mode, p_starts_at, v_meeting, v_route_label,
    p_max_participants,
    coalesce(nullif(trim(p_pace), ''), 'Normal'),
    coalesce(nullif(trim(p_surface), ''), 'Ikke satt'),
    p_group_id
  ) returning id into v_activity_id;

  insert into public.activity_routes(activity_id, label, is_primary)
  values (v_activity_id, v_route_label, true);

  if v_meeting <> '' then
    insert into public.activity_stops(activity_id, name, address, stop_type, sort_order, latitude, longitude)
    values (v_activity_id, v_meeting, v_meeting_address, 'meeting', 0, p_meeting_latitude, p_meeting_longitude);
  end if;

  insert into public.activity_stops(activity_id, name, address, stop_type, sort_order, latitude, longitude)
  values (v_activity_id, v_start, v_start_address, 'stop', 10, p_route_start_latitude, p_route_start_longitude);

  insert into public.activity_stops(activity_id, name, address, stop_type, sort_order, latitude, longitude)
  values (v_activity_id, v_destination, v_destination_address, 'destination', 100, p_route_destination_latitude, p_route_destination_longitude);

  return v_activity_id;
end;
$$;

revoke all on function public.create_activity(
  text,text,text,text,text,timestamptz,text,text,double precision,double precision,
  text,text,double precision,double precision,text,text,double precision,double precision,
  integer,text,text,uuid
) from public;
grant execute on function public.create_activity(
  text,text,text,text,text,timestamptz,text,text,double precision,double precision,
  text,text,double precision,double precision,text,text,double precision,double precision,
  integer,text,text,uuid
) to authenticated;
