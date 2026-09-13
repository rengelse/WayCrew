-- Activity Network v0.2.3 - Real Groups
-- Run after v0.2.2.

create extension if not exists pgcrypto;

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 2 and 120),
  activity_type text not null references public.activity_types(id),
  region text not null default '',
  description text not null default '',
  visibility text not null default 'public' check (visibility in ('public','private')),
  join_mode text not null default 'request' check (join_mode in ('open','request','inviteOnly')),
  members_can_create_activities boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','admin','member')),
  status text not null default 'requested' check (status in ('active','requested','invited','left','removed')),
  requested_at timestamptz not null default now(),
  joined_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (group_id,user_id)
);

create table if not exists public.group_posts (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 4000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists group_members_user_idx on public.group_members(user_id,status);
create index if not exists group_posts_group_created_idx on public.group_posts(group_id,created_at desc);
create index if not exists groups_visibility_idx on public.groups(visibility,activity_type);

-- Attach activities to groups now that groups exist.
do $$ begin
  if not exists (
    select 1 from pg_constraint where conname='activities_group_id_fkey'
  ) then
    alter table public.activities
      add constraint activities_group_id_fkey foreign key (group_id) references public.groups(id) on delete set null;
  end if;
end $$;
create index if not exists activities_group_idx on public.activities(group_id,starts_at);

-- Keep timestamps consistent.
drop trigger if exists groups_set_updated_at on public.groups;
create trigger groups_set_updated_at before update on public.groups
for each row execute procedure public.set_updated_at();
drop trigger if exists group_members_set_updated_at on public.group_members;
create trigger group_members_set_updated_at before update on public.group_members
for each row execute procedure public.set_updated_at();
drop trigger if exists group_posts_set_updated_at on public.group_posts;
create trigger group_posts_set_updated_at before update on public.group_posts
for each row execute procedure public.set_updated_at();

-- Security-definer helpers avoid recursive RLS lookups.
create or replace function public.is_group_member(p_group_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.group_members
    where group_id=p_group_id and user_id=p_user_id and status='active');
$$;

create or replace function public.group_role(p_group_id uuid, p_user_id uuid default auth.uid())
returns text language sql stable security definer set search_path=public as $$
  select role from public.group_members
  where group_id=p_group_id and user_id=p_user_id and status='active' limit 1;
$$;

create or replace function public.is_group_admin(p_group_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public as $$
  select coalesce(public.group_role(p_group_id,p_user_id) in ('owner','admin'),false);
$$;

create or replace function public.can_view_group(p_group_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.groups g where g.id=p_group_id and
    (g.visibility='public' or public.is_group_member(g.id,p_user_id) or g.created_by=p_user_id));
$$;

create or replace function public.can_create_group_activity(p_group_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.groups g where g.id=p_group_id and (
    public.is_group_admin(g.id,p_user_id) or
    (g.members_can_create_activities and public.is_group_member(g.id,p_user_id))
  ));
$$;

create or replace function public.group_active_member_count(p_group_id uuid)
returns integer language sql stable security definer set search_path=public as $$
  select case when public.can_view_group(p_group_id,auth.uid()) then
    (select count(*)::integer from public.group_members where group_id=p_group_id and status='active')
  else 0 end;
$$;

create or replace function public.group_upcoming_count(p_group_id uuid)
returns integer language sql stable security definer set search_path=public as $$
  select case when public.can_view_group(p_group_id,auth.uid()) then
    (select count(*)::integer from public.activities where group_id=p_group_id and status not in ('finished','cancelled'))
  else 0 end;
$$;

create or replace function public.group_add_creator_as_owner()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.group_members(group_id,user_id,role,status,joined_at)
  values(new.id,new.created_by,'owner','active',now())
  on conflict(group_id,user_id) do update set role='owner',status='active',joined_at=coalesce(public.group_members.joined_at,now()),updated_at=now();
  return new;
end; $$;
drop trigger if exists groups_add_creator_as_owner on public.groups;
create trigger groups_add_creator_as_owner after insert on public.groups
for each row execute procedure public.group_add_creator_as_owner();

create or replace function public.join_open_group(p_group_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare g public.groups%rowtype;
begin
  select * into g from public.groups where id=p_group_id for update;
  if not found then raise exception 'group_not_found'; end if;
  if g.visibility <> 'public' or g.join_mode <> 'open' then raise exception 'direct_join_not_allowed'; end if;
  insert into public.group_members(group_id,user_id,role,status,joined_at)
  values(p_group_id,auth.uid(),'member','active',now())
  on conflict(group_id,user_id) do update set role='member',status='active',joined_at=coalesce(public.group_members.joined_at,now()),updated_at=now();
end; $$;

create or replace function public.request_group_membership(p_group_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare g public.groups%rowtype;
begin
  select * into g from public.groups where id=p_group_id;
  if not found then raise exception 'group_not_found'; end if;
  if g.visibility <> 'public' or g.join_mode <> 'request' then raise exception 'request_not_allowed'; end if;
  insert into public.group_members(group_id,user_id,role,status,requested_at)
  values(p_group_id,auth.uid(),'member','requested',now())
  on conflict(group_id,user_id) do update set role='member',status='requested',requested_at=now(),updated_at=now();
end; $$;

create or replace function public.approve_group_membership(p_group_id uuid, p_user_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.is_group_admin(p_group_id) then raise exception 'group_admin_required'; end if;
  update public.group_members set status='active',joined_at=coalesce(joined_at,now()),updated_at=now()
  where group_id=p_group_id and user_id=p_user_id and status in ('requested','invited');
  if not found then raise exception 'membership_request_not_found'; end if;
end; $$;

create or replace function public.reject_group_membership(p_group_id uuid, p_user_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.is_group_admin(p_group_id) then raise exception 'group_admin_required'; end if;
  update public.group_members set status='removed',updated_at=now()
  where group_id=p_group_id and user_id=p_user_id and status='requested';
  if not found then raise exception 'membership_request_not_found'; end if;
end; $$;

create or replace function public.change_group_member_role(p_group_id uuid, p_user_id uuid, p_role text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if public.group_role(p_group_id) <> 'owner' then raise exception 'group_owner_required'; end if;
  if p_role not in ('admin','member') then raise exception 'invalid_group_role'; end if;
  update public.group_members set role=p_role,updated_at=now()
  where group_id=p_group_id and user_id=p_user_id and status='active' and role<>'owner';
  if not found then raise exception 'member_not_found_or_owner'; end if;
end; $$;

create or replace function public.remove_group_member(p_group_id uuid, p_user_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare actor_role text; target_role text;
begin
  actor_role := public.group_role(p_group_id);
  if actor_role not in ('owner','admin') then raise exception 'group_admin_required'; end if;
  select role into target_role from public.group_members where group_id=p_group_id and user_id=p_user_id and status='active';
  if target_role is null then raise exception 'member_not_found'; end if;
  if target_role='owner' then raise exception 'owner_cannot_be_removed'; end if;
  if actor_role='admin' and target_role='admin' then raise exception 'owner_required_to_remove_admin'; end if;
  update public.group_members set status='removed',updated_at=now() where group_id=p_group_id and user_id=p_user_id;
end; $$;

create or replace function public.leave_group(p_group_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if public.group_role(p_group_id)='owner' then raise exception 'owner_cannot_leave'; end if;
  update public.group_members set status='left',updated_at=now() where group_id=p_group_id and user_id=auth.uid();
end; $$;

-- Extend activity visibility for group-only activities.
create or replace function public.can_view_activity(p_activity_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.activities a where a.id=p_activity_id and (
    a.created_by=p_user_id or
    a.participation_mode in ('open','request') or
    public.is_activity_participant(a.id,p_user_id) or
    (a.participation_mode='groupOnly' and a.group_id is not null and public.is_group_member(a.group_id,p_user_id))
  ));
$$;

alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_posts enable row level security;

-- Groups: public discovery; private groups only for members/creator.
drop policy if exists groups_select_visible on public.groups;
create policy groups_select_visible on public.groups for select to authenticated using (public.can_view_group(id,auth.uid()));
drop policy if exists groups_insert_own on public.groups;
create policy groups_insert_own on public.groups for insert to authenticated with check (created_by=auth.uid());
drop policy if exists groups_update_admin on public.groups;
create policy groups_update_admin on public.groups for update to authenticated
using (public.is_group_admin(id,auth.uid())) with check (public.is_group_admin(id,auth.uid()));

-- Membership rows can be read by group members/admins; own pending row remains visible.
drop policy if exists group_members_select_visible on public.group_members;
create policy group_members_select_visible on public.group_members for select to authenticated using (
  user_id=auth.uid() or public.is_group_member(group_id,auth.uid()) or public.is_group_admin(group_id,auth.uid())
);

-- Posts are member-only. Author may delete own post; admins may delete any.
drop policy if exists group_posts_select_members on public.group_posts;
create policy group_posts_select_members on public.group_posts for select to authenticated using (public.is_group_member(group_id,auth.uid()));
drop policy if exists group_posts_insert_members on public.group_posts;
create policy group_posts_insert_members on public.group_posts for insert to authenticated with check (
  author_id=auth.uid() and public.is_group_member(group_id,auth.uid())
);
drop policy if exists group_posts_delete_author_admin on public.group_posts;
create policy group_posts_delete_author_admin on public.group_posts for delete to authenticated using (
  author_id=auth.uid() or public.is_group_admin(group_id,auth.uid())
);

-- Activity group linkage is constrained to groups where the caller may create activities.
drop policy if exists activities_select_visible on public.activities;
create policy activities_select_visible on public.activities for select to authenticated using (public.can_view_activity(id,auth.uid()));
drop policy if exists activities_insert_own on public.activities;
create policy activities_insert_own on public.activities for insert to authenticated with check (
  created_by=auth.uid() and (group_id is null or public.can_create_group_activity(group_id,auth.uid()))
);
drop policy if exists activities_update_leader on public.activities;
create policy activities_update_leader on public.activities for update to authenticated using (public.is_activity_leader(id)) with check (
  public.is_activity_leader(id) and (group_id is null or public.can_create_group_activity(group_id,auth.uid()))
);

-- Group-context profile visibility, in addition to existing own/activity policies.
drop policy if exists profiles_select_group_context on public.profiles;
create policy profiles_select_group_context on public.profiles for select to authenticated using (
  exists(select 1 from public.group_members gm
    where gm.user_id=profiles.id and gm.status='active' and public.is_group_member(gm.group_id,auth.uid()))
);

grant select,insert,update on public.groups to authenticated;
grant select on public.group_members to authenticated;
grant select,insert,delete on public.group_posts to authenticated;
grant execute on function public.join_open_group(uuid) to authenticated;
grant execute on function public.request_group_membership(uuid) to authenticated;
grant execute on function public.approve_group_membership(uuid,uuid) to authenticated;
grant execute on function public.reject_group_membership(uuid,uuid) to authenticated;
grant execute on function public.change_group_member_role(uuid,uuid,text) to authenticated;
grant execute on function public.remove_group_member(uuid,uuid) to authenticated;
grant execute on function public.leave_group(uuid) to authenticated;
grant execute on function public.group_active_member_count(uuid) to authenticated;
grant execute on function public.group_upcoming_count(uuid) to authenticated;
