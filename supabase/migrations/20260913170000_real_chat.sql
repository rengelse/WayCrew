-- Activity Network v0.2.4 - Real Chat
-- Run after 20260913162000_real_groups.sql.
-- Adds activity/group chats, server-maintained chat membership, messages and Realtime publication.

create extension if not exists pgcrypto;

create table if not exists public.chats (
  id uuid primary key default gen_random_uuid(),
  chat_type text not null check (chat_type in ('activity','group')),
  activity_id uuid references public.activities(id) on delete cascade,
  group_id uuid references public.groups(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chats_entity_exactly_one check (
    (chat_type='activity' and activity_id is not null and group_id is null) or
    (chat_type='group' and group_id is not null and activity_id is null)
  )
);

create unique index if not exists chats_activity_unique on public.chats(activity_id) where activity_id is not null;
create unique index if not exists chats_group_unique on public.chats(group_id) where group_id is not null;

create table if not exists public.chat_members (
  chat_id uuid not null references public.chats(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('member','moderator')),
  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (chat_id,user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats(id) on delete cascade,
  sender_id uuid references public.profiles(id) on delete set null,
  message_type text not null default 'text' check (message_type in ('text','system','location','image')),
  body text not null default '' check (char_length(body) <= 8000),
  important boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists chat_members_user_idx on public.chat_members(user_id,chat_id);
create index if not exists messages_chat_created_idx on public.messages(chat_id,created_at,id);

-- Reuse the common updated_at trigger from v0.2.1.
drop trigger if exists chats_set_updated_at on public.chats;
create trigger chats_set_updated_at before update on public.chats
for each row execute procedure public.set_updated_at();
drop trigger if exists chat_members_set_updated_at on public.chat_members;
create trigger chat_members_set_updated_at before update on public.chat_members
for each row execute procedure public.set_updated_at();
drop trigger if exists messages_set_updated_at on public.messages;
create trigger messages_set_updated_at before update on public.messages
for each row execute procedure public.set_updated_at();

-- RLS-safe helpers.
create or replace function public.is_chat_member(p_chat_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.chat_members cm
    where cm.chat_id=p_chat_id and cm.user_id=p_user_id
  );
$$;

create or replace function public.is_activity_chat_participant(p_activity_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.activity_participants ap
    where ap.activity_id=p_activity_id
      and ap.user_id=p_user_id
      and ap.status in ('approved','active')
  );
$$;

create or replace function public.can_send_important_chat_message(p_chat_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.chats c
    where c.id=p_chat_id and (
      (c.chat_type='activity' and public.is_activity_leader(c.activity_id,p_user_id)) or
      (c.chat_type='group' and public.is_group_admin(c.group_id,p_user_id))
    )
  );
$$;

-- Ensure one chat per activity/group. Client-facing functions require real membership.
create or replace function public.ensure_activity_chat(p_activity_id uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_chat_id uuid;
begin
  if not public.is_activity_chat_participant(p_activity_id,auth.uid()) then
    raise exception 'activity_chat_membership_required';
  end if;
  insert into public.chats(chat_type,activity_id)
  values('activity',p_activity_id)
  on conflict (activity_id) where activity_id is not null do update set updated_at=public.chats.updated_at
  returning id into v_chat_id;
  insert into public.chat_members(chat_id,user_id,role)
  values(v_chat_id,auth.uid(),case when public.is_activity_leader(p_activity_id,auth.uid()) then 'moderator' else 'member' end)
  on conflict(chat_id,user_id) do update set role=excluded.role,updated_at=now();
  return v_chat_id;
end; $$;

create or replace function public.ensure_group_chat(p_group_id uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_chat_id uuid;
begin
  if not public.is_group_member(p_group_id,auth.uid()) then
    raise exception 'group_chat_membership_required';
  end if;
  insert into public.chats(chat_type,group_id)
  values('group',p_group_id)
  on conflict (group_id) where group_id is not null do update set updated_at=public.chats.updated_at
  returning id into v_chat_id;
  insert into public.chat_members(chat_id,user_id,role)
  values(v_chat_id,auth.uid(),case when public.is_group_admin(p_group_id,auth.uid()) then 'moderator' else 'member' end)
  on conflict(chat_id,user_id) do update set role=excluded.role,updated_at=now();
  return v_chat_id;
end; $$;

-- Internal trigger helpers keep chat membership synchronized with the domain membership tables.
create or replace function public.sync_activity_chat_member()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_activity_id uuid; v_user_id uuid; v_status text; v_role text; v_chat_id uuid;
begin
  if tg_op='DELETE' then
    v_activity_id:=old.activity_id; v_user_id:=old.user_id; v_status:='removed'; v_role:=old.role;
  else
    v_activity_id:=new.activity_id; v_user_id:=new.user_id; v_status:=new.status; v_role:=new.role;
  end if;
  insert into public.chats(chat_type,activity_id) values('activity',v_activity_id)
  on conflict (activity_id) where activity_id is not null do nothing;
  select id into v_chat_id from public.chats where activity_id=v_activity_id;
  if tg_op<>'DELETE' and v_status in ('approved','active') then
    insert into public.chat_members(chat_id,user_id,role)
    values(v_chat_id,v_user_id,case when v_role='leader' then 'moderator' else 'member' end)
    on conflict(chat_id,user_id) do update set role=excluded.role,updated_at=now();
  else
    delete from public.chat_members where chat_id=v_chat_id and user_id=v_user_id;
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end; $$;

drop trigger if exists activity_participants_sync_chat on public.activity_participants;
create trigger activity_participants_sync_chat
after insert or update or delete on public.activity_participants
for each row execute procedure public.sync_activity_chat_member();

create or replace function public.sync_group_chat_member()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_group_id uuid; v_user_id uuid; v_status text; v_role text; v_chat_id uuid;
begin
  if tg_op='DELETE' then
    v_group_id:=old.group_id; v_user_id:=old.user_id; v_status:='removed'; v_role:=old.role;
  else
    v_group_id:=new.group_id; v_user_id:=new.user_id; v_status:=new.status; v_role:=new.role;
  end if;
  insert into public.chats(chat_type,group_id) values('group',v_group_id)
  on conflict (group_id) where group_id is not null do nothing;
  select id into v_chat_id from public.chats where group_id=v_group_id;
  if tg_op<>'DELETE' and v_status='active' then
    insert into public.chat_members(chat_id,user_id,role)
    values(v_chat_id,v_user_id,case when v_role in ('owner','admin') then 'moderator' else 'member' end)
    on conflict(chat_id,user_id) do update set role=excluded.role,updated_at=now();
  else
    delete from public.chat_members where chat_id=v_chat_id and user_id=v_user_id;
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end; $$;

drop trigger if exists group_members_sync_chat on public.group_members;
create trigger group_members_sync_chat
after insert or update or delete on public.group_members
for each row execute procedure public.sync_group_chat_member();

-- Create chats immediately for new entities, even before the first message.
create or replace function public.create_activity_chat()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.chats(chat_type,activity_id) values('activity',new.id)
  on conflict (activity_id) where activity_id is not null do nothing;
  return new;
end; $$;
drop trigger if exists activities_create_chat on public.activities;
create trigger activities_create_chat after insert on public.activities
for each row execute procedure public.create_activity_chat();

create or replace function public.create_group_chat()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.chats(chat_type,group_id) values('group',new.id)
  on conflict (group_id) where group_id is not null do nothing;
  return new;
end; $$;
drop trigger if exists groups_create_chat on public.groups;
create trigger groups_create_chat after insert on public.groups
for each row execute procedure public.create_group_chat();

-- Backfill chats and memberships for entities created before v0.2.4.
insert into public.chats(chat_type,activity_id)
select 'activity',a.id from public.activities a
on conflict (activity_id) where activity_id is not null do nothing;

insert into public.chats(chat_type,group_id)
select 'group',g.id from public.groups g
on conflict (group_id) where group_id is not null do nothing;

insert into public.chat_members(chat_id,user_id,role)
select c.id,ap.user_id,case when ap.role='leader' then 'moderator' else 'member' end
from public.activity_participants ap
join public.chats c on c.activity_id=ap.activity_id
where ap.status in ('approved','active')
on conflict(chat_id,user_id) do update set role=excluded.role,updated_at=now();

insert into public.chat_members(chat_id,user_id,role)
select c.id,gm.user_id,case when gm.role in ('owner','admin') then 'moderator' else 'member' end
from public.group_members gm
join public.chats c on c.group_id=gm.group_id
where gm.status='active'
on conflict(chat_id,user_id) do update set role=excluded.role,updated_at=now();

-- RLS: chat membership is maintained by triggers/RPCs, not by the client.
alter table public.chats enable row level security;
alter table public.chat_members enable row level security;
alter table public.messages enable row level security;

drop policy if exists chats_select_members on public.chats;
create policy chats_select_members on public.chats for select to authenticated
using (public.is_chat_member(id,auth.uid()));

drop policy if exists chat_members_select_members on public.chat_members;
create policy chat_members_select_members on public.chat_members for select to authenticated
using (public.is_chat_member(chat_id,auth.uid()));

drop policy if exists messages_select_members on public.messages;
create policy messages_select_members on public.messages for select to authenticated
using (public.is_chat_member(chat_id,auth.uid()));

drop policy if exists messages_insert_members on public.messages;
create policy messages_insert_members on public.messages for insert to authenticated
with check (
  sender_id=auth.uid()
  and public.is_chat_member(chat_id,auth.uid())
  and message_type in ('text','location','image')
  and (not important or public.can_send_important_chat_message(chat_id,auth.uid()))
  and char_length(trim(body)) between 1 and 8000
);

-- No client UPDATE/DELETE policies yet. Message moderation/editing comes later.
grant select on public.chats to authenticated;
grant select on public.chat_members to authenticated;
grant select,insert on public.messages to authenticated;
grant execute on function public.ensure_activity_chat(uuid) to authenticated;
grant execute on function public.ensure_group_chat(uuid) to authenticated;

-- Supabase Realtime needs messages in the realtime publication.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end $$;
