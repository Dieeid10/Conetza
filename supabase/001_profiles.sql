-- Conetza · Migración 001
-- Tablas: profiles, social_accounts
-- Incluye: trigger de alta de perfil + RLS
-- Guardar en: supabase/migrations/001_profiles.sql

-- ============================================================
-- 1. PROFILES (1 fila por usuario de auth.users)
-- ============================================================
create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  display_name  text,
  avatar_url    text,
  bio           text,
  language      text not null default 'es',
  timezone      text,
  looking_for   text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ============================================================
-- 2. SOCIAL_ACCOUNTS (redes conectadas y datos verificados)
-- ============================================================
create table public.social_accounts (
  id                uuid primary key default gen_random_uuid(),
  profile_id        uuid not null references public.profiles (id) on delete cascade,
  provider          text not null,              -- 'twitch', 'google', ...
  provider_user_id  text not null,
  username          text,
  followers         integer,
  verified_at       timestamptz,                -- cuándo se leyó el dato
  created_at        timestamptz not null default now(),
  unique (provider, provider_user_id)
);

create index social_accounts_profile_id_idx
  on public.social_accounts (profile_id);

-- ============================================================
-- 3. TRIGGER: crear perfil al registrarse
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'preferred_username',
      new.raw_user_meta_data ->> 'name',
      new.raw_user_meta_data ->> 'full_name',
      split_part(new.email, '@', 1)
    ),
    coalesce(
      new.raw_user_meta_data ->> 'avatar_url',
      new.raw_user_meta_data ->> 'picture'
    )
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- 4. updated_at automático en profiles
-- ============================================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ============================================================
-- 5. RLS
-- ============================================================
alter table public.profiles enable row level security;
alter table public.social_accounts enable row level security;

-- PROFILES: cualquier usuario autenticado puede ver perfiles
create policy "profiles_select_authenticated"
  on public.profiles for select
  to authenticated
  using (true);

-- PROFILES: cada usuario edita solo el suyo
create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- (No hay policy de insert: el perfil lo crea el trigger.)

-- SOCIAL_ACCOUNTS: lectura para usuarios autenticados
create policy "social_accounts_select_authenticated"
  on public.social_accounts for select
  to authenticated
  using (true);

-- SOCIAL_ACCOUNTS: SIN policies de insert/update/delete para usuarios.
-- Los followers son "datos verificados": solo se escriben desde el
-- servidor con la secret key (service role), que ignora RLS.
-- Así nadie puede falsear su cantidad de followers desde el navegador.