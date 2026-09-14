-- WayCrew v0.3.8 - scheduling, tracking lifecycle hardening and notification reliability.
-- Existing activities.starts_at remains the canonical required start timestamp.

-- If a participant leaves, is removed/rejected/withdrawn, stop sharing
-- immediately. publish_live_position already rejects future points, but this
-- trigger also removes the participant from live/public state without waiting
-- for the stale-position timeout.
create or replace function public.sync_live_sharing_from_participation()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_activity_id uuid;
  v_user_id uuid;
  v_new_status text;
begin
  if tg_op = 'DELETE' then
    v_activity_id := old.activity_id;
    v_user_id := old.user_id;
    v_new_status := null;
  else
    v_activity_id := new.activity_id;
    v_user_id := new.user_id;
    v_new_status := new.status;
  end if;

  if tg_op = 'DELETE' or v_new_status not in ('approved','active') then
    update public.live_participants
       set sharing=false, updated_at=now()
     where activity_id=v_activity_id and user_id=v_user_id;
    perform public.refresh_activity_public_state(v_activity_id);
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists activity_participants_sync_live_sharing on public.activity_participants;
create trigger activity_participants_sync_live_sharing
after update of status or delete on public.activity_participants
for each row execute procedure public.sync_live_sharing_from_participation();

-- Keep the server as the final authority: a client may not create a scheduled
-- activity with an empty/ancient start timestamp. "Start now" remains valid.
create or replace function public.validate_activity_schedule()
returns trigger
language plpgsql
set search_path=public
as $$
begin
  if new.starts_at is null then
    raise exception 'activity_start_required';
  end if;
  if new.status in ('draft','planned') and new.starts_at < now() - interval '5 minutes' then
    raise exception 'activity_start_in_past';
  end if;
  return new;
end;
$$;

drop trigger if exists activities_validate_schedule on public.activities;
create trigger activities_validate_schedule
before insert or update of starts_at,status on public.activities
for each row execute procedure public.validate_activity_schedule();

-- Realtime remains enabled for notifications. The Flutter client now rebuilds
-- its subscription on auth token rotation and retries once after an expired JWT.
do $$ begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then null;
end $$;
