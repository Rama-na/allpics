-- AllPics · 0004_storage.sql
-- Storage buckets + policies.
-- Writes go through the create-upload-url Edge Function (signed upload URLs),
-- which validates quota/mime/size with the service role. Direct client writes
-- are additionally permitted only for joined guests into their event prefix.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('media',  'media',  false, 262144000, array[
      'image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif',
      'video/mp4', 'video/quicktime', 'video/webm'
  ]),
  ('thumbs', 'thumbs', false, 5242880, array['image/jpeg', 'image/webp']),
  ('covers', 'covers', false, 10485760, array['image/jpeg', 'image/png', 'image/webp']),
  ('exports', 'exports', false, 1073741824, array['video/mp4', 'application/zip', 'application/pdf'])
on conflict (id) do nothing;

-- Path convention:
--   media/{event_id}/{upload_id}.{ext}
--   thumbs/{event_id}/{upload_id}.jpg
--   covers/{event_id}/cover.{ext}
--   exports/{event_id}/{artifact}

-- ============================================================
-- MEDIA: read for event members; insert for joined guests into own event
-- ============================================================
create policy storage_media_read on storage.objects
  for select using (
    bucket_id = 'media'
    and public.is_event_member(((storage.foldername(name))[1])::uuid)
  );

create policy storage_media_insert_guest on storage.objects
  for insert with check (
    bucket_id = 'media'
    and public.is_event_guest(((storage.foldername(name))[1])::uuid)
  );

create policy storage_media_delete_host on storage.objects
  for delete using (
    bucket_id = 'media'
    and (public.is_event_host(((storage.foldername(name))[1])::uuid) or public.is_admin())
  );

-- ============================================================
-- THUMBS: read for members (written by worker via service role)
-- ============================================================
create policy storage_thumbs_read on storage.objects
  for select using (
    bucket_id = 'thumbs'
    and public.is_event_member(((storage.foldername(name))[1])::uuid)
  );

-- ============================================================
-- COVERS: read for members; host writes own event cover
-- ============================================================
create policy storage_covers_read on storage.objects
  for select using (
    bucket_id = 'covers'
    and public.is_event_member(((storage.foldername(name))[1])::uuid)
  );

create policy storage_covers_write_host on storage.objects
  for insert with check (
    bucket_id = 'covers'
    and public.is_event_host(((storage.foldername(name))[1])::uuid)
  );

create policy storage_covers_update_host on storage.objects
  for update using (
    bucket_id = 'covers'
    and public.is_event_host(((storage.foldername(name))[1])::uuid)
  );

create policy storage_covers_delete_host on storage.objects
  for delete using (
    bucket_id = 'covers'
    and (public.is_event_host(((storage.foldername(name))[1])::uuid) or public.is_admin())
  );

-- ============================================================
-- EXPORTS: read for host only (slideshows, zips, invoices)
-- ============================================================
create policy storage_exports_read_host on storage.objects
  for select using (
    bucket_id = 'exports'
    and (public.is_event_host(((storage.foldername(name))[1])::uuid) or public.is_admin())
  );
