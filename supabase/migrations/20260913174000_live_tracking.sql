-- Activity Network v0.2.5 - Live Tracking
-- Run after v0.2.4. Adds secure live sessions, per-participant GPS state,
-- approximate public activity state and realtime publication.

create extension if not exists pgcrypto;

create table if not exists public.live_sessions (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null unique references public.activities(id) on delete cascade,
  status text not null default 'active' check (status in ('active','ended')),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.live_participants (
  session_id uuid not null references public.live_sessions(id) on delete cascade,
  activity_id uuid not null references public.activities(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'participant' check (role in ('leader','sweep','participant')),
  sharing boolean not null default true,
  share_with_participants boolean not null default true,
  share_with_leader boolean not null default true,
  public_approximate boolean not null default true,
  sequence bigint not null default 0,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  accuracy_m double precision not null default 0 check (accuracy_m between 0 and 5000),
  heading_deg double precision check (heading_deg is null or (heading_deg >= 0 and heading_deg <= 360)),
  speed_mps double precision check (speed_mps is null or (speed_mps >= 0 and speed_mps <= 120)),
  recorded_at timestamptz not null,
  received_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (session_id, user_id)
);

create table if not exists public.activity_public_state (
  activity_id uuid primary key references public.activities(id) on delete cascade,
  session_id uuid not null references public.live_sessions(id) on delete cascade,
  center_latitude double precision not null check (center_latitude between -90 and 90),
  center_longitude double precision not null check (center_longitude between -180 and 180),
  participant_count integer not null default 0 check (participant_count >= 0),
  updated_at timestamptz not null default now()
);

create index if not exists live_participants_activity_idx on public.live_participants(activity_id);
create index if not exists live_participants_recorded_idx on public.live_participants(activity_id, recorded_at desc);
create index if not exists activity_public_state_updated_idx on public.activity_public_state(updated_at desc);

drop trigger if exists live_sessions_set_updated_at on public.live_sessions;
create trigger live_sessions_set_updated_at before update on public.live_sessions
for each row execute procedure public.set_updated_at();

drop trigger if exists live_participants_set_updated_at on public.live_participants;
create trigger live_participants_set_updated_at before update on public.live_participants
for each row execute procedure public.set_updated_at();

create or replace function public.is_live_activity_participant(p_activity_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.activity_participants ap
    where ap.activity_id=p_activity_id
      and ap.user_id=p_user_id
      and ap.status in ('approved','active')
  );
$$;

create or replace function public.ensure_live_session(p_activity_id uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_status text;
  v_session_id uuid;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not public.is_live_activity_participant(p_activity_id, auth.uid()) then raise exception 'participant_required'; end if;

  select status into v_status from public.activities where id=p_activity_id;
  if not found then raise exception 'activity_not_found'; end if;
  if v_status not in ('active','paused') then raise exception 'activity_not_live'; end if;

  insert into public.live_sessions(activity_id,status,started_at,ended_at)
  values(p_activity_id,'active',now(),null)
  on conflict(activity_id) do update
    set status='active', ended_at=null, updated_at=now()
  returning id into v_session_id;

  return v_session_id;
end; $$;

create or replace function public.refresh_activity_public_state(p_activity_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare
  v_session_id uuid;
  v_lat double precision;
  v_lon double precision;
  v_count integer;
begin
  select id into v_session_id
  from public.live_sessions
  where activity_id=p_activity_id and status='active';

  if v_session_id is null then
    delete from public.activity_public_state where activity_id=p_activity_id;
    return;
  end if;

  select
    round(avg(latitude)::numeric, 3)::double precision,
    round(avg(longitude)::numeric, 3)::double precision,
    count(*)::integer
  into v_lat, v_lon, v_count
  from public.live_participants
  where session_id=v_session_id
    and sharing=true
    and public_approximate=true
    and recorded_at >= now() - interval '2 minutes';

  if coalesce(v_count,0)=0 or v_lat is null or v_lon is null then
    delete from public.activity_public_state where activity_id=p_activity_id;
    return;
  end if;

  insert into public.activity_public_state(activity_id,session_id,center_latitude,center_longitude,participant_count,updated_at)
  values(p_activity_id,v_session_id,v_lat,v_lon,v_count,now())
  on conflict(activity_id) do update set
    session_id=excluded.session_id,
    center_latitude=excluded.center_latitude,
    center_longitude=excluded.center_longitude,
    participant_count=excluded.participant_count,
    updated_at=now();
end; $$;

create or replace function public.publish_live_position(
  p_activity_id uuid,
  p_sequence bigint,
  p_latitude double precision,
  p_longitude double precision,
  p_accuracy_m double precision,
  p_heading_deg double precision default null,
  p_speed_mps double precision default null,
  p_recorded_at timestamptz default now(),
  p_share_participants boolean default true,
  p_share_leader boolean default true,
  p_public_approximate boolean default true
)
returns void language plpgsql security definer set search_path=public as $$
declare
  v_activity_status text;
  v_session_id uuid;
  v_role text;
  v_previous_sequence bigint;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;

  select a.status, ap.role
  into v_activity_status, v_role
  from public.activities a
  join public.activity_participants ap on ap.activity_id=a.id
  where a.id=p_activity_id
    and ap.user_id=auth.uid()
    and ap.status in ('approved','active');

  if not found then raise exception 'participant_required'; end if;
  if v_activity_status not in ('active','paused') then raise exception 'activity_not_live'; end if;

  if p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then
    raise exception 'invalid_coordinates';
  end if;
  if p_accuracy_m < 0 or p_accuracy_m > 5000 then raise exception 'invalid_accuracy'; end if;
  if p_heading_deg is not null and (p_heading_deg < 0 or p_heading_deg > 360) then raise exception 'invalid_heading'; end if;
  if p_speed_mps is not null and (p_speed_mps < 0 or p_speed_mps > 120) then raise exception 'invalid_speed'; end if;
  if p_recorded_at < now() - interval '5 minutes' or p_recorded_at > now() + interval '1 minute' then
    raise exception 'invalid_recorded_at';
  end if;

  v_session_id := public.ensure_live_session(p_activity_id);

  select sequence into v_previous_sequence
  from public.live_participants
  where session_id=v_session_id and user_id=auth.uid();

  if v_previous_sequence is not null and p_sequence <= v_previous_sequence then
    return;
  end if;

  insert into public.live_participants(
    session_id,activity_id,user_id,role,sharing,share_with_participants,share_with_leader,public_approximate,sequence,
    latitude,longitude,accuracy_m,heading_deg,speed_mps,recorded_at,received_at
  ) values (
    v_session_id,p_activity_id,auth.uid(),v_role,true,p_share_participants,p_share_leader,p_public_approximate,p_sequence,
    p_latitude,p_longitude,p_accuracy_m,p_heading_deg,p_speed_mps,p_recorded_at,now()
  )
  on conflict(session_id,user_id) do update set
    role=excluded.role,
    sharing=true,
    share_with_participants=excluded.share_with_participants,
    share_with_leader=excluded.share_with_leader,
    public_approximate=excluded.public_approximate,
    sequence=excluded.sequence,
    latitude=excluded.latitude,
    longitude=excluded.longitude,
    accuracy_m=excluded.accuracy_m,
    heading_deg=excluded.heading_deg,
    speed_mps=excluded.speed_mps,
    recorded_at=excluded.recorded_at,
    received_at=now(),
    updated_at=now();

  perform public.refresh_activity_public_state(p_activity_id);
end; $$;

create or replace function public.set_live_privacy(
  p_activity_id uuid,
  p_share_participants boolean,
  p_share_leader boolean,
  p_public_approximate boolean
)
returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  update public.live_participants
  set share_with_participants=p_share_participants,
      share_with_leader=p_share_leader,
      public_approximate=p_public_approximate,
      updated_at=now()
  where activity_id=p_activity_id and user_id=auth.uid();
  perform public.refresh_activity_public_state(p_activity_id);
end; $$;

create or replace function public.stop_live_sharing(p_activity_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  update public.live_participants
  set sharing=false, updated_at=now()
  where activity_id=p_activity_id and user_id=auth.uid();
  perform public.refresh_activity_public_state(p_activity_id);
end; $$;

-- Activity lifecycle owns the live session. Pausing keeps the session active;
-- finishing/cancelling immediately disables every participant and public state.
create or replace function public.sync_live_session_from_activity()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status='active' and old.status is distinct from 'active' then
    insert into public.live_sessions(activity_id,status,started_at,ended_at)
    values(new.id,'active',now(),null)
    on conflict(activity_id) do update set status='active', ended_at=null, updated_at=now();
  elsif new.status in ('finished','cancelled') and old.status is distinct from new.status then
    update public.live_sessions set status='ended', ended_at=now(), updated_at=now() where activity_id=new.id;
    update public.live_participants set sharing=false, updated_at=now() where activity_id=new.id;
    delete from public.activity_public_state where activity_id=new.id;
  end if;
  return new;
end; $$;

drop trigger if exists activities_sync_live_session on public.activities;
create trigger activities_sync_live_session
after update of status on public.activities
for each row execute procedure public.sync_live_session_from_activity();

-- RLS: exact participant coordinates are visible only inside the activity.
-- Public state is the deliberately reduced/rounded group location used by discovery/map UI.
alter table public.live_sessions enable row level security;
alter table public.live_participants enable row level security;
alter table public.activity_public_state enable row level security;

drop policy if exists live_sessions_select_participants on public.live_sessions;
create policy live_sessions_select_participants on public.live_sessions for select to authenticated using (
  public.is_live_activity_participant(activity_id,auth.uid()) or public.is_activity_leader(activity_id,auth.uid())
);

drop policy if exists live_participants_select_activity on public.live_participants;
create policy live_participants_select_activity on public.live_participants for select to authenticated using (
  user_id=auth.uid()
  or (share_with_leader and public.is_activity_leader(activity_id,auth.uid()))
  or (share_with_participants and public.is_live_activity_participant(activity_id,auth.uid()))
);

drop policy if exists activity_public_state_select_visible on public.activity_public_state;
create policy activity_public_state_select_visible on public.activity_public_state for select to authenticated using (
  public.can_view_activity(activity_id,auth.uid())
);

-- Writes happen only through security-definer RPCs above.
grant select on public.live_sessions to authenticated;
grant select on public.live_participants to authenticated;
grant select on public.activity_public_state to authenticated;
revoke insert,update,delete on public.live_sessions from authenticated;
revoke insert,update,delete on public.live_participants from authenticated;
revoke insert,update,delete on public.activity_public_state from authenticated;

grant execute on function public.ensure_live_session(uuid) to authenticated;
grant execute on function public.publish_live_position(uuid,bigint,double precision,double precision,double precision,double precision,double precision,timestamptz,boolean,boolean,boolean) to authenticated;
grant execute on function public.stop_live_sharing(uuid) to authenticated;
grant execute on function public.set_live_privacy(uuid,boolean,boolean,boolean) to authenticated;

-- Realtime: add the two client-facing live tables exactly once.
do $$ begin
  alter publication supabase_realtime add table public.live_participants;
exception when duplicate_object then null;
end $$;

do $$ begin
  alter publication supabase_realtime add table public.activity_public_state;
exception when duplicate_object then null;
end $$;
