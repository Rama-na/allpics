-- AllPics · 0009_provisioning_backfill.sql
--
-- Hosted `supabase db push` applies migrations but NEVER runs seed.sql
-- (seeds only run on local `db reset`). A project provisioned by `db push`
-- alone therefore had an empty `plans` table, so the app's free-plan lookup
-- failed and "Create event" surfaced a generic "Something went wrong."
-- This migration makes plain `db push` fully provision a working backend.
--
-- Idempotent by construction; safe to re-run. Keep the catalog in sync with
-- seed.sql (local/CI path).

-- ============================================================
-- 1. Plan catalog (prices in paise).
--    Free covers a real party but gates on TIME; paid tiers sell retention
--    and AI keepsakes (highlights/slideshow at Plus and up).
-- ============================================================
insert into public.plans (code, name, price_inr, photo_limit, storage_days, is_active, sort_order)
values
  ('free',    'Free',    0,     100,  7,   true, 0),
  ('basic',   'Basic',   19900, 500,  30,  true, 1),
  ('plus',    'Plus',    39900, 2000, 90,  true, 2),
  ('premium', 'Premium', 79900, 5000, 365, true, 3)
on conflict (code) do update set
  name = excluded.name,
  price_inr = excluded.price_inr,
  photo_limit = excluded.photo_limit,
  storage_days = excluded.storage_days,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order;

-- ============================================================
-- 2. Default feature flags (worker + admin read these).
-- ============================================================
insert into public.feature_flags (key, enabled, payload)
values
  ('ai_dedupe',       true,  '{}'),
  ('ai_blur_detect',  true,  '{}'),
  ('ai_enhance',      true,  '{}'),
  ('ai_highlights',   true,  '{"max_items": 30}'),
  ('ai_slideshow',    true,  '{"max_duration_s": 120}'),
  ('virus_scan',      false, '{}'),
  ('guest_video_upload', true, '{"max_bytes": 262144000}')
on conflict (key) do nothing;

-- ============================================================
-- 3. Profile backfill.
--    profiles rows are normally created by the on-auth-user-created trigger
--    (0002); accounts created BEFORE migrations were pushed have none, and
--    events_insert_host (0003) rejects hosts without a profile.
--    Mirrors handle_new_user for existing non-anonymous users.
-- ============================================================
insert into public.profiles (id, full_name, avatar_url)
select u.id,
       coalesce(u.raw_user_meta_data ->> 'full_name', ''),
       u.raw_user_meta_data ->> 'avatar_url'
from auth.users u
where not coalesce(u.is_anonymous, false)
  and not exists (select 1 from public.profiles p where p.id = u.id)
on conflict (id) do nothing;
