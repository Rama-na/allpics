-- AllPics · 0001_initial_schema.sql
-- Core schema: enums + 13 tables. RLS enabled here, policies in 0003.

create extension if not exists "uuid-ossp";
create extension if not exists pg_trgm;

-- ============================================================
-- ENUMS
-- ============================================================
create type public.user_role as enum ('host', 'admin');
create type public.event_type as enum ('wedding', 'birthday', 'party', 'trip', 'corporate', 'baby_shower', 'custom');
create type public.event_status as enum ('active', 'expired', 'deleted');
create type public.media_type as enum ('photo', 'video');
create type public.upload_status as enum ('pending', 'uploaded', 'processing', 'ready', 'failed', 'rejected');
create type public.album_kind as enum ('main', 'highlights', 'slideshow');
create type public.payment_status as enum ('created', 'authorized', 'captured', 'failed', 'refunded');
create type public.job_type as enum ('thumbnail', 'dedupe', 'blur_detect', 'enhance', 'highlights', 'slideshow');
create type public.job_status as enum ('queued', 'running', 'done', 'failed');
create type public.notification_type as enum ('guest_joined', 'new_uploads', 'album_expiring', 'storage_low', 'payment_success', 'system');

-- ============================================================
-- PROFILES (extends auth.users; hosts + admins)
-- ============================================================
create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  role          public.user_role not null default 'host',
  full_name     text not null default '',
  avatar_url    text,
  phone         text,
  fcm_token     text,
  theme         text not null default 'system' check (theme in ('system', 'light', 'dark')),
  language      text not null default 'en',
  notify_guest_joined   boolean not null default true,
  notify_new_uploads    boolean not null default true,
  notify_expiry         boolean not null default true,
  is_banned     boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ============================================================
-- PLANS
-- ============================================================
create table public.plans (
  id            uuid primary key default uuid_generate_v4(),
  code          text not null unique,
  name          text not null,
  price_inr     integer not null check (price_inr >= 0),  -- paise
  photo_limit   integer not null check (photo_limit > 0),
  storage_days  integer not null check (storage_days > 0),
  is_active     boolean not null default true,
  sort_order    integer not null default 0,
  created_at    timestamptz not null default now()
);

-- ============================================================
-- EVENTS
-- ============================================================
create table public.events (
  id            uuid primary key default uuid_generate_v4(),
  host_id       uuid not null references public.profiles (id) on delete cascade,
  plan_id       uuid not null references public.plans (id),
  type          public.event_type not null default 'custom',
  status        public.event_status not null default 'active',
  title         text not null check (char_length(title) between 1 and 120),
  description   text not null default '' check (char_length(description) <= 2000),
  event_date    date,
  location      text not null default '' check (char_length(location) <= 300),
  cover_url     text,
  event_code    text not null unique,           -- 6-char human code, e.g. K3XR7P
  share_slug    text not null unique,           -- URL-safe slug for share links
  photo_limit   integer not null,               -- copied from plan; upgradable
  expires_at    timestamptz not null,
  -- denormalized counters (maintained by triggers)
  guest_count   integer not null default 0,
  photo_count   integer not null default 0,
  video_count   integer not null default 0,
  bytes_used    bigint  not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index events_host_idx on public.events (host_id, status);
create index events_expires_idx on public.events (expires_at) where status = 'active';

-- ============================================================
-- EVENT GUESTS (anonymous-auth users joined to an event)
-- ============================================================
create table public.event_guests (
  id            uuid primary key default uuid_generate_v4(),
  event_id      uuid not null references public.events (id) on delete cascade,
  auth_user_id  uuid not null references auth.users (id) on delete cascade,
  name          text not null check (char_length(name) between 1 and 80),
  phone         text check (phone is null or phone ~ '^[+0-9][0-9 -]{5,19}$'),
  is_banned     boolean not null default false,
  joined_at     timestamptz not null default now(),
  unique (event_id, auth_user_id)
);
create index event_guests_event_idx on public.event_guests (event_id);
create index event_guests_user_idx on public.event_guests (auth_user_id);

-- ============================================================
-- UPLOADS
-- ============================================================
create table public.uploads (
  id            uuid primary key default uuid_generate_v4(),
  event_id      uuid not null references public.events (id) on delete cascade,
  guest_id      uuid not null references public.event_guests (id) on delete cascade,
  storage_path  text not null unique,          -- media/{event_id}/{upload_id}.{ext}
  thumb_path    text,
  media_type    public.media_type not null,
  status        public.upload_status not null default 'pending',
  mime_type     text not null,
  bytes         bigint not null default 0 check (bytes >= 0),
  width         integer,
  height        integer,
  duration_ms   integer,                        -- videos only
  caption       text not null default '' check (char_length(caption) <= 500),
  phash         text,                           -- perceptual hash (worker)
  blur_score    real,                           -- Laplacian variance (worker)
  quality_score real,                           -- worker-computed ranking
  is_duplicate  boolean not null default false,
  duplicate_of  uuid references public.uploads (id) on delete set null,
  captured_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index uploads_event_idx on public.uploads (event_id, status, created_at desc);
create index uploads_guest_idx on public.uploads (guest_id);
create index uploads_phash_idx on public.uploads (event_id, phash) where phash is not null;
create index uploads_caption_trgm_idx on public.uploads using gin (caption gin_trgm_ops);

-- ============================================================
-- ALBUMS + ITEMS
-- ============================================================
create table public.albums (
  id            uuid primary key default uuid_generate_v4(),
  event_id      uuid not null references public.events (id) on delete cascade,
  kind          public.album_kind not null,
  title         text not null default '',
  output_path   text,                           -- slideshow video path
  generated_at  timestamptz,
  created_at    timestamptz not null default now(),
  unique (event_id, kind)
);

create table public.album_items (
  id            uuid primary key default uuid_generate_v4(),
  album_id      uuid not null references public.albums (id) on delete cascade,
  upload_id     uuid not null references public.uploads (id) on delete cascade,
  position      integer not null default 0,
  unique (album_id, upload_id)
);
create index album_items_album_idx on public.album_items (album_id, position);

-- ============================================================
-- FAVORITES (any auth user: host or guest)
-- ============================================================
create table public.favorites (
  id            uuid primary key default uuid_generate_v4(),
  upload_id     uuid not null references public.uploads (id) on delete cascade,
  user_id       uuid not null references auth.users (id) on delete cascade,
  created_at    timestamptz not null default now(),
  unique (upload_id, user_id)
);
create index favorites_user_idx on public.favorites (user_id);

-- ============================================================
-- PAYMENTS
-- ============================================================
create table public.payments (
  id                    uuid primary key default uuid_generate_v4(),
  event_id              uuid not null references public.events (id) on delete cascade,
  host_id               uuid not null references public.profiles (id),
  plan_id               uuid not null references public.plans (id),
  razorpay_order_id     text not null unique,
  razorpay_payment_id   text unique,
  razorpay_signature    text,
  amount_inr            integer not null,       -- paise
  currency              text not null default 'INR',
  status                public.payment_status not null default 'created',
  invoice_number        text unique,
  invoice_url           text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index payments_host_idx on public.payments (host_id, created_at desc);
create index payments_event_idx on public.payments (event_id);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
create table public.notifications (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  type          public.notification_type not null,
  title         text not null,
  body          text not null default '',
  data          jsonb not null default '{}'::jsonb,
  read_at       timestamptz,
  created_at    timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);

-- ============================================================
-- ACTIVITY LOGS
-- ============================================================
create table public.activity_logs (
  id            bigint generated always as identity primary key,
  actor_id      uuid references auth.users (id) on delete set null,
  event_id      uuid references public.events (id) on delete set null,
  action        text not null,
  metadata      jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now()
);
create index activity_logs_event_idx on public.activity_logs (event_id, created_at desc);

-- ============================================================
-- FEATURE FLAGS
-- ============================================================
create table public.feature_flags (
  key           text primary key,
  enabled       boolean not null default false,
  payload       jsonb not null default '{}'::jsonb,
  updated_at    timestamptz not null default now()
);

-- ============================================================
-- PROCESSING JOBS (AI worker queue)
-- ============================================================
create table public.processing_jobs (
  id            uuid primary key default uuid_generate_v4(),
  event_id      uuid not null references public.events (id) on delete cascade,
  upload_id     uuid references public.uploads (id) on delete cascade,
  job_type      public.job_type not null,
  status        public.job_status not null default 'queued',
  attempts      integer not null default 0,
  last_error    text,
  result        jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index processing_jobs_queue_idx on public.processing_jobs (status, created_at) where status in ('queued', 'running');

-- ============================================================
-- ENABLE RLS EVERYWHERE (policies in 0003)
-- ============================================================
alter table public.profiles         enable row level security;
alter table public.plans            enable row level security;
alter table public.events           enable row level security;
alter table public.event_guests     enable row level security;
alter table public.uploads          enable row level security;
alter table public.albums           enable row level security;
alter table public.album_items      enable row level security;
alter table public.favorites        enable row level security;
alter table public.payments         enable row level security;
alter table public.notifications    enable row level security;
alter table public.activity_logs    enable row level security;
alter table public.feature_flags    enable row level security;
alter table public.processing_jobs  enable row level security;
