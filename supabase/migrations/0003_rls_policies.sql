-- AllPics · 0003_rls_policies.sql
-- Row Level Security policies. Deny-by-default; explicit grants only.
-- Edge Functions using the service-role key bypass RLS by design.

-- ============================================================
-- PROFILES
-- ============================================================
create policy profiles_select_own on public.profiles
  for select using (id = auth.uid() or public.is_admin());

create policy profiles_update_own on public.profiles
  for update using (id = auth.uid() and not is_banned)
  with check (
    id = auth.uid()
    -- users cannot self-promote or self-unban
    and role = (select p.role from public.profiles p where p.id = auth.uid())
    and is_banned = (select p.is_banned from public.profiles p where p.id = auth.uid())
  );

create policy profiles_admin_update on public.profiles
  for update using (public.is_admin()) with check (public.is_admin());

-- ============================================================
-- PLANS (public catalog)
-- ============================================================
create policy plans_select_all on public.plans
  for select using (is_active or public.is_admin());

create policy plans_admin_write on public.plans
  for all using (public.is_admin()) with check (public.is_admin());

-- ============================================================
-- EVENTS
-- ============================================================
create policy events_select_member on public.events
  for select using (
    host_id = auth.uid()
    or public.is_event_guest(id)
    or public.is_admin()
  );

create policy events_insert_host on public.events
  for insert with check (
    host_id = auth.uid()
    and exists (select 1 from public.profiles p where p.id = auth.uid() and not p.is_banned)
  );

create policy events_update_host on public.events
  for update using (host_id = auth.uid() or public.is_admin())
  with check (host_id = auth.uid() or public.is_admin());

create policy events_delete_host on public.events
  for delete using (host_id = auth.uid() or public.is_admin());

-- ============================================================
-- EVENT GUESTS
-- Join flow: anonymous user inserts own row for an active event.
-- Event lookup by code happens via SECURITY DEFINER RPC (below).
-- ============================================================
create policy event_guests_select_member on public.event_guests
  for select using (
    auth_user_id = auth.uid()
    or public.is_event_host(event_id)
    or public.is_event_guest(event_id)
    or public.is_admin()
  );

create policy event_guests_insert_self on public.event_guests
  for insert with check (
    auth_user_id = auth.uid()
    and exists (
      select 1 from public.events e
      where e.id = event_id and e.status = 'active' and e.expires_at > now()
    )
  );

create policy event_guests_update_own on public.event_guests
  for update using (auth_user_id = auth.uid() or public.is_event_host(event_id) or public.is_admin())
  with check (auth_user_id = auth.uid() or public.is_event_host(event_id) or public.is_admin());

create policy event_guests_delete_host on public.event_guests
  for delete using (public.is_event_host(event_id) or public.is_admin());

-- ============================================================
-- UPLOADS
-- ============================================================
create policy uploads_select_member on public.uploads
  for select using (public.is_event_member(event_id) or public.is_admin());

create policy uploads_insert_guest on public.uploads
  for insert with check (
    exists (
      select 1 from public.event_guests g
      where g.id = guest_id
        and g.auth_user_id = auth.uid()
        and g.event_id = uploads.event_id
        and not g.is_banned
    )
  );

-- Uploader can update own row (status/caption); host can moderate; worker uses service role.
create policy uploads_update_owner_or_host on public.uploads
  for update using (
    exists (select 1 from public.event_guests g where g.id = guest_id and g.auth_user_id = auth.uid())
    or public.is_event_host(event_id)
    or public.is_admin()
  )
  with check (
    exists (select 1 from public.event_guests g where g.id = guest_id and g.auth_user_id = auth.uid())
    or public.is_event_host(event_id)
    or public.is_admin()
  );

create policy uploads_delete_owner_or_host on public.uploads
  for delete using (
    exists (select 1 from public.event_guests g where g.id = guest_id and g.auth_user_id = auth.uid())
    or public.is_event_host(event_id)
    or public.is_admin()
  );

-- ============================================================
-- ALBUMS + ITEMS (written by worker/service role; read by members)
-- ============================================================
create policy albums_select_member on public.albums
  for select using (public.is_event_member(event_id) or public.is_admin());

create policy album_items_select_member on public.album_items
  for select using (
    exists (
      select 1 from public.albums a
      where a.id = album_id and (public.is_event_member(a.event_id) or public.is_admin())
    )
  );

-- ============================================================
-- FAVORITES
-- ============================================================
create policy favorites_select_own on public.favorites
  for select using (user_id = auth.uid() or public.is_admin());

create policy favorites_insert_own on public.favorites
  for insert with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.uploads u
      where u.id = upload_id and public.is_event_member(u.event_id)
    )
  );

create policy favorites_delete_own on public.favorites
  for delete using (user_id = auth.uid());

-- ============================================================
-- PAYMENTS (written by Edge Functions w/ service role)
-- ============================================================
create policy payments_select_own on public.payments
  for select using (host_id = auth.uid() or public.is_admin());

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
create policy notifications_select_own on public.notifications
  for select using (user_id = auth.uid());

create policy notifications_update_own on public.notifications
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy notifications_delete_own on public.notifications
  for delete using (user_id = auth.uid());

-- ============================================================
-- ACTIVITY LOGS (read: host of event or admin; write: triggers/service)
-- ============================================================
create policy activity_logs_select on public.activity_logs
  for select using (
    (event_id is not null and public.is_event_host(event_id)) or public.is_admin()
  );

-- ============================================================
-- FEATURE FLAGS (read all authed; write admin)
-- ============================================================
create policy feature_flags_select on public.feature_flags
  for select using (auth.uid() is not null);

create policy feature_flags_admin_write on public.feature_flags
  for all using (public.is_admin()) with check (public.is_admin());

-- ============================================================
-- PROCESSING JOBS (host visibility; worker uses service role)
-- ============================================================
create policy processing_jobs_select_host on public.processing_jobs
  for select using (public.is_event_host(event_id) or public.is_admin());

-- ============================================================
-- RPC: look up a joinable event by code or slug (pre-join, so
-- SECURITY DEFINER; returns only safe public fields).
-- ============================================================
create or replace function public.get_event_for_join(p_code text)
returns table (
  id uuid,
  title text,
  description text,
  type public.event_type,
  event_date date,
  location text,
  cover_url text,
  photo_count integer,
  video_count integer,
  photo_limit integer,
  is_full boolean
) language sql stable security definer set search_path = public as $$
  select
    e.id, e.title, e.description, e.type, e.event_date, e.location, e.cover_url,
    e.photo_count, e.video_count, e.photo_limit,
    (e.photo_count + e.video_count) >= e.photo_limit as is_full
  from public.events e
  where (upper(e.event_code) = upper(p_code) or e.share_slug = lower(p_code))
    and e.status = 'active'
    and e.expires_at > now()
  limit 1;
$$;

grant execute on function public.get_event_for_join(text) to authenticated, anon;
