-- ============================================================
-- Conetza — Schema SQL para Supabase
-- Ejecutar en: Supabase Dashboard > SQL Editor
-- ============================================================

-- ============================================================
-- EXTENSIONS
-- ============================================================
create extension if not exists "uuid-ossp";

-- ============================================================
-- PROFILES
-- ============================================================
create table public.profiles (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  username     text unique not null,
  display_name text,
  bio          text,
  avatar_url   text,
  category     text,
  tags         text[] default '{}',
  location     text,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create unique index profiles_user_id_idx on public.profiles(user_id);

-- Auto-update updated_at
create or replace function public.handle_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.handle_updated_at();

-- Auto-crear perfil vacío al registrarse
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (user_id, username)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'preferred_username', split_part(new.email, '@', 1))
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- SOCIAL ACCOUNTS
-- ============================================================
create table public.social_accounts (
  id                uuid primary key default uuid_generate_v4(),
  profile_id        uuid not null references public.profiles(id) on delete cascade,
  platform          text not null check (platform in ('twitch', 'instagram', 'tiktok', 'youtube', 'twitter')),
  handle            text not null,
  profile_url       text,
  followers_count   integer default 0,
  access_token      text,
  refresh_token     text,
  token_expires_at  timestamptz,
  is_primary        boolean not null default false,
  created_at        timestamptz not null default now(),
  unique (profile_id, platform)
);

-- ============================================================
-- SWIPES
-- ============================================================
create table public.swipes (
  id          uuid primary key default uuid_generate_v4(),
  swiper_id   uuid not null references public.profiles(id) on delete cascade,
  swiped_id   uuid not null references public.profiles(id) on delete cascade,
  direction   text not null check (direction in ('like', 'pass')),
  created_at  timestamptz not null default now(),
  unique (swiper_id, swiped_id),
  check (swiper_id <> swiped_id)
);

create index swipes_swiped_id_idx on public.swipes(swiped_id);

-- ============================================================
-- MATCHES
-- ============================================================
create table public.matches (
  id            uuid primary key default uuid_generate_v4(),
  profile_a_id  uuid not null references public.profiles(id) on delete cascade,
  profile_b_id  uuid not null references public.profiles(id) on delete cascade,
  status        text not null default 'active' check (status in ('active', 'unmatched')),
  matched_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  check (profile_a_id < profile_b_id),
  unique (profile_a_id, profile_b_id)
);

create trigger matches_updated_at
  before update on public.matches
  for each row execute function public.handle_updated_at();

-- Función que detecta match mutuo y crea el registro
create or replace function public.check_and_create_match()
returns trigger as $$
declare
  v_a uuid;
  v_b uuid;
begin
  if new.direction = 'like' then
    -- Verificar si el otro ya dio like
    if exists (
      select 1 from public.swipes
      where swiper_id = new.swiped_id
        and swiped_id = new.swiper_id
        and direction = 'like'
    ) then
      -- Ordenar IDs para el índice único
      v_a := least(new.swiper_id, new.swiped_id);
      v_b := greatest(new.swiper_id, new.swiped_id);

      insert into public.matches (profile_a_id, profile_b_id)
      values (v_a, v_b)
      on conflict do nothing;

      -- Notificaciones para ambos
      insert into public.notifications (profile_id, type, payload)
      values
        (new.swiper_id, 'new_match', jsonb_build_object('matched_with', new.swiped_id)),
        (new.swiped_id, 'new_match', jsonb_build_object('matched_with', new.swiper_id));
    end if;
  end if;
  return new;
end;
$$ language plpgsql security definer;

create trigger on_swipe_inserted
  after insert on public.swipes
  for each row execute function public.check_and_create_match();

-- ============================================================
-- MESSAGES
-- ============================================================
create table public.messages (
  id            uuid primary key default uuid_generate_v4(),
  match_id      uuid not null references public.matches(id) on delete cascade,
  sender_id     uuid not null references public.profiles(id) on delete cascade,
  content       text not null,
  message_type  text not null default 'text' check (message_type in ('text', 'image', 'link')),
  is_read       boolean not null default false,
  created_at    timestamptz not null default now()
);

create index messages_match_id_idx on public.messages(match_id, created_at);

-- Notificación al recibir un mensaje
create or replace function public.notify_new_message()
returns trigger as $$
declare
  v_receiver uuid;
begin
  select
    case when profile_a_id = new.sender_id then profile_b_id else profile_a_id end
  into v_receiver
  from public.matches
  where id = new.match_id;

  insert into public.notifications (profile_id, type, payload)
  values (
    v_receiver,
    'new_message',
    jsonb_build_object('match_id', new.match_id, 'from_profile_id', new.sender_id)
  );

  return new;
end;
$$ language plpgsql security definer;

create trigger on_message_inserted
  after insert on public.messages
  for each row execute function public.notify_new_message();

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
create table public.notifications (
  id          uuid primary key default uuid_generate_v4(),
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  type        text not null check (type in ('new_match', 'new_message', 'new_like')),
  payload     jsonb default '{}',
  is_read     boolean not null default false,
  created_at  timestamptz not null default now()
);

create index notifications_profile_id_idx on public.notifications(profile_id, is_read, created_at desc);

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

alter table public.profiles       enable row level security;
alter table public.social_accounts enable row level security;
alter table public.swipes          enable row level security;
alter table public.matches         enable row level security;
alter table public.messages        enable row level security;
alter table public.notifications   enable row level security;

-- Helper: obtener profile_id del usuario autenticado
create or replace function public.my_profile_id()
returns uuid as $$
  select id from public.profiles where user_id = auth.uid() limit 1;
$$ language sql stable security definer;

-- PROFILES
create policy "Perfiles públicos visibles para todos"
  on public.profiles for select using (is_active = true);

create policy "Usuario edita su propio perfil"
  on public.profiles for update using (user_id = auth.uid());

-- SOCIAL ACCOUNTS
create policy "Cuentas sociales visibles si el perfil es activo"
  on public.social_accounts for select
  using (exists (
    select 1 from public.profiles p
    where p.id = profile_id and p.is_active = true
  ));

create policy "Usuario gestiona sus propias cuentas sociales"
  on public.social_accounts for all
  using (profile_id = public.my_profile_id());

-- SWIPES
create policy "Usuario ve sus propios swipes"
  on public.swipes for select using (swiper_id = public.my_profile_id());

create policy "Usuario crea sus propios swipes"
  on public.swipes for insert with check (swiper_id = public.my_profile_id());

-- MATCHES
create policy "Usuario ve sus propios matches"
  on public.matches for select
  using (
    profile_a_id = public.my_profile_id() or
    profile_b_id = public.my_profile_id()
  );

-- MESSAGES
create policy "Usuario ve mensajes de sus matches"
  on public.messages for select
  using (
    exists (
      select 1 from public.matches m
      where m.id = match_id
        and (m.profile_a_id = public.my_profile_id() or m.profile_b_id = public.my_profile_id())
    )
  );

create policy "Usuario envía mensajes en sus matches"
  on public.messages for insert
  with check (
    sender_id = public.my_profile_id() and
    exists (
      select 1 from public.matches m
      where m.id = match_id and m.status = 'active'
        and (m.profile_a_id = public.my_profile_id() or m.profile_b_id = public.my_profile_id())
    )
  );

-- NOTIFICATIONS
create policy "Usuario ve sus propias notificaciones"
  on public.notifications for select
  using (profile_id = public.my_profile_id());

create policy "Usuario marca sus notificaciones como leídas"
  on public.notifications for update
  using (profile_id = public.my_profile_id());

-- ============================================================
-- REALTIME (para chat y notificaciones en vivo)
-- ============================================================
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.matches;
