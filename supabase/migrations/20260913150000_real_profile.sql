-- Activity Network v0.2.1 - Real Profile
-- Run after 20260913140000_supabase_foundation.sql.
-- No destructive schema changes. Adds consistent updated_at handling for real profile writes.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute procedure public.set_updated_at();

drop trigger if exists activity_profiles_set_updated_at on public.activity_profiles;
create trigger activity_profiles_set_updated_at
before update on public.activity_profiles
for each row execute procedure public.set_updated_at();

-- Keep the avatar bucket private. The profile stores only the object path;
-- authenticated clients create short-lived signed URLs when rendering their own avatar.
update storage.buckets
set public = false,
    file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id = 'avatars';
