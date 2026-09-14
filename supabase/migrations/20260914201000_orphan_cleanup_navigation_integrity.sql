-- WayCrew v0.4.2 - Orphan Cleanup & Navigation Integrity
-- Cleans stale notification targets, removes chat notifications when membership ends,
-- and adds a server-side notification route resolver that validates target existence/access.

create or replace function public.resolve_notification_route(p_notification_id uuid)
returns text
language plpgsql
security definer
set search_path=public
as $$
declare
  n public.notifications%rowtype;
  v_valid boolean := false;
begin
  if auth.uid() is null then
    raise exception 'auth_required';
  end if;

  select * into n
  from public.notifications
  where id=p_notification_id and user_id=auth.uid();

  if not found or n.route is null or btrim(n.route)='' then
    return null;
  end if;

  if n.entity_type='history' then
    select exists(
      select 1 from public.activity_history h
      where h.id=n.entity_id and h.user_id=auth.uid()
    ) into v_valid;

  elsif n.entity_type='activity' then
    if n.route like '%/chat' then
      select exists(select 1 from public.activities a where a.id=n.entity_id)
         and public.is_activity_chat_participant(n.entity_id,auth.uid())
      into v_valid;
    else
      select exists(
        select 1
        from public.activities a
        where a.id=n.entity_id
          and (
            a.created_by=auth.uid()
            or exists(
              select 1 from public.activity_participants ap
              where ap.activity_id=a.id
                and ap.user_id=auth.uid()
                and ap.status in ('requested','approved','active')
            )
          )
      ) into v_valid;
    end if;

  elsif n.entity_type='group' then
    if n.route like '%/admin' then
      select exists(select 1 from public.groups g where g.id=n.entity_id)
         and public.is_group_admin(n.entity_id,auth.uid())
      into v_valid;
    elsif n.route like '%/chat' then
      select exists(select 1 from public.groups g where g.id=n.entity_id)
         and public.is_group_member(n.entity_id,auth.uid())
      into v_valid;
    else
      select exists(select 1 from public.groups g where g.id=n.entity_id)
         and public.is_group_member(n.entity_id,auth.uid())
      into v_valid;
    end if;

  else
    -- Legacy notifications without a typed target can still use their stored route.
    v_valid := true;
  end if;

  if v_valid then
    return n.route;
  end if;
  return null;
end;
$$;

revoke all on function public.resolve_notification_route(uuid) from public;
grant execute on function public.resolve_notification_route(uuid) to authenticated;

-- Remove notification rows whose target entity is already gone.
delete from public.notifications n
where n.entity_type='activity'
  and n.entity_id is not null
  and not exists(select 1 from public.activities a where a.id=n.entity_id);

delete from public.notifications n
where n.entity_type='group'
  and n.entity_id is not null
  and not exists(select 1 from public.groups g where g.id=n.entity_id);

delete from public.notifications n
where n.entity_type='history'
  and n.entity_id is not null
  and not exists(select 1 from public.activity_history h where h.id=n.entity_id and h.user_id=n.user_id);

-- Remove stale chat notifications for users who are no longer eligible for the chat.
delete from public.notifications n
where n.entity_type='activity'
  and n.entity_id is not null
  and n.route like '%/chat'
  and not public.is_activity_chat_participant(n.entity_id,n.user_id);

delete from public.notifications n
where n.entity_type='group'
  and n.entity_id is not null
  and n.route like '%/chat'
  and not public.is_group_member(n.entity_id,n.user_id);

-- Future entity deletion automatically removes all notifications pointing at it.
create or replace function public.cleanup_notifications_for_deleted_entity()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if tg_table_name='activities' then
    delete from public.notifications where entity_type='activity' and entity_id=old.id;
  elsif tg_table_name='groups' then
    delete from public.notifications where entity_type='group' and entity_id=old.id;
  elsif tg_table_name='activity_history' then
    delete from public.notifications
    where entity_type='history' and entity_id=old.id and user_id=old.user_id;
  end if;
  return old;
end;
$$;

revoke all on function public.cleanup_notifications_for_deleted_entity() from public;

drop trigger if exists cleanup_activity_notifications_on_delete on public.activities;
create trigger cleanup_activity_notifications_on_delete
before delete on public.activities
for each row execute procedure public.cleanup_notifications_for_deleted_entity();

drop trigger if exists cleanup_group_notifications_on_delete on public.groups;
create trigger cleanup_group_notifications_on_delete
before delete on public.groups
for each row execute procedure public.cleanup_notifications_for_deleted_entity();

drop trigger if exists cleanup_history_notifications_on_delete on public.activity_history;
create trigger cleanup_history_notifications_on_delete
before delete on public.activity_history
for each row execute procedure public.cleanup_notifications_for_deleted_entity();

-- If activity/group membership ends, old message notifications must not remain navigable.
create or replace function public.cleanup_chat_notifications_on_membership_change()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_entity_id uuid;
  v_user_id uuid;
  v_has_access boolean;
begin
  if tg_table_name='activity_participants' then
    if tg_op='DELETE' then
      v_entity_id := old.activity_id;
      v_user_id := old.user_id;
      v_has_access := false;
    else
      v_entity_id := new.activity_id;
      v_user_id := new.user_id;
      v_has_access := new.status in ('approved','active');
    end if;
    if not v_has_access then
      delete from public.notifications
      where user_id=v_user_id and entity_type='activity' and entity_id=v_entity_id and route like '%/chat';
    end if;
  elsif tg_table_name='group_members' then
    if tg_op='DELETE' then
      v_entity_id := old.group_id;
      v_user_id := old.user_id;
      v_has_access := false;
    else
      v_entity_id := new.group_id;
      v_user_id := new.user_id;
      v_has_access := new.status='active';
    end if;
    if not v_has_access then
      delete from public.notifications
      where user_id=v_user_id and entity_type='group' and entity_id=v_entity_id and route like '%/chat';
    end if;
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;

revoke all on function public.cleanup_chat_notifications_on_membership_change() from public;

drop trigger if exists cleanup_activity_chat_notifications_on_membership on public.activity_participants;
create trigger cleanup_activity_chat_notifications_on_membership
after update of status or delete on public.activity_participants
for each row execute procedure public.cleanup_chat_notifications_on_membership_change();

drop trigger if exists cleanup_group_chat_notifications_on_membership on public.group_members;
create trigger cleanup_group_chat_notifications_on_membership
after update of status or delete on public.group_members
for each row execute procedure public.cleanup_chat_notifications_on_membership_change();
