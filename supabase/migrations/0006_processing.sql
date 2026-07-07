-- AllPics · 0006_processing.sql
-- Job enqueueing for the AI worker + atomic claim RPC.

-- ============================================================
-- Enqueue per-upload processing when bytes land (status → uploaded).
-- One 'thumbnail' job represents the full per-upload pipeline:
-- thumbnail → phash → blur/quality → dedupe → status 'ready'.
-- ============================================================
create or replace function public.enqueue_upload_processing()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'uploaded' and old.status = 'pending' then
    insert into public.processing_jobs (event_id, upload_id, job_type)
    values (new.event_id, new.id, 'thumbnail');
  end if;
  return new;
end $$;

create trigger trg_enqueue_upload_processing
  after update of status on public.uploads
  for each row execute function public.enqueue_upload_processing();

-- ============================================================
-- Host-triggered event-level jobs (enhance/highlights/slideshow).
-- Deduplicates: refuses when the same job is already queued/running.
-- ============================================================
create or replace function public.enqueue_event_job(
  p_event_id uuid,
  p_job_type public.job_type
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_job_id uuid;
begin
  if not public.is_event_host(p_event_id) then
    raise exception 'NOT_EVENT_HOST';
  end if;
  if p_job_type not in ('highlights', 'slideshow') then
    raise exception 'UNSUPPORTED_JOB_TYPE';
  end if;
  if exists (
    select 1 from public.processing_jobs
    where event_id = p_event_id
      and job_type = p_job_type
      and status in ('queued', 'running')
  ) then
    raise exception 'JOB_ALREADY_QUEUED';
  end if;

  insert into public.processing_jobs (event_id, job_type)
  values (p_event_id, p_job_type)
  returning id into v_job_id;
  return v_job_id;
end $$;

grant execute on function public.enqueue_event_job(uuid, public.job_type)
  to authenticated;

-- ============================================================
-- Atomic job claim for the worker (service role).
-- FOR UPDATE SKIP LOCKED → safe with multiple worker replicas.
-- Jobs stuck in 'running' for >10 minutes are reclaimed.
-- ============================================================
create or replace function public.claim_processing_job()
returns setof public.processing_jobs
language plpgsql security definer set search_path = public as $$
declare
  v_job public.processing_jobs%rowtype;
begin
  select * into v_job
  from public.processing_jobs
  where status = 'queued'
     or (status = 'running' and updated_at < now() - interval '10 minutes'
         and attempts < 3)
  order by created_at
  limit 1
  for update skip locked;

  if not found then
    return;
  end if;

  update public.processing_jobs
    set status = 'running', attempts = attempts + 1
    where id = v_job.id;

  return query select * from public.processing_jobs where id = v_job.id;
end $$;

-- Service role only — no grants to authenticated/anon.
revoke execute on function public.claim_processing_job() from public;
