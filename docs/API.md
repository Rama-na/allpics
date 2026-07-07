# AllPics — API Surface

The client talks to Supabase via PostgREST (RLS-guarded tables), RPC functions, Realtime channels, and Edge Functions. This document is the contract; functions are implemented in their scheduled phases.

## RPC (implemented)

### `get_event_for_join(p_code text)`
Pre-join lookup by event code or share slug. `SECURITY DEFINER`; returns only safe public fields for active, unexpired events.

**Returns:** `id, title, description, type, event_date, location, cover_url, photo_count, video_count, photo_limit, is_full`

## Edge Functions

All functions require `Authorization: Bearer <access_token>` (anonymous or full session) unless noted. Errors use `{ "error": { "code": string, "message": string } }` with proper HTTP status.

### `POST /functions/v1/create-upload-url` — Phase 4
Issues a signed upload URL after validating membership, quota, mime type, and size, and inserts a `pending` uploads row.

Request:
```json
{ "event_id": "uuid", "file_name": "IMG_1234.heic", "mime_type": "image/heic", "bytes": 4194304 }
```
Response `200`:
```json
{ "upload_id": "uuid", "storage_path": "media/{event}/{upload}.heic", "signed_url": "https://…", "token": "…" }
```
Errors: `401 not_joined`, `403 banned`, `409 quota_exceeded`, `410 event_expired`, `415 unsupported_media`, `413 too_large`, `429 rate_limited`

### `POST /functions/v1/razorpay-order` — Phase 6
Creates a Razorpay order for a plan purchase. Host-only.
```json
{ "event_id": "uuid", "plan_code": "plus" }
```
Response: `{ "order_id": "order_…", "amount": 29900, "currency": "INR", "key_id": "rzp_…" }`

### `POST /functions/v1/razorpay-webhook` — Phase 6
Razorpay server webhook. Verifies `X-Razorpay-Signature` (HMAC-SHA256), idempotently marks the payment `captured`, upgrades `events.photo_limit`/`expires_at`, generates the invoice. **No client auth; signature is the auth.**

### `POST /functions/v1/send-notification` — Phase 7
Internal fan-out: writes `notifications` rows and pushes FCM. Invoked by DB webhooks/schedules with a service token.

### `POST /functions/v1/event-expiry` — Phase 7 (scheduled)
Runs `expire_events()`, sends "album expiring soon" notifications at T-3 days.

## Realtime Channels

| Channel | Table filter | Consumers |
|---|---|---|
| `event:{id}:uploads` | `uploads` where `event_id=eq.{id}` | live album, upload counters |
| `event:{id}` | `events` where `id=eq.{id}` | host dashboard counters |

## Direct Table Access (via RLS)

Typical PostgREST usage from the client:
- `events` — host CRUD, member reads
- `event_guests` — guest self-insert on join
- `uploads` — member reads; status/caption updates by owner
- `favorites` — toggle by any member
- `notifications` — list + mark read
- `plans`, `feature_flags` — read-only catalogs
