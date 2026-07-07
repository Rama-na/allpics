-- AllPics · verify_schema.sql
-- Post-migration verification. Run after `supabase db reset` / `db push`:
--   psql "$DATABASE_URL" -f supabase/tests/verify_schema.sql
-- Raises an exception (non-zero exit) on the first failed check.

do $$
declare
  t text;
  missing text;
begin
  ---------------------------------------------------------------
  -- 1. RLS must be enabled on every application table
  ---------------------------------------------------------------
  for t in
    select tablename from pg_tables
    where schemaname = 'public'
      and tablename in (
        'profiles','plans','events','event_guests','uploads','albums',
        'album_items','favorites','payments','notifications',
        'activity_logs','feature_flags','processing_jobs'
      )
  loop
    if not exists (
      select 1 from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relname = t and c.relrowsecurity
    ) then
      raise exception 'RLS NOT ENABLED on table %', t;
    end if;
  end loop;

  ---------------------------------------------------------------
  -- 2. Critical policies exist
  ---------------------------------------------------------------
  for missing in
    select p.policy from (values
      ('profiles_select_own'), ('events_select_member'),
      ('events_insert_host'), ('event_guests_insert_self'),
      ('uploads_insert_guest'), ('uploads_select_member'),
      ('payments_select_own'), ('notifications_select_own'),
      ('feature_flags_admin_write')
    ) as p(policy)
    where not exists (
      select 1 from pg_policies where policyname = p.policy
    )
  loop
    raise exception 'MISSING POLICY %', missing;
  end loop;

  ---------------------------------------------------------------
  -- 3. Critical functions exist
  ---------------------------------------------------------------
  for missing in
    select f.fn from (values
      ('is_admin'), ('is_event_host'), ('is_event_guest'),
      ('get_event_for_join'), ('generate_event_code'),
      ('expire_events'), ('notify_expiring_events'),
      ('enqueue_event_job'), ('claim_processing_job'),
      ('admin_stats'), ('admin_list_users'), ('admin_set_user_banned'),
      ('admin_delete_event'), ('delete_own_account')
    ) as f(fn)
    where not exists (
      select 1 from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = f.fn
    )
  loop
    raise exception 'MISSING FUNCTION %', missing;
  end loop;

  ---------------------------------------------------------------
  -- 4. Seed data landed
  ---------------------------------------------------------------
  if (select count(*) from public.plans where is_active) < 4 then
    raise exception 'PLAN SEED MISSING (expected 4 active plans)';
  end if;

  ---------------------------------------------------------------
  -- 5. Storage buckets exist and are private
  ---------------------------------------------------------------
  for missing in
    select b.bucket from (values
      ('media'), ('thumbs'), ('covers'), ('exports')
    ) as b(bucket)
    where not exists (
      select 1 from storage.buckets where id = b.bucket and not public
    )
  loop
    raise exception 'MISSING OR PUBLIC BUCKET %', missing;
  end loop;

  raise notice 'AllPics schema verification: ALL CHECKS PASSED';
end $$;
