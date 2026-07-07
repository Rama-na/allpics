# AllPics — Security

## Principles
1. **Deny by default** — RLS enabled on every table; only explicit policies grant access.
2. **No unauthenticated writes** — even guests hold a real (anonymous) Supabase auth session.
3. **Defense in depth** — every limit (quota, mime, size) is enforced at UI, Edge Function, and database/bucket layers.
4. **Secrets never ship** — Razorpay secret, service-role key, and FCM server key exist only in Edge Function / worker environments.

## Threat Model & Controls

| Threat | Control |
|---|---|
| Guest uploads to an event they never joined | RLS `uploads_insert_guest` requires an `event_guests` row bound to `auth.uid()`; storage policy checks the event-id path prefix |
| Quota bypass via concurrent uploads | `handle_upload_insert` trigger takes a row lock (`FOR UPDATE`) before checking `photo_limit` |
| Uploading executables/malware | Bucket `allowed_mime_types` + Edge Function mime/extension validation + worker server-side mime sniffing; optional ClamAV scan behind the `virus_scan` feature flag |
| Forged payment confirmation | Only the Razorpay webhook (HMAC-SHA256 signature verified) upgrades quota; client "success" alone never mutates plan state; idempotent by `razorpay_order_id` |
| Privilege escalation via profile update | `profiles_update_own` policy pins `role` and `is_banned` to current values |
| Event code enumeration | Codes are 6 chars from a 31-symbol alphabet (~887M combos), unambiguous charset, rate-limited lookup via `get_event_for_join` |
| Spam / abuse floods | Per-guest and per-IP rate limits in Edge Functions; `is_banned` on both profiles and event_guests; admin ban tooling (Phase 9) |
| Data exposure pre-join | `get_event_for_join` returns only safe public fields; everything else requires membership |
| Stolen signed upload URL | Signed URLs are single-path, short-TTL, and bound to a pre-created `pending` row |
| Admin panel exposure | `role='admin'` checked in RLS (`is_admin()`), in the router guard, and admin routes are only compiled into the web build |

## Storage Security
- All buckets private; access via RLS policies or short-lived signed URLs only.
- Path convention `{bucket}/{event_id}/…` makes every storage policy a single-prefix check.
- Per-bucket size and mime allowlists (see [DATABASE.md](DATABASE.md)).

## Operational
- Anonymous sessions are not persisted beyond the event lifetime; expired-event sweep revokes access naturally via `status` checks.
- `activity_logs` provides an audit trail for event creation, joins, and payments.
- Crashlytics reports scrub PII; logs never include tokens or storage URLs.

## Reporting
Security issues: open a private issue or contact the maintainer. Do not file public issues for vulnerabilities.
