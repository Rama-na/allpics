-- AllPics · 0005_notifications.sql
-- Notification generation + push bookkeeping.

-- Track FCM push delivery (used by the send-notification function).
alter table public.notifications
  add column if not exists pushed_at timestamptz;

create index if not exists notifications_unpushed_idx
  on public.notifications (created_at)
  where pushed_at is null;

-- ============================================================
-- Helper: insert a notification for an event's host, respecting prefs.
-- ============================================================
create or replace function public.notify_event_host(
  p_event_id uuid,
  p_type public.notification_type,
  p_title text,
  p_body text,
  p_data jsonb default '{}'::jsonb
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_host_id uuid;
  v_allowed boolean := true;
begin
  select host_id into v_host_id from public.events where id = p_event_id;
  if v_host_id is null then return; end if;

  select case p_type
      when 'guest_joined' then p.notify_guest_joined
      when 'new_uploads' then p.notify_new_uploads
      when 'album_expiring' then p.notify_expiry
      else true
    end
    into v_allowed
  from public.profiles p where p.id = v_host_id;

  if coalesce(v_allowed, true) then
    insert into public.notifications (user_id, type, title, body, data)
    values (
      v_host_id,
      p_type,
      p_title,
      p_body,
      p_data || jsonb_build_object('event_id', p_event_id)
    );
  end if;
end $$;

-- ============================================================
-- Guest joined → notify host
-- ============================================================
create or replace function public.handle_guest_joined_notification()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_title text;
begin
  select title into v_title from public.events where id = new.event_id;
  perform public.notify_event_host(
    new.event_id,
    'guest_joined',
    new.name || ' joined ' || coalesce(v_title, 'your event'),
    'They can now add photos to the album.',
    jsonb_build_object('guest_name', new.name)
  );
  return new;
end $$;

create trigger trg_notify_guest_joined
  after insert on public.event_guests
  for each row execute function public.handle_guest_joined_notification();

-- ============================================================
-- Uploads → milestone + storage-low notifications
--   · first upload of the event
--   · every 25th upload
--   · crossing 90% of the quota (exactly once per crossing)
-- ============================================================
create or replace function public.handle_upload_notifications()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_event public.events%rowtype;
  v_used integer;
  v_threshold integer;
begin
  select * into v_event from public.events where id = new.event_id;
  if not found then return new; end if;

  v_used := v_event.photo_count + v_event.video_count; -- post-trigger counts
  v_threshold := ceil(v_event.photo_limit * 0.9);

  if v_used = 1 then
    perform public.notify_event_host(
      new.event_id,
      'new_uploads',
      'First photo is in! 📸',
      'The album for ' || v_event.title || ' has its first upload.'
    );
  elsif v_used % 25 = 0 then
    perform public.notify_event_host(
      new.event_id,
      'new_uploads',
      v_used || ' uploads and counting',
      v_event.title || ' is filling up with memories.'
    );
  end if;

  if v_used = v_threshold and v_used < v_event.photo_limit then
    perform public.notify_event_host(
      new.event_id,
      'storage_low',
      'Album almost full',
      v_event.title || ' has used ' || v_used || ' of ' ||
        v_event.photo_limit || ' uploads. Upgrade to keep collecting.'
    );
  end if;
  return new;
end $$;

create trigger trg_notify_uploads
  after insert on public.uploads
  for each row execute function public.handle_upload_notifications();

-- ============================================================
-- Expiry warnings: called by the scheduled event-expiry function.
-- Notifies hosts of events expiring within 3 days, once per day.
-- ============================================================
create or replace function public.notify_expiring_events()
returns integer language plpgsql security definer set search_path = public as $$
declare
  v_count integer := 0;
  r record;
begin
  for r in
    select e.id, e.title, e.expires_at,
           greatest(0, extract(day from e.expires_at - now())::int) as days_left
    from public.events e
    where e.status = 'active'
      and e.expires_at between now() and now() + interval '3 days'
      and not exists (
        select 1 from public.notifications n
        where n.type = 'album_expiring'
          and n.data ->> 'event_id' = e.id::text
          and n.created_at > now() - interval '20 hours'
      )
  loop
    perform public.notify_event_host(
      r.id,
      'album_expiring',
      'Album expires ' || case when r.days_left = 0 then 'today'
        else 'in ' || r.days_left || ' day' ||
             case when r.days_left = 1 then '' else 's' end end,
      'Download everything from ' || r.title ||
        ' or upgrade the plan to extend storage.',
      jsonb_build_object('days_left', r.days_left)
    );
    v_count := v_count + 1;
  end loop;
  return v_count;
end $$;
