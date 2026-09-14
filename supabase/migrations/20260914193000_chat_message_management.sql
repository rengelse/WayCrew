-- WayCrew v0.3.9 - Chat Message Management
-- Soft-delete chat messages while preserving a locked audit copy.

alter table public.messages
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references public.profiles(id) on delete set null;

create index if not exists messages_deleted_idx on public.messages(chat_id, deleted_at);

create table if not exists public.message_delete_audit (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null,
  chat_id uuid not null,
  sender_id uuid,
  message_type text not null,
  body text not null,
  important boolean not null default false,
  message_created_at timestamptz not null,
  deleted_by uuid not null,
  deleted_at timestamptz not null default now()
);

alter table public.message_delete_audit enable row level security;
revoke all on table public.message_delete_audit from anon, authenticated;

create or replace function public.delete_chat_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  v_message public.messages%rowtype;
  v_chat public.chats%rowtype;
  v_actor uuid := auth.uid();
  v_allowed boolean := false;
begin
  if v_actor is null then
    raise exception 'authentication_required';
  end if;

  select * into v_message
  from public.messages
  where id = p_message_id
  for update;

  if not found then
    raise exception 'message_not_found';
  end if;

  if v_message.deleted_at is not null then
    return;
  end if;

  if v_message.message_type = 'system' then
    raise exception 'system_message_cannot_be_deleted';
  end if;

  select * into v_chat from public.chats where id = v_message.chat_id;
  if not found then
    raise exception 'chat_not_found';
  end if;

  if v_message.sender_id = v_actor then
    v_allowed := true;
  elsif v_chat.chat_type = 'activity' and public.is_activity_leader(v_chat.activity_id, v_actor) then
    v_allowed := true;
  elsif v_chat.chat_type = 'group' and public.is_group_admin(v_chat.group_id, v_actor) then
    v_allowed := true;
  end if;

  if not v_allowed then
    raise exception 'message_delete_not_allowed';
  end if;

  insert into public.message_delete_audit(
    message_id,
    chat_id,
    sender_id,
    message_type,
    body,
    important,
    message_created_at,
    deleted_by
  ) values (
    v_message.id,
    v_message.chat_id,
    v_message.sender_id,
    v_message.message_type,
    v_message.body,
    v_message.important,
    v_message.created_at,
    v_actor
  );

  update public.messages
  set body = '',
      important = false,
      deleted_at = now(),
      deleted_by = v_actor,
      updated_at = now()
  where id = p_message_id;
end;
$$;

revoke all on function public.delete_chat_message(uuid) from public, anon;
grant execute on function public.delete_chat_message(uuid) to authenticated;
