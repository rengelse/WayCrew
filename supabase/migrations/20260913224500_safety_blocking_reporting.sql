-- WayCrew v0.3.7 - Safety: blocking and reporting

create table if not exists public.blocked_users (
  user_id uuid not null references public.profiles(id) on delete cascade,
  blocked_user_id uuid not null references public.profiles(id) on delete cascade,
  blocked_display_name text not null default 'Bruker',
  created_at timestamptz not null default now(),
  primary key (user_id, blocked_user_id),
  check (user_id <> blocked_user_id)
);

create table if not exists public.user_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  category text not null check (category in ('safety','harassment','spam','content','other')),
  description text not null check (char_length(trim(description)) between 10 and 4000),
  target_type text check (target_type is null or target_type in ('user','group','activity','message','other')),
  target_id text,
  status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists blocked_users_user_idx on public.blocked_users(user_id, created_at desc);
create index if not exists user_reports_reporter_idx on public.user_reports(reporter_id, created_at desc);
create index if not exists user_reports_status_idx on public.user_reports(status, created_at desc);

alter table public.blocked_users enable row level security;
alter table public.user_reports enable row level security;

drop policy if exists blocked_users_select_own on public.blocked_users;
create policy blocked_users_select_own on public.blocked_users
for select to authenticated
using (auth.uid() = user_id);

drop policy if exists user_reports_select_own on public.user_reports;
create policy user_reports_select_own on public.user_reports
for select to authenticated
using (auth.uid() = reporter_id);

-- Writes are intentionally RPC-only.
revoke insert, update, delete on public.blocked_users from authenticated;
revoke insert, update, delete on public.user_reports from authenticated;
grant select on public.blocked_users to authenticated;
grant select on public.user_reports to authenticated;

create or replace function public.block_user(p_blocked_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if p_blocked_user_id is null or p_blocked_user_id = auth.uid() then raise exception 'invalid_block_target'; end if;

  select coalesce(nullif(trim(display_name), ''), 'Bruker') into v_name
  from public.profiles where id = p_blocked_user_id;
  if not found then raise exception 'user_not_found'; end if;

  insert into public.blocked_users(user_id, blocked_user_id, blocked_display_name)
  values(auth.uid(), p_blocked_user_id, v_name)
  on conflict(user_id, blocked_user_id) do update
    set blocked_display_name = excluded.blocked_display_name,
        created_at = now();
end;
$$;

create or replace function public.unblock_user(p_blocked_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  delete from public.blocked_users
  where user_id = auth.uid() and blocked_user_id = p_blocked_user_id;
end;
$$;

create or replace function public.submit_user_report(
  p_category text,
  p_description text,
  p_target_type text default null,
  p_target_id text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_description text := trim(coalesce(p_description, ''));
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if p_category not in ('safety','harassment','spam','content','other') then raise exception 'invalid_report_category'; end if;
  if char_length(v_description) < 10 or char_length(v_description) > 4000 then raise exception 'invalid_report_description'; end if;
  if p_target_type is not null and p_target_type not in ('user','group','activity','message','other') then raise exception 'invalid_report_target_type'; end if;

  insert into public.user_reports(reporter_id, category, description, target_type, target_id)
  values(auth.uid(), p_category, v_description, p_target_type, nullif(trim(coalesce(p_target_id, '')), ''))
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.block_user(uuid) from public;
revoke all on function public.unblock_user(uuid) from public;
revoke all on function public.submit_user_report(text,text,text,text) from public;
grant execute on function public.block_user(uuid) to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;
grant execute on function public.submit_user_report(text,text,text,text) to authenticated;
