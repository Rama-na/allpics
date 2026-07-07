-- AllPics · 0007_admin.sql
-- Admin panel RPCs. Every function self-guards with is_admin() —
-- callable only by admins regardless of PostgREST exposure.

-- ============================================================
-- Platform-wide stats for the admin overview.
-- ============================================================
create or replace function public.admin_stats()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'ADMIN_ONLY';
  end if;
  return jsonb_build_object(
    'hosts', (select count(*) from public.profiles),
    'events_total', (select count(*) from public.events),
    'events_active', (select count(*) from public.events where status = 'active'),
    'guests', (select count(*) from public.event_guests),
    'uploads', (select count(*) from public.uploads),
    'storage_bytes', (select coalesce(sum(bytes_used), 0) from public.events),
    'revenue_paise', (
      select coalesce(sum(amount_inr), 0)
      from public.payments where status = 'captured'
    ),
    'payments_captured', (
      select count(*) from public.payments where status = 'captured'
    ),
    'jobs_queued', (
      select count(*) from public.processing_jobs
      where status in ('queued', 'running')
    ),
    'jobs_failed', (
      select count(*) from public.processing_jobs where status = 'failed'
    )
  );
end $$;

grant execute on function public.admin_stats() to authenticated;

-- ============================================================
-- User directory (profiles + auth email + event counts).
-- ============================================================
create or replace function public.admin_list_users(p_search text default '')
returns table (
  id uuid,
  full_name text,
  email text,
  role public.user_role,
  is_banned boolean,
  event_count bigint,
  created_at timestamptz
) language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'ADMIN_ONLY';
  end if;
  return query
    select p.id, p.full_name, u.email::text, p.role, p.is_banned,
           (select count(*) from public.events e where e.host_id = p.id),
           p.created_at
    from public.profiles p
    join auth.users u on u.id = p.id
    where p_search = ''
       or p.full_name ilike '%' || p_search || '%'
       or u.email ilike '%' || p_search || '%'
    order by p.created_at desc
    limit 200;
end $$;

grant execute on function public.admin_list_users(text) to authenticated;

-- ============================================================
-- All events with host names (admin moderation view).
-- ============================================================
create or replace function public.admin_list_events(p_search text default '')
returns table (
  id uuid,
  title text,
  host_name text,
  status public.event_status,
  photo_count integer,
  video_count integer,
  photo_limit integer,
  guest_count integer,
  bytes_used bigint,
  expires_at timestamptz,
  created_at timestamptz
) language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'ADMIN_ONLY';
  end if;
  return query
    select e.id, e.title, p.full_name, e.status,
           e.photo_count, e.video_count, e.photo_limit, e.guest_count,
           e.bytes_used, e.expires_at, e.created_at
    from public.events e
    join public.profiles p on p.id = e.host_id
    where p_search = '' or e.title ilike '%' || p_search || '%'
    order by e.created_at desc
    limit 200;
end $$;

grant execute on function public.admin_list_events(text) to authenticated;

-- ============================================================
-- Ban / unban a user (admins cannot ban admins or themselves).
-- ============================================================
create or replace function public.admin_set_user_banned(
  p_user_id uuid,
  p_banned boolean
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'ADMIN_ONLY';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'CANNOT_BAN_SELF';
  end if;
  if exists (select 1 from public.profiles where id = p_user_id and role = 'admin') then
    raise exception 'CANNOT_BAN_ADMIN';
  end if;
  update public.profiles set is_banned = p_banned where id = p_user_id;
  insert into public.activity_logs (actor_id, action, metadata)
  values (auth.uid(),
          case when p_banned then 'admin.user_banned' else 'admin.user_unbanned' end,
          jsonb_build_object('user_id', p_user_id));
end $$;

grant execute on function public.admin_set_user_banned(uuid, boolean) to authenticated;

-- ============================================================
-- Admin event deletion (soft) with audit trail.
-- ============================================================
create or replace function public.admin_delete_event(p_event_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'ADMIN_ONLY';
  end if;
  update public.events set status = 'deleted' where id = p_event_id;
  insert into public.activity_logs (actor_id, event_id, action)
  values (auth.uid(), p_event_id, 'admin.event_deleted');
end $$;

grant execute on function public.admin_delete_event(uuid) to authenticated;
