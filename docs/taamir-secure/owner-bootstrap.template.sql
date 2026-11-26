-- Run this once in Supabase SQL Editor after the owner's account is confirmed.
-- Replace YOUR_LOGIN_EMAIL in the SQL editor only; never commit the real address.
begin;
do $bootstrap$
declare
  v_owner_id uuid;
begin
  select id into v_owner_id
  from auth.users
  where lower(email) = lower('YOUR_LOGIN_EMAIL')
    and email_confirmed_at is not null;

  if v_owner_id is null then
    raise exception 'No confirmed Auth user matches the supplied owner email';
  end if;

  if exists (
    select 1 from public.app_owner
    where singleton = true and owner_user_id <> v_owner_id
  ) then
    raise exception 'An application owner is already configured; refusing to replace it';
  end if;

  insert into public.profiles(id, email, role, active)
  select id, email, 'manager', true from auth.users where id = v_owner_id
  on conflict (id) do update
    set role = 'manager', active = true, updated_at = now();

  insert into public.app_owner(singleton, owner_user_id)
  values (true, v_owner_id)
  on conflict (singleton) do update
    set owner_user_id = excluded.owner_user_id;
end
$bootstrap$;
commit;
