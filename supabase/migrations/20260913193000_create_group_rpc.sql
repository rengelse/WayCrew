-- Activity Network v0.2.10 - robust group creation RPC
-- Run after 20260913190000_meeting_point_search.sql.

create or replace function public.create_group(
  p_name text,
  p_activity_type text,
  p_region text default '',
  p_description text default '',
  p_visibility text default 'public',
  p_join_mode text default 'request'
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_user_id uuid := auth.uid();
  v_group_id uuid;
  v_name text := trim(coalesce(p_name,''));
  v_region text := trim(coalesce(p_region,''));
  v_description text := trim(coalesce(p_description,''));
begin
  if v_user_id is null then
    raise exception 'auth_required';
  end if;

  if not exists(select 1 from public.profiles where id=v_user_id) then
    raise exception 'profile_required';
  end if;

  if char_length(v_name) < 2 or char_length(v_name) > 120 then
    raise exception 'invalid_group_name';
  end if;

  if not exists(select 1 from public.activity_types where id=p_activity_type) then
    raise exception 'invalid_activity_type';
  end if;

  if p_visibility not in ('public','private') then
    raise exception 'invalid_visibility';
  end if;

  if p_join_mode not in ('open','request','inviteOnly') then
    raise exception 'invalid_join_mode';
  end if;

  insert into public.groups(
    created_by,
    name,
    activity_type,
    region,
    description,
    visibility,
    join_mode
  ) values (
    v_user_id,
    v_name,
    p_activity_type,
    v_region,
    v_description,
    p_visibility,
    p_join_mode
  )
  returning id into v_group_id;

  -- Existing AFTER INSERT triggers add the creator as owner and create the group chat.
  return v_group_id;
end;
$$;

grant execute on function public.create_group(text,text,text,text,text,text) to authenticated;

-- Creation is intentionally funneled through the RPC. Existing groups remain editable
-- through the RLS-protected update path used by group administration.
revoke insert on public.groups from authenticated;
