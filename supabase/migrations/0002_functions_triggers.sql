-- AllPics · 0002_functions_triggers.sql
-- Helper functions, profile bootstrap, counters, quota enforcement, event codes.

-- ============================================================
-- updated_at maintenance
-- ============================================================
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

create trigger trg_profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger trg_events_updated_at before update on public.events
  for each row execute function public.set_updated_at();
create trigger trg_uploads_updated_at before update on public.uploads
  for each row execute function public.set_updated_at();
create trigger trg_payments_updated_at before update on public.payments
  for each row execute function public.set_updated_at();
create trigger trg_jobs_updated_at before update on public.processing_jobs
  for each row execute function public.set_updated_at();

-- ============================================================
-- Role helpers (used by RLS)
-- ============================================================
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and not is_banned
  );
$$;

create or replace function public.is_event_host(p_event_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.events
    where id = p_event_id and host_id = auth.uid()
  );
$$;

create or replace function public.is_event_guest(p_event_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.event_guests
    where event_id = p_event_id and auth_user_id = auth.uid() and not is_banned
  );
$$;

create or replace function public.is_event_member(p_event_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_event_host(p_event_id) or public.is_event_guest(p_event_id);
$$;

-- ============================================================
-- Profile bootstrap: create a profile row for every NON-anonymous auth user
-- ============================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if coalesce(new.is_anonymous, false) then
    return new; -- guests do not get profiles
  end if;
  insert into public.profiles (id, full_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end $$;

create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- Event code + share slug generation (collision-safe)
-- ============================================================
create or replace function public.generate_event_code()
returns text language plpgsql volatile as $$
declare
  chars constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; -- unambiguous set
  code text;
begin
  loop
    code := (
      select string_agg(substr(chars, 1 + floor(random() * length(chars))::int, 1), '')
      from generate_series(1, 6)
    );
    exit when not exists (select 1 from public.events where event_code = code);
  end loop;
  return code;
end $$;

create or replace function public.handle_new_event()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_plan public.plans%rowtype;
begin
  select * into v_plan from public.plans where id = new.plan_id;
  if not found then
    raise exception 'PLAN_NOT_FOUND';
  end if;

  if new.event_code is null or new.event_code = '' then
    new.event_code := public.generate_event_code();
  end if;
  if new.share_slug is null or new.share_slug = '' then
    new.share_slug := lower(new.event_code) || '-' || substr(replace(uuid_generate_v4()::text, '-', ''), 1, 8);
  end if;
  new.photo_limit := v_plan.photo_limit;
  new.expires_at := now() + make_interval(days => v_plan.storage_days);
  return new;
end $$;

create trigger trg_events_before_insert
  before insert on public.events
  for each row execute function public.handle_new_event();

-- ============================================================
-- Guest counter
-- ============================================================
create or replace function public.handle_guest_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update public.events set guest_count = guest_count + 1 where id = new.event_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.events set guest_count = greatest(guest_count - 1, 0) where id = old.event_id;
    return old;
  end if;
  return null;
end $$;

create trigger trg_event_guests_counter
  after insert or delete on public.event_guests
  for each row execute function public.handle_guest_change();

-- ============================================================
-- Upload quota enforcement + counters
-- Quota counts photos + videos against events.photo_limit.
-- ============================================================
create or replace function public.handle_upload_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_event public.events%rowtype;
begin
  select * into v_event from public.events where id = new.event_id for update;
  if not found or v_event.status <> 'active' then
    raise exception 'EVENT_NOT_ACTIVE';
  end if;
  if v_event.expires_at < now() then
    raise exception 'EVENT_EXPIRED';
  end if;
  if (v_event.photo_count + v_event.video_count) >= v_event.photo_limit then
    raise exception 'QUOTA_EXCEEDED';
  end if;

  update public.events set
    photo_count = photo_count + (case when new.media_type = 'photo' then 1 else 0 end),
    video_count = video_count + (case when new.media_type = 'video' then 1 else 0 end),
    bytes_used  = bytes_used + coalesce(new.bytes, 0)
  where id = new.event_id;
  return new;
end $$;

create trigger trg_uploads_before_insert
  before insert on public.uploads
  for each row execute function public.handle_upload_insert();

create or replace function public.handle_upload_delete()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.events set
    photo_count = greatest(photo_count - (case when old.media_type = 'photo' then 1 else 0 end), 0),
    video_count = greatest(video_count - (case when old.media_type = 'video' then 1 else 0 end), 0),
    bytes_used  = greatest(bytes_used - coalesce(old.bytes, 0), 0)
  where id = old.event_id;
  return old;
end $$;

create trigger trg_uploads_after_delete
  after delete on public.uploads
  for each row execute function public.handle_upload_delete();

-- Keep bytes_used accurate when actual size is patched after storage upload.
create or replace function public.handle_upload_bytes_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.bytes is distinct from old.bytes then
    update public.events
      set bytes_used = greatest(bytes_used - coalesce(old.bytes, 0) + coalesce(new.bytes, 0), 0)
      where id = new.event_id;
  end if;
  return new;
end $$;

create trigger trg_uploads_after_update_bytes
  after update of bytes on public.uploads
  for each row execute function public.handle_upload_bytes_update();

-- ============================================================
-- Activity logging (key actions)
-- ============================================================
create or replace function public.log_activity()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name = 'events' and tg_op = 'INSERT' then
    insert into public.activity_logs (actor_id, event_id, action, metadata)
    values (auth.uid(), new.id, 'event.created', jsonb_build_object('title', new.title));
  elsif tg_table_name = 'event_guests' and tg_op = 'INSERT' then
    insert into public.activity_logs (actor_id, event_id, action, metadata)
    values (auth.uid(), new.event_id, 'guest.joined', jsonb_build_object('name', new.name));
  elsif tg_table_name = 'payments' and tg_op = 'UPDATE' and new.status = 'captured' and old.status <> 'captured' then
    insert into public.activity_logs (actor_id, event_id, action, metadata)
    values (new.host_id, new.event_id, 'payment.captured', jsonb_build_object('amount_inr', new.amount_inr));
  end if;
  return coalesce(new, old);
end $$;

create trigger trg_log_event_created after insert on public.events
  for each row execute function public.log_activity();
create trigger trg_log_guest_joined after insert on public.event_guests
  for each row execute function public.log_activity();
create trigger trg_log_payment_captured after update on public.payments
  for each row execute function public.log_activity();

-- ============================================================
-- Expiry sweep (called by scheduled Edge Function / pg_cron)
-- ============================================================
create or replace function public.expire_events()
returns integer language plpgsql security definer set search_path = public as $$
declare
  v_count integer;
begin
  update public.events
    set status = 'expired'
    where status = 'active' and expires_at < now();
  get diagnostics v_count = row_count;
  return v_count;
end $$;
