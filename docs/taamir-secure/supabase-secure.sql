-- El Taamir v3.4 secure beta
-- Run ONLY in a new, dedicated Supabase project after review.
-- Shared team data: manager/agent/monitor roles are enforced by PostgreSQL RLS.
-- Do not place a service_role key in the browser.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'monitor' check (role in ('manager','agent','monitor')),
  active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.profiles add column if not exists active boolean not null default false;
alter table public.profiles add column if not exists updated_at timestamptz not null default now();

-- A separate, private owner identity prevents other data managers from changing user access.
create table if not exists public.app_owner (
  singleton boolean primary key default true check (singleton),
  owner_user_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);
alter table public.app_owner enable row level security;
revoke all on public.app_owner from public, anon, authenticated;

create table if not exists public.parcels (id uuid primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.plans (id uuid primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.classified (id uuid primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.childhood (id uuid primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.contracts (id uuid primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.regular (id uuid primary key, data jsonb not null, updated_at timestamptz not null default now());

-- Remove every prior policy from these app tables, including the old permissive "allow all" policies.
do $$
declare t text; p record;
begin
  foreach t in array array['profiles','parcels','plans','classified','childhood','contracts','regular'] loop
    for p in select policyname from pg_policies where schemaname='public' and tablename=t loop
      execute format('drop policy %I on public.%I',p.policyname,t);
    end loop;
  end loop;
end $$;

create or replace function public.current_app_role()
returns text language sql stable security definer
set search_path = pg_catalog
as $$ select p.role from public.profiles p where p.id = (select auth.uid()) and p.active = true $$;
revoke all on function public.current_app_role() from public, anon;
grant execute on function public.current_app_role() to authenticated;

create or replace function public.is_app_owner()
returns boolean language sql stable security definer
set search_path = pg_catalog
as $$
  select exists (
    select 1 from public.app_owner o
    join public.profiles p on p.id = o.owner_user_id
    where o.singleton = true and o.owner_user_id = (select auth.uid())
      and p.active = true and p.role = 'manager'
  )
$$;
revoke all on function public.is_app_owner() from public, anon;
grant execute on function public.is_app_owner() to authenticated;

alter table public.profiles enable row level security;
create policy profiles_read_self_or_owner on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select public.is_app_owner()));
revoke all on public.profiles from public, anon, authenticated;
grant select on public.profiles to authenticated;
-- No direct client insert/update/delete on profiles; signup trigger and the manager-only RPC own this table.

create or replace function public.create_inactive_profile()
returns trigger language plpgsql security definer
set search_path = pg_catalog
as $$
begin
  insert into public.profiles(id,email,role,active)
  values (new.id,new.email,'monitor',false)
  on conflict (id) do nothing;
  return new;
end $$;
revoke all on function public.create_inactive_profile() from public, anon, authenticated;
drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile after insert on auth.users
  for each row execute function public.create_inactive_profile();
-- Ensure accounts that existed before this migration also begin disabled.
insert into public.profiles(id,email,role,active)
select id,email,'monitor',false from auth.users
on conflict (id) do nothing;

create or replace function public.set_member_access(p_user_id uuid, p_role text, p_active boolean)
returns void language plpgsql security definer
set search_path = pg_catalog
as $$
begin
  if coalesce((select public.is_app_owner()),false) = false then
    raise exception 'application owner required';
  end if;
  if p_user_id is null or p_role is null or p_role not in ('manager','agent','monitor') or p_active is null then
    raise exception 'invalid access settings';
  end if;
  if p_user_id = (select auth.uid()) then
    raise exception 'managers cannot change their own access';
  end if;
  update public.profiles set role=p_role, active=p_active, updated_at=now() where id=p_user_id;
  if not found then raise exception 'profile not found'; end if;
end $$;
revoke all on function public.set_member_access(uuid,text,boolean) from public, anon;
grant execute on function public.set_member_access(uuid,text,boolean) to authenticated;

-- Apply the same server-enforced permissions to each shared registry.
do $$
declare t text;
begin
  foreach t in array array['parcels','plans','classified','childhood','contracts','regular'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on public.%I from public, anon',t);
    execute format('grant select, insert, update, delete on public.%I to authenticated',t);
    execute format('create policy %I on public.%I for select to authenticated using ((select public.current_app_role()) in (''manager'',''agent'',''monitor''))',t||'_read_active_team',t);
    execute format('create policy %I on public.%I for insert to authenticated with check ((select public.current_app_role()) in (''manager'',''agent''))',t||'_write_manager_agent',t);
    execute format('create policy %I on public.%I for update to authenticated using ((select public.current_app_role()) in (''manager'',''agent'')) with check ((select public.current_app_role()) in (''manager'',''agent''))',t||'_edit_manager_agent',t);
    execute format('create policy %I on public.%I for delete to authenticated using ((select public.current_app_role()) = ''manager'')',t||'_delete_manager',t);
  end loop;
end $$;

-- Private documents: access requires the same active team role; only manager/agent may upload.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('duac-files','duac-files',false,15728640,array['application/pdf'])
on conflict (id) do update set public=false, file_size_limit=15728640, allowed_mime_types=array['application/pdf'];
drop policy if exists "duac files public read" on storage.objects;
drop policy if exists "duac files upload" on storage.objects;
drop policy if exists "duac files update" on storage.objects;
drop policy if exists "duac files delete" on storage.objects;
drop policy if exists taamir_secure_files_read on storage.objects;
drop policy if exists taamir_secure_files_upload on storage.objects;
create policy taamir_secure_files_read on storage.objects for select to authenticated
  using (bucket_id='duac-files' and (select public.current_app_role()) in ('manager','agent','monitor'));
create policy taamir_secure_files_upload on storage.objects for insert to authenticated
  with check (bucket_id='duac-files' and (select public.current_app_role()) in ('manager','agent'));

-- FINAL OWNER-ONLY BOOTSTRAP: see owner-bootstrap.template.sql.
