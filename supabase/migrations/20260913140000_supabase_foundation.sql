-- Activity Network v0.2.0 - Supabase Foundation
-- Safe to run on a fresh Supabase project.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  bio text,
  region text,
  avatar_url text,
  profile_visibility text not null default 'participants'
    check (profile_visibility in ('everyone', 'participants', 'only_me')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.activity_types (
  id text primary key,
  name_no text not null,
  name_en text not null,
  icon text,
  is_enabled boolean not null default true,
  sort_order integer not null default 0,
  metadata_schema jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_interests (
  user_id uuid not null references public.profiles(id) on delete cascade,
  activity_type text not null references public.activity_types(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, activity_type)
);

create table if not exists public.activity_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  activity_type text not null references public.activity_types(id) on delete cascade,
  experience_level text not null default 'beginner'
    check (experience_level in ('beginner', 'some_experience', 'experienced', 'very_experienced')),
  metadata jsonb not null default '{}'::jsonb,
  visibility text not null default 'participants'
    check (visibility in ('everyone', 'participants', 'only_me')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, activity_type)
);

-- Automatically create an application profile when an auth user is created.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
      split_part(coalesce(new.email, ''), '@', 1),
      'Ny bruker'
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Seed the shared activity type registry.
insert into public.activity_types (id, name_no, name_en, icon, sort_order)
values
  ('motorcycle', 'MC', 'Motorcycle', '🏍️', 10),
  ('ski', 'Ski', 'Ski', '⛷️', 20),
  ('cycling', 'Sykkel', 'Cycling', '🚵', 30),
  ('hiking', 'Fottur', 'Hiking', '🥾', 40),
  ('running', 'Løping', 'Running', '🏃', 50),
  ('kayak', 'Kajakk', 'Kayak', '🛶', 60),
  ('climbing', 'Klatring', 'Climbing', '🧗', 70),
  ('other', 'Annet', 'Other', '📍', 999)
on conflict (id) do update set
  name_no = excluded.name_no,
  name_en = excluded.name_en,
  icon = excluded.icon,
  sort_order = excluded.sort_order,
  updated_at = now();

-- RLS
alter table public.profiles enable row level security;
alter table public.activity_types enable row level security;
alter table public.user_interests enable row level security;
alter table public.activity_profiles enable row level security;

-- Raw profiles are private in the foundation migration. Public/discovery views
-- will be introduced with the activity/group migrations so we never expose more
-- profile data than intended.
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
for select to authenticated
using (auth.uid() = id);

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
for insert to authenticated
with check (auth.uid() = id);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
for update to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists activity_types_read on public.activity_types;
create policy activity_types_read on public.activity_types
for select to anon, authenticated
using (is_enabled = true);

drop policy if exists interests_select_own on public.user_interests;
create policy interests_select_own on public.user_interests
for select to authenticated
using (auth.uid() = user_id);

drop policy if exists interests_insert_own on public.user_interests;
create policy interests_insert_own on public.user_interests
for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists interests_delete_own on public.user_interests;
create policy interests_delete_own on public.user_interests
for delete to authenticated
using (auth.uid() = user_id);

drop policy if exists activity_profiles_select_own on public.activity_profiles;
create policy activity_profiles_select_own on public.activity_profiles
for select to authenticated
using (auth.uid() = user_id);

drop policy if exists activity_profiles_insert_own on public.activity_profiles;
create policy activity_profiles_insert_own on public.activity_profiles
for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists activity_profiles_update_own on public.activity_profiles;
create policy activity_profiles_update_own on public.activity_profiles
for update to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists activity_profiles_delete_own on public.activity_profiles;
create policy activity_profiles_delete_own on public.activity_profiles
for delete to authenticated
using (auth.uid() = user_id);

-- Explicit grants. RLS remains the authority for row access.
grant select, insert, update on public.profiles to authenticated;
grant select on public.activity_types to anon, authenticated;
grant select, insert, delete on public.user_interests to authenticated;
grant select, insert, update, delete on public.activity_profiles to authenticated;

-- Private avatar bucket, prepared for a later profile migration.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Files must be stored as: <auth.uid()>/<filename>
drop policy if exists avatar_read_own on storage.objects;
create policy avatar_read_own on storage.objects
for select to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists avatar_insert_own on storage.objects;
create policy avatar_insert_own on storage.objects
for insert to authenticated
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists avatar_update_own on storage.objects;
create policy avatar_update_own on storage.objects
for update to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists avatar_delete_own on storage.objects;
create policy avatar_delete_own on storage.objects
for delete to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
