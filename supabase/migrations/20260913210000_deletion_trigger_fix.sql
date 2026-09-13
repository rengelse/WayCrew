-- WayCrew v0.2.14 - deletion trigger fix + owner-only activity deletion
-- Run after 20260913203000_group_delete_route_creation.sql.

-- Cascading deletes remove participant/member rows after the parent row is already
-- being deleted. The old sync triggers tried to INSERT a chat again on DELETE,
-- which could violate the chats_*_id_fkey constraints. DELETE must only clean up
-- existing chat membership; it must never recreate the chat.
create or replace function public.sync_group_chat_member()
returns trigger language plpgsql security definer set search_path=public as $$
declare
  v_group_id uuid;
  v_user_id uuid;
  v_status text;
  v_role text;
  v_chat_id uuid;
begin
  if tg_op='DELETE' then
    v_group_id:=old.group_id;
    v_user_id:=old.user_id;
    select id into v_chat_id from public.chats where group_id=v_group_id;
    if v_chat_id is not null then
      delete from public.chat_members where chat_id=v_chat_id and user_id=v_user_id;
    end if;
    return old;
  end if;

  v_group_id:=new.group_id;
  v_user_id:=new.user_id;
  v_status:=new.status;
  v_role:=new.role;

  insert into public.chats(chat_type,group_id) values('group',v_group_id)
  on conflict (group_id) where group_id is not null do nothing;
  select id into v_chat_id from public.chats where group_id=v_group_id;

  if v_status='active' then
    insert into public.chat_members(chat_id,user_id,role)
    values(v_chat_id,v_user_id,case when v_role in ('owner','admin') then 'moderator' else 'member' end)
    on conflict(chat_id,user_id) do update set role=excluded.role,updated_at=now();
  else
    delete from public.chat_members where chat_id=v_chat_id and user_id=v_user_id;
  end if;
  return new;
end; $$;

create or replace function public.sync_activity_chat_member()
returns trigger language plpgsql security definer set search_path=public as $$
declare
  v_activity_id uuid;
  v_user_id uuid;
  v_status text;
  v_role text;
  v_chat_id uuid;
begin
  if tg_op='DELETE' then
    v_activity_id:=old.activity_id;
    v_user_id:=old.user_id;
    select id into v_chat_id from public.chats where activity_id=v_activity_id;
    if v_chat_id is not null then
      delete from public.chat_members where chat_id=v_chat_id and user_id=v_user_id;
    end if;
    return old;
  end if;

  v_activity_id:=new.activity_id;
  v_user_id:=new.user_id;
  v_status:=new.status;
  v_role:=new.role;

  insert into public.chats(chat_type,activity_id) values('activity',v_activity_id)
  on conflict (activity_id) where activity_id is not null do nothing;
  select id into v_chat_id from public.chats where activity_id=v_activity_id;

  if v_status in ('approved','active') then
    insert into public.chat_members(chat_id,user_id,role)
    values(v_chat_id,v_user_id,case when v_role='leader' then 'moderator' else 'member' end)
    on conflict(chat_id,user_id) do update set role=excluded.role,updated_at=now();
  else
    delete from public.chat_members where chat_id=v_chat_id and user_id=v_user_id;
  end if;
  return new;
end; $$;

-- Keep the group deletion RPC owner-only. With the corrected sync trigger,
-- ON DELETE CASCADE can now complete without attempting to recreate its chat.
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

-- Permanent activity deletion is intentionally restricted to the creator.
-- Related chats, participants, live data, route and stops are removed through
-- existing foreign-key cascades. History rows with ON DELETE SET NULL survive.
create or replace function public.delete_activity(p_activity_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  v_owner uuid;
begin
  if auth.uid() is null then raise exception 'auth_required'; end if;
  select created_by into v_owner from public.activities where id=p_activity_id;
  if v_owner is null then raise exception 'activity_not_found'; end if;
  if v_owner <> auth.uid() then raise exception 'activity_owner_required'; end if;
  delete from public.activities where id=p_activity_id;
end;
$$;

revoke all on function public.delete_activity(uuid) from public;
grant execute on function public.delete_activity(uuid) to authenticated;
