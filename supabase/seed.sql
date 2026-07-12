-- AllPics · seed.sql
-- Plan catalog (prices in paise) + default feature flags.
-- NOTE: kept in sync with migrations/0009_provisioning_backfill.sql — hosted
-- `supabase db push` never runs seeds, so the catalog also lives in a
-- migration. Update BOTH files when the catalog changes.
--
-- Catalog philosophy: free tier covers a real party (generous uploads) but
-- gates on TIME; paid tiers sell retention and AI keepsakes.

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
