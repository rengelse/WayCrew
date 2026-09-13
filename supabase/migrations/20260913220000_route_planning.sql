-- WayCrew v0.3.0 - persisted route planning geometry, waypoints and route metadata.
-- Run after 20260913210000_deletion_trigger_fix.sql.

alter table public.activity_routes
  add column if not exists duration_minutes integer not null default 0 check (duration_minutes >= 0),
  add column if not exists routing_profile text not null default '',
  add column if not exists routing_provider text not null default '';

-- Add explicit waypoint support while preserving existing meeting/stop/destination rows.
alter table public.activity_stops drop constraint if exists activity_stops_stop_type_check;
alter table public.activity_stops
  add constraint activity_stops_stop_type_check
  check (stop_type in ('meeting','stop','waypoint','destination'));

-- Remove the v0.2.13 signature before replacing it with route geometry support.
drop function if exists public.create_activity(
  text,text,text,text,text,timestamptz,text,text,double precision,double precision,
  text,text,double precision,double precision,text,text,double precision,double precision,
  integer,text,text,uuid
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
  p_route_geojson jsonb default null,
  p_route_distance_km double precision default 0,
  p_route_duration_minutes integer default 0,
  p_route_profile text default '',
  p_route_provider text default '',
  p_route_waypoints jsonb default '[]'::jsonb,
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
  v_waypoint jsonb;
  v_waypoint_name text;
  v_waypoint_address text;
  v_waypoint_lat double precision;
  v_waypoint_lon double precision;
  v_waypoint_order integer;
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
  if p_route_start_latitude not between -90 and 90 or p_route_destination_latitude not between -90 and 90 then raise exception 'invalid_route_latitude'; end if;
  if p_route_start_longitude not between -180 and 180 or p_route_destination_longitude not between -180 and 180 then raise exception 'invalid_route_longitude'; end if;
  if p_route_geojson is null or p_route_geojson->>'type' <> 'LineString' or jsonb_array_length(coalesce(p_route_geojson->'coordinates','[]'::jsonb)) < 2 then raise exception 'route_geometry_required'; end if;
  if p_route_distance_km < 0 or p_route_distance_km > 50000 then raise exception 'invalid_route_distance'; end if;
  if p_route_duration_minutes < 0 or p_route_duration_minutes > 100000 then raise exception 'invalid_route_duration'; end if;
  if jsonb_typeof(coalesce(p_route_waypoints,'[]'::jsonb)) <> 'array' then raise exception 'invalid_route_waypoints'; end if;
  if jsonb_array_length(coalesce(p_route_waypoints,'[]'::jsonb)) > 20 then raise exception 'too_many_route_waypoints'; end if;

  if (p_meeting_latitude is null) <> (p_meeting_longitude is null) then raise exception 'meeting_coordinates_incomplete'; end if;
  if p_meeting_latitude is not null and p_meeting_latitude not between -90 and 90 then raise exception 'invalid_meeting_latitude'; end if;
  if p_meeting_longitude is not null and p_meeting_longitude not between -180 and 180 then raise exception 'invalid_meeting_longitude'; end if;

  v_route_label := v_start || ' → ' || v_destination;

  insert into public.activities (
    created_by, activity_type, title, description, status, participation_mode,
    starts_at, meeting_point, route_label, max_participants, distance_km, pace, surface, group_id
  ) values (
    v_user_id, p_activity_type, v_title, coalesce(p_description, ''), p_status,
    p_participation_mode, p_starts_at, v_meeting, v_route_label,
    p_max_participants, round(p_route_distance_km::numeric, 2),
    coalesce(nullif(trim(p_pace), ''), 'Normal'),
    coalesce(nullif(trim(p_surface), ''), 'Ikke satt'),
    p_group_id
  ) returning id into v_activity_id;

  insert into public.activity_routes(
    activity_id, label, route_geojson, distance_km, duration_minutes, routing_profile, routing_provider, is_primary
  ) values (
    v_activity_id, v_route_label, p_route_geojson, round(p_route_distance_km::numeric, 2),
    p_route_duration_minutes, trim(coalesce(p_route_profile,'')), trim(coalesce(p_route_provider,'')), true
  );

  if v_meeting <> '' then
    insert into public.activity_stops(activity_id, name, address, stop_type, sort_order, latitude, longitude)
    values (v_activity_id, v_meeting, v_meeting_address, 'meeting', 0, p_meeting_latitude, p_meeting_longitude);
  end if;

  insert into public.activity_stops(activity_id, name, address, stop_type, sort_order, latitude, longitude)
  values (v_activity_id, v_start, v_start_address, 'stop', 10, p_route_start_latitude, p_route_start_longitude);

  for v_waypoint in select value from jsonb_array_elements(coalesce(p_route_waypoints,'[]'::jsonb)) loop
    v_waypoint_name := trim(coalesce(v_waypoint->>'name',''));
    v_waypoint_address := trim(coalesce(v_waypoint->>'address',''));
    v_waypoint_lat := nullif(v_waypoint->>'latitude','')::double precision;
    v_waypoint_lon := nullif(v_waypoint->>'longitude','')::double precision;
    v_waypoint_order := coalesce(nullif(v_waypoint->>'sort_order','')::integer, 20);
    if v_waypoint_name = '' or v_waypoint_lat is null or v_waypoint_lon is null then raise exception 'invalid_route_waypoint'; end if;
    if v_waypoint_lat not between -90 and 90 or v_waypoint_lon not between -180 and 180 then raise exception 'invalid_route_waypoint_coordinates'; end if;
    insert into public.activity_stops(activity_id, name, address, stop_type, sort_order, latitude, longitude)
    values (v_activity_id, v_waypoint_name, v_waypoint_address, 'waypoint', v_waypoint_order, v_waypoint_lat, v_waypoint_lon);
  end loop;

  insert into public.activity_stops(activity_id, name, address, stop_type, sort_order, latitude, longitude)
  values (v_activity_id, v_destination, v_destination_address, 'destination', 100, p_route_destination_latitude, p_route_destination_longitude);

  return v_activity_id;
end;
$$;

revoke all on function public.create_activity(
  text,text,text,text,text,timestamptz,text,text,double precision,double precision,
  text,text,double precision,double precision,text,text,double precision,double precision,
  jsonb,double precision,integer,text,text,jsonb,integer,text,text,uuid
) from public;
grant execute on function public.create_activity(
  text,text,text,text,text,timestamptz,text,text,double precision,double precision,
  text,text,double precision,double precision,text,text,double precision,double precision,
  jsonb,double precision,integer,text,text,jsonb,integer,text,text,uuid
) to authenticated;
