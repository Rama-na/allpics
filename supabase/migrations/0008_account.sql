-- AllPics · 0008_account.sql
-- Self-service account deletion (GDPR-style).

-- Deletes the caller's auth user. All owned data cascades:
--   profiles → events → event_guests/uploads/albums/payments/notifications.
-- Storage objects are cleaned by the expiry sweep / storage lifecycle.
create or replace function public.delete_own_account()
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  -- Audit before the row disappears.
  insert into public.activity_logs (actor_id, action, metadata)
  values (v_uid, 'account.deleted', '{}'::jsonb);

  delete from auth.users where id = v_uid;
end $$;

grant execute on function public.delete_own_account() to authenticated;
