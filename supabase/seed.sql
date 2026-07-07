-- AllPics · seed.sql
-- Plan catalog (prices in paise) + default feature flags.

insert into public.plans (code, name, price_inr, photo_limit, storage_days, is_active, sort_order)
values
  ('free',    'Free',    0,     10,   30,  true, 0),
  ('basic',   'Basic',   15900, 100,  30,  true, 1),
  ('plus',    'Plus',    29900, 500,  30,  true, 2),
  ('premium', 'Premium', 59900, 1000, 180, true, 3)
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
