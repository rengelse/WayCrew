-- WayCrew v0.4.4 – Live Participant Profile Cards
-- Restricts profile-card access to participants who share the same active/paused activity.

create or replace function public.can_read_live_participant_profile(
  p_profile_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_profile_id = p_user_id or exists (
    select 1
    from public.activities a
    join public.activity_participants viewer
      on viewer.activity_id = a.id
     and viewer.user_id = p_user_id
     and viewer.status in ('approved', 'active')
    join public.activity_participants target
      on target.activity_id = a.id
     and target.user_id = p_profile_id
     and target.status in ('approved', 'active')
    where a.status in ('active', 'paused')
      and not exists (
        select 1 from public.blocked_users b
        where (b.user_id = p_user_id and b.blocked_user_id = p_profile_id)
           or (b.user_id = p_profile_id and b.blocked_user_id = p_user_id)
      )
  );
$$;

revoke all on function public.can_read_live_participant_profile(uuid, uuid) from public, anon;
grant execute on function public.can_read_live_participant_profile(uuid, uuid) to authenticated;

create or replace function public.get_live_participant_profile(
  p_activity_id uuid,
  p_user_id uuid
)
returns table (
  id uuid,
  display_name text,
  region text,
  bio text,
  avatar_path text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (
    select 1
    from public.activities a
    join public.activity_participants viewer
      on viewer.activity_id = a.id
     and viewer.user_id = auth.uid()
     and viewer.status in ('approved', 'active')
    join public.activity_participants target
      on target.activity_id = a.id
     and target.user_id = p_user_id
     and target.status in ('approved', 'active')
    where a.id = p_activity_id
      and a.status in ('active', 'paused')
      and not exists (
        select 1 from public.blocked_users b
        where (b.user_id = auth.uid() and b.blocked_user_id = p_user_id)
           or (b.user_id = p_user_id and b.blocked_user_id = auth.uid())
      )
  ) then
    raise exception 'live_participant_profile_required';
  end if;

  return query
  select p.id, p.display_name, coalesce(p.region, ''), coalesce(p.bio, ''), p.avatar_url
  from public.profiles p
  where p.id = p_user_id;
end;
$$;

revoke all on function public.get_live_participant_profile(uuid, uuid) from public, anon;
grant execute on function public.get_live_participant_profile(uuid, uuid) to authenticated;

-- The avatar bucket stays private. A signed URL may only be minted when the caller
-- can read the object under this policy: own avatar or a participant in the same
-- active/paused activity.
drop policy if exists avatar_read_live_participant on storage.objects;
create policy avatar_read_live_participant on storage.objects
for select to authenticated
using (
  bucket_id = 'avatars'
  and exists (
    select 1
    from public.profiles p
    where p.id::text = (storage.foldername(name))[1]
      and public.can_read_live_participant_profile(p.id, auth.uid())
  )
);
