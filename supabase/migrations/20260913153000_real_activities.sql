-- Activity Network v0.2.2 - Real Activities
-- Run after v0.2.1. Creates the real activity domain and atomic RPC operations.

create extension if not exists pgcrypto;

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles(id) on delete cascade,
  activity_type text not null references public.activity_types(id),
  title text not null check (char_length(trim(title)) between 2 and 120),
  description text not null default '',
  status text not null default 'planned' check (status in ('draft','planned','gathering','active','paused','finished','cancelled')),
  participation_mode text not null default 'request' check (participation_mode in ('open','request','groupOnly','private')),
  starts_at timestamptz not null,
  meeting_point text not null default '',
  route_label text not null default 'Rute ikke satt',
  max_participants integer not null default 12 check (max_participants between 2 and 500),
  distance_km numeric(8,2) not null default 0 check (distance_km >= 0),
  pace text not null default 'Normal',
  surface text not null default 'Ikke satt',
  metadata jsonb not null default '{}'::jsonb,
  group_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  finished_at timestamptz
);

create table if not exists public.activity_participants (
  activity_id uuid not null references public.activities(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'participant' check (role in ('leader','sweep','participant')),
  status text not null default 'requested' check (status in ('invited','requested','approved','active','rejected','withdrawn','left','removed')),
  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (activity_id, user_id)
);

create table if not exists public.activity_routes (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activities(id) on delete cascade,
  label text not null default 'Rute',
  route_geojson jsonb,
  distance_km numeric(8,2) not null default 0 check (distance_km >= 0),
  is_primary boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists activity_routes_one_primary_idx
on public.activity_routes(activity_id) where is_primary;

create table if not exists public.activity_stops (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activities(id) on delete cascade,
  name text not null,
  stop_type text not null default 'stop' check (stop_type in ('meeting','stop','destination')),
  sort_order integer not null default 0,
  latitude double precision,
  longitude double precision,
  eta_minutes integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists activities_starts_at_idx on public.activities(starts_at);
create index if not exists activities_status_idx on public.activities(status);
create index if not exists activities_type_idx on public.activities(activity_type);
create index if not exists activity_participants_user_idx on public.activity_participants(user_id);
create index if not exists activity_stops_activity_order_idx on public.activity_stops(activity_id, sort_order);

-- Keep updated_at consistent.
drop trigger if exists activities_set_updated_at on public.activities;
create trigger activities_set_updated_at before update on public.activities
for each row execute procedure public.set_updated_at();
drop trigger if exists activity_participants_set_updated_at on public.activity_participants;
create trigger activity_participants_set_updated_at before update on public.activity_participants
for each row execute procedure public.set_updated_at();
drop trigger if exists activity_routes_set_updated_at on public.activity_routes;
create trigger activity_routes_set_updated_at before update on public.activity_routes
for each row execute procedure public.set_updated_at();
drop trigger if exists activity_stops_set_updated_at on public.activity_stops;
create trigger activity_stops_set_updated_at before update on public.activity_stops
for each row execute procedure public.set_updated_at();

-- Creator is always inserted as leader atomically with the activity.
create or replace function public.activity_add_creator_as_leader()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.activity_participants(activity_id, user_id, role, status)
  values (new.id, new.created_by, 'leader', case when new.status = 'active' then 'active' else 'approved' end)
  on conflict (activity_id, user_id) do update set role='leader', status=excluded.status;
  return new;
end; $$;
drop trigger if exists activities_add_creator_as_leader on public.activities;
create trigger activities_add_creator_as_leader after insert on public.activities
for each row execute procedure public.activity_add_creator_as_leader();

create or replace function public.is_activity_leader(p_activity_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.activity_participants
    where activity_id=p_activity_id and user_id=p_user_id and role='leader' and status in ('approved','active'));
$$;

create or replace function public.activity_confirmed_count(p_activity_id uuid)
returns integer language sql stable security definer set search_path = public as $$
  select count(*)::integer from public.activity_participants
  where activity_id=p_activity_id and status in ('approved','active');
$$;

create or replace function public.is_activity_participant(p_activity_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.activity_participants where activity_id=p_activity_id and user_id=p_user_id and status not in ('rejected','removed','left','withdrawn'));
$$;

create or replace function public.can_view_activity(p_activity_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.activities a where a.id=p_activity_id and
    (a.created_by=p_user_id or a.participation_mode in ('open','request') or public.is_activity_participant(a.id,p_user_id)));
$$;

create or replace function public.can_view_activity_profile(p_profile_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public as $$
  select p_profile_id=p_user_id or exists(
    select 1 from public.activity_participants ap
    where ap.user_id=p_profile_id and public.can_view_activity(ap.activity_id,p_user_id)
  );
$$;

create or replace function public.request_to_join_activity(p_activity_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare a public.activities%rowtype;
begin
  select * into a from public.activities where id=p_activity_id;
  if not found or a.status in ('finished','cancelled') then raise exception 'activity_unavailable'; end if;
  if a.participation_mode <> 'request' then raise exception 'request_not_allowed'; end if;
  if public.activity_confirmed_count(p_activity_id) >= a.max_participants then raise exception 'activity_full'; end if;
  insert into public.activity_participants(activity_id,user_id,role,status)
  values(p_activity_id,auth.uid(),'participant','requested')
  on conflict(activity_id,user_id) do update set status='requested', role='participant', updated_at=now();
end; $$;

create or replace function public.join_open_activity(p_activity_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare a public.activities%rowtype;
begin
  select * into a from public.activities where id=p_activity_id for update;
  if not found or a.status in ('finished','cancelled') then raise exception 'activity_unavailable'; end if;
  if a.participation_mode <> 'open' then raise exception 'direct_join_not_allowed'; end if;
  if public.activity_confirmed_count(p_activity_id) >= a.max_participants then raise exception 'activity_full'; end if;
  insert into public.activity_participants(activity_id,user_id,role,status)
  values(p_activity_id,auth.uid(),'participant','approved')
  on conflict(activity_id,user_id) do update set status='approved', role='participant', updated_at=now();
end; $$;

create or replace function public.approve_activity_participant(p_activity_id uuid, p_user_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare a public.activities%rowtype;
begin
  if not public.is_activity_leader(p_activity_id) then raise exception 'leader_required'; end if;
  select * into a from public.activities where id=p_activity_id for update;
  if public.activity_confirmed_count(p_activity_id) >= a.max_participants then raise exception 'activity_full'; end if;
  update public.activity_participants set status='approved', updated_at=now()
  where activity_id=p_activity_id and user_id=p_user_id and status in ('requested','invited');
  if not found then raise exception 'participant_request_not_found'; end if;
end; $$;

create or replace function public.set_activity_status(p_activity_id uuid, p_status text)
returns void language plpgsql security definer set search_path=public as $$
declare current_status text;
begin
  if not public.is_activity_leader(p_activity_id) then raise exception 'leader_required'; end if;
  select status into current_status from public.activities where id=p_activity_id for update;
  if not found then raise exception 'activity_not_found'; end if;
  if not ((current_status='draft' and p_status in ('planned','cancelled')) or
          (current_status='planned' and p_status in ('gathering','cancelled')) or
          (current_status='gathering' and p_status in ('active','finished','cancelled')) or
          (current_status='active' and p_status in ('paused','finished')) or
          (current_status='paused' and p_status in ('active','finished'))) then
    raise exception 'invalid_status_transition';
  end if;
  update public.activities set status=p_status, finished_at=case when p_status='finished' then now() else finished_at end where id=p_activity_id;
  if p_status='active' then
    update public.activity_participants set status='active' where activity_id=p_activity_id and status='approved';
  elsif p_status='finished' then
    update public.activity_participants set status='approved' where activity_id=p_activity_id and status='active';
  end if;
end; $$;

create or replace function public.update_activity_meeting_point(p_activity_id uuid, p_meeting_point text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.is_activity_leader(p_activity_id) then raise exception 'leader_required'; end if;
  if nullif(trim(p_meeting_point),'') is null then raise exception 'meeting_point_required'; end if;
  update public.activities set meeting_point=trim(p_meeting_point) where id=p_activity_id;
  update public.activity_stops set name=trim(p_meeting_point) where activity_id=p_activity_id and stop_type='meeting';
  if not found then
    insert into public.activity_stops(activity_id,name,stop_type,sort_order) values(p_activity_id,trim(p_meeting_point),'meeting',0);
  end if;
end; $$;

create or replace function public.leave_activity(p_activity_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if public.is_activity_leader(p_activity_id) then raise exception 'leader_cannot_leave'; end if;
  update public.activity_participants set status='left', updated_at=now()
  where activity_id=p_activity_id and user_id=auth.uid();
end; $$;

-- RLS. Discovery exposes open/request activities; private/group-only remain visible to their participants/creator.
alter table public.activities enable row level security;
alter table public.activity_participants enable row level security;
alter table public.activity_routes enable row level security;
alter table public.activity_stops enable row level security;

drop policy if exists activities_select_visible on public.activities;
create policy activities_select_visible on public.activities for select to authenticated using (
  created_by=auth.uid() or participation_mode in ('open','request') or public.is_activity_participant(id,auth.uid())
);
drop policy if exists activities_insert_own on public.activities;
create policy activities_insert_own on public.activities for insert to authenticated with check (created_by=auth.uid());
drop policy if exists activities_update_leader on public.activities;
create policy activities_update_leader on public.activities for update to authenticated using (public.is_activity_leader(id)) with check (public.is_activity_leader(id));

drop policy if exists participants_select_visible on public.activity_participants;
create policy participants_select_visible on public.activity_participants for select to authenticated using (
  user_id=auth.uid() or public.can_view_activity(activity_id,auth.uid())
);

drop policy if exists routes_select_visible on public.activity_routes;
create policy routes_select_visible on public.activity_routes for select to authenticated using (public.can_view_activity(activity_id,auth.uid()));
drop policy if exists routes_write_leader on public.activity_routes;
create policy routes_write_leader on public.activity_routes for all to authenticated using (public.is_activity_leader(activity_id)) with check (public.is_activity_leader(activity_id));

drop policy if exists stops_select_visible on public.activity_stops;
create policy stops_select_visible on public.activity_stops for select to authenticated using (public.can_view_activity(activity_id,auth.uid()));
drop policy if exists stops_write_leader on public.activity_stops;
create policy stops_write_leader on public.activity_stops for all to authenticated using (public.is_activity_leader(activity_id)) with check (public.is_activity_leader(activity_id));

-- Participant profiles are readable when they participate in an activity visible to the requesting user.
drop policy if exists profiles_select_activity_context on public.profiles;
create policy profiles_select_activity_context on public.profiles for select to authenticated using (public.can_view_activity_profile(id,auth.uid()));

grant select,insert,update on public.activities to authenticated;
grant select on public.activity_participants to authenticated;
grant select,insert,update,delete on public.activity_routes to authenticated;
grant select,insert,update,delete on public.activity_stops to authenticated;
grant execute on function public.request_to_join_activity(uuid) to authenticated;
grant execute on function public.join_open_activity(uuid) to authenticated;
grant execute on function public.approve_activity_participant(uuid,uuid) to authenticated;
grant execute on function public.set_activity_status(uuid,text) to authenticated;
grant execute on function public.update_activity_meeting_point(uuid,text) to authenticated;
grant execute on function public.leave_activity(uuid) to authenticated;
