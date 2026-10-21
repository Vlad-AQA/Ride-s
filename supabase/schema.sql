-- ThaiRide: схема базы для Supabase.
-- Запускать целиком в Supabase → SQL Editor → New query → Run.
--
-- Правила жизни метки:
--   * новая метка живёт 1 час;
--   * каждое «Актуально» продлевает её до now() + 3 часа;
--   * 2 разных «Неактуально» после последнего подтверждения снимают метку.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Таблицы
-- ---------------------------------------------------------------------------

create table if not exists public.markers (
  id                uuid primary key default gen_random_uuid(),
  type              text not null check (type in (
                      'checkpoint', 'moto_patrol', 'tourist_check', 'alcohol',
                      'drug_test', 'highway', 'camera', 'hazard')),
  lat               double precision not null check (lat between -90 and 90),
  lng               double precision not null check (lng between -180 and 180),
  address           text check (char_length(address) <= 200),
  author_id         uuid not null,
  created_at        timestamptz not null default now(),
  last_confirmed_at timestamptz,
  expires_at        timestamptz not null,
  confirmations     int not null default 0,
  denials           int not null default 0,  -- разные «Неактуально» после последнего подтверждения
  comments_count    int not null default 0
);
create index if not exists markers_expires_idx on public.markers (expires_at);
create index if not exists markers_latlng_idx on public.markers (lat, lng);

create table if not exists public.votes (
  id         bigint generated always as identity primary key,
  marker_id  uuid not null references public.markers on delete cascade,
  user_id    uuid not null,
  is_actual  boolean not null,
  created_at timestamptz not null default now()
);
create index if not exists votes_marker_idx on public.votes (marker_id, created_at);

create table if not exists public.comments (
  id         bigint generated always as identity primary key,
  marker_id  uuid not null references public.markers on delete cascade,
  user_id    uuid not null,
  text       text not null check (char_length(text) between 1 and 280),
  created_at timestamptz not null default now()
);
create index if not exists comments_marker_idx on public.comments (marker_id, created_at);

-- ---------------------------------------------------------------------------
-- Доступ: читать могут все, писать только через функции ниже
-- ---------------------------------------------------------------------------

alter table public.markers  enable row level security;
alter table public.votes    enable row level security;
alter table public.comments enable row level security;

drop policy if exists markers_read on public.markers;
create policy markers_read on public.markers for select to anon, authenticated using (true);

drop policy if exists comments_read on public.comments;
create policy comments_read on public.comments for select to anon, authenticated using (true);
grant usage on schema public to anon, authenticated;
grant select on public.markers, public.comments to anon, authenticated;
revoke all on public.votes from anon, authenticated;
-- votes: политик нет — таблица закрыта, голоса видны только через счётчики в markers.

-- ---------------------------------------------------------------------------
-- Функции
-- ---------------------------------------------------------------------------

create or replace function public.distance_km(lat1 float8, lng1 float8, lat2 float8, lng2 float8)
returns float8 language sql immutable as $$
  select 6371 * 2 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)));
$$;

create or replace function public.add_comment(p_marker uuid, p_text text)
returns public.comments
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  c   public.comments;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from markers where id = p_marker and expires_at > now()) then
    raise exception 'marker_not_found';
  end if;
  if (select count(*) from comments
      where user_id = uid and created_at > now() - interval '10 minutes') >= 10 then
    raise exception 'rate_limited';
  end if;
  insert into comments (marker_id, user_id, text)
  values (p_marker, uid, btrim(p_text))
  returning * into c;
  update markers set comments_count = comments_count + 1 where id = p_marker;
  return c;
end $$;

create or replace function public.vote_marker(p_marker uuid, p_actual boolean)
returns public.markers
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  m   public.markers;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select * into m from markers where id = p_marker for update;
  if not found or m.expires_at <= now() then raise exception 'marker_not_found'; end if;
  if m.author_id = uid then raise exception 'own_marker'; end if;
  if exists (select 1 from votes where marker_id = p_marker and user_id = uid
             and created_at > now() - interval '15 minutes') then
    raise exception 'already_voted';
  end if;

  insert into votes (marker_id, user_id, is_actual) values (p_marker, uid, p_actual);

  if p_actual then
    update markers set
      confirmations     = confirmations + 1,
      last_confirmed_at = now(),
      expires_at        = greatest(expires_at, now() + interval '3 hours'),
      denials           = 0
    where id = p_marker returning * into m;
  else
    update markers set denials = (
      select count(distinct user_id) from votes
      where marker_id = p_marker and not is_actual
        and created_at >= coalesce(m.last_confirmed_at, m.created_at))
    where id = p_marker returning * into m;
    if m.denials >= 2 then
      update markers set expires_at = now() where id = p_marker returning * into m;
    end if;
  end if;
  return m;
end $$;

-- p_user_lat/p_user_lng — где сейчас находится пользователь; метку можно
-- поставить не дальше 70 км от себя. Если рядом (150 м) уже есть живая метка
-- того же типа — новая не создаётся, а существующая подтверждается.
create or replace function public.add_marker(
  p_type text, p_lat float8, p_lng float8,
  p_user_lat float8, p_user_lng float8,
  p_address text default null, p_comment text default null)
returns public.markers
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  m   public.markers;
  d   float8;
begin
  if uid is null then raise exception 'not_authenticated'; end if;

  d := distance_km(p_lat, p_lng, p_user_lat, p_user_lng);
  if d > 70 then raise exception 'too_far:%', round(d); end if;

  select * into m from markers
  where type = p_type and expires_at > now()
    and lat between p_lat - 0.01 and p_lat + 0.01
    and lng between p_lng - 0.01 and p_lng + 0.01
    and distance_km(lat, lng, p_lat, p_lng) < 0.15
  order by created_at desc limit 1;

  if found then
    if m.author_id <> uid
       and not exists (select 1 from votes where marker_id = m.id and user_id = uid
                       and created_at > now() - interval '15 minutes') then
      m := vote_marker(m.id, true);
    end if;
  else
    if (select count(*) from markers
        where author_id = uid and created_at > now() - interval '10 minutes') >= 5 then
      raise exception 'rate_limited';
    end if;
    insert into markers (type, lat, lng, address, author_id, expires_at)
    values (p_type, p_lat, p_lng, left(p_address, 200), uid, now() + interval '1 hour')
    returning * into m;
  end if;

  if coalesce(btrim(p_comment), '') <> '' then
    perform add_comment(m.id, left(p_comment, 280));
    select * into m from markers where id = m.id;
  end if;
  return m;
end $$;

revoke all on function public.add_marker(text, float8, float8, float8, float8, text, text) from public, anon;
revoke all on function public.vote_marker(uuid, boolean) from public, anon;
revoke all on function public.add_comment(uuid, text) from public, anon;
grant execute on function public.add_marker(text, float8, float8, float8, float8, text, text) to authenticated;
grant execute on function public.vote_marker(uuid, boolean) to authenticated;
grant execute on function public.add_comment(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Онлайн-обновления карты
-- ---------------------------------------------------------------------------

do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                     where pubname = 'supabase_realtime' and tablename = 'markers') then
    alter publication supabase_realtime add table public.markers;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Уборка: раз в час удалять метки, истёкшие больше суток назад
-- ---------------------------------------------------------------------------

do $$ begin
  create extension if not exists pg_cron;
  perform cron.schedule('cleanup-expired-markers', '0 * * * *',
    $q$delete from public.markers where expires_at < now() - interval '1 day'$q$);
exception when others then
  raise notice 'pg_cron недоступен, уборка не настроена: %', sqlerrm;
end $$;
