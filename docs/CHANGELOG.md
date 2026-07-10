# Changelog

All notable changes to AllPics. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [SemVer](https://semver.org/).

## [Unreleased] · Landing & onboarding UX overhaul

### Added
- **Try-first landing screen** (`/landing`): action-first entry with "Join an event" and "Create an event — free" as equal CTAs, free-tier messaging ("10 uploads, 30 days, no card"), glass hero, and a secondary sign-in link. Onboarding carousel now shows exactly once (persisted via `FirstRunStore`); the app no longer dead-ends on the sign-in form.
- **Deferred sign-up at event creation**: the create-event wizard is open to signed-out visitors; a bottom-sheet auth step ("Save your event") appears only when they publish. The form draft survives under the modal. `/events/new` exempted from the host-only router guard.
- **In-app camera** (`features/capture/`): tap for photo, hold for video (with recording timer), flip camera, flash cycle, and six swipeable color filters (Original/Mono/Sepia/Vivid/Warm/Cool) rendered live on the preview and baked into photos via `dart:ui` (videos keep filters preview-only). Review step with optional caption, feeding the existing upload queue. Guest upload panel gains an "Open camera" button (mobile; web keeps the gallery picker). Captions flow through `confirmUploaded` into the existing `uploads.caption` column.
- **Merchandised upgrade UX**: plans screen redesign (usage meter hero, per-plan taglines and feature bullets, per-upload value framing, "MOST POPULAR" emphasis on Plus, free plan hidden once outgrown); contextual upgrade bottom sheet for hosts fired once per session when an album passes 80% usage; persistent near-quota banner with progress bar on the event dashboard; friendlier guest album-full copy.
- Shimmer skeleton loaders (dependency-free) for the album grid and home event list.
- Video grid tiles now render the worker-generated thumbnail with a play badge instead of a bare placeholder icon.
- Accessibility: semantic labels on media tiles, the QR share card, landing CTAs, capture controls, and plan cards; live regions for quota banners.
- 24 new tests (127 total): landing/onboarding first-run flows, deferred-auth create (publish, dismiss, signed-in bypass), capture filters + filter baking + caption plumbing, plan merchandising + upgrade nudge session semantics, video-thumb media tiles, skeleton widgets. Full-journey E2E updated to the try-first flow.

### Changed
- Splash routing: signed-in hosts → home; first-time users → onboarding (once); everyone else → landing.
- `camera: ^0.11.4` dependency; Android manifest gains CAMERA/RECORD_AUDIO permissions (iOS usage descriptions already present).

## [1.0.0-rc.1] — 2026-07-07 · Phase 12: Deployment

### Added
- Android release configuration: `key.properties` signing flow (safe debug fallback), R8 minification with Razorpay keep rules, minSdk 23, App Links intent filter for `allpics.app/j/*`, INTERNET permission, proper app label.
- iOS release configuration: `Runner.entitlements` with Universal Links, photo/camera/microphone usage descriptions, display name.
- CI (`ci.yml`): Flutter analyze + tests + release web build, worker pytest + Docker build, Supabase migrations applied to a disposable stack and verified with the schema assertion script.
- Release workflow (`release.yml`): manual signed `.aab` build from repo secrets.
- docs/DEPLOYMENT.md: full release runbook — Android/iOS/web builds, scheduled-function registration, copy-ready store listing, and the credentials drop-in checklist.
- Verified: 98 Flutter tests + 22 worker tests green, `flutter build web --release` succeeds.

## [0.11.0] — 2026-07-07 · Phase 11: Testing Hardening

### Added
- Full-journey end-to-end test: onboarding → host sign-up → event creation → QR dashboard → sign-out → guest join by code → uploads with retry → live album updates → favorite round-trip — exercising every feature layer in one flow.
- Unit coverage for the persistence and infrastructure seams: `UploadTask` serialization (restore-as-queued semantics, in-memory tasks excluded by design), `UploadQueueStore` (pending-only persistence, corrupt-data recovery), `GoRouterRefreshStream`, `AlbumItem` parsing, and user-safe `AppException` message guarantees.
- `supabase/tests/verify_schema.sql`: post-migration verification — RLS enabled on all 13 tables, critical policies and functions present, plan seeds landed, buckets exist and are private. Fails loudly for CI/deploy gates.
- Suite totals: 98 Flutter tests + 22 worker tests, analyzer clean.

## [0.10.0] — 2026-07-07 · Phase 10: Settings

### Added
- Migration 0008: `delete_own_account()` — audited, cascading self-service account deletion.
- Settings screen: profile name editing, theme selector (system/light/dark — local-first via shared_preferences so it applies instantly and works offline, synced to the profile), notification preference switches (wired to the DB triggers from Phase 7), payment history + privacy links, sign out, and double-confirmed account deletion.
- In-app privacy policy screen.
- Home app bar simplified to notifications + settings (+ admin shield); history and sign-out moved into settings.
- Product decision: English-only (Hindi scaffold dropped).
- 6 new tests (87 total).

## [0.9.0] — 2026-07-07 · Phase 9: Admin Panel

### Added
- Migration 0007: self-guarded admin RPCs — `admin_stats` (platform aggregates incl. revenue, storage, job health), `admin_list_users` (with auth emails + event counts), `admin_list_events`, `admin_set_user_banned` (cannot ban self/admins, audited), `admin_delete_event` (audited).
- Admin panel at `/admin` (role-gated in-screen and server-side): Overview stat grid (responsive 2/4 columns), Users tab with search + ban/unban, Events tab with search + confirmed delete, Flags tab with live feature-flag toggles.
- Admin entry icon appears on home only for admins.
- `StatTile` now scales down instead of overflowing in tight grid cells.
- 5 new tests (81 total): access denial, stats rendering, ban round-trip, event delete, flag toggle.

## [0.8.0] — 2026-07-07 · Phase 8: AI Worker

### Added
- Migration 0006: per-upload job enqueueing (uploaded → `thumbnail` pipeline job), host-callable `enqueue_event_job` RPC (highlights/slideshow, dedup-guarded), `claim_processing_job` RPC with `FOR UPDATE SKIP LOCKED` (multi-replica safe, stuck-job reclaim, 3-attempt cap).
- Python worker (FastAPI + httpx + Pillow + numpy, ffmpeg for video):
  - Per-upload pipeline: EXIF-aware JPEG thumbnails, 64-bit DCT perceptual hash, Laplacian-variance blur detection, quality scoring, in-event dedupe that keeps the best-quality copy.
  - Enhancement: median-filter denoise + brightness/contrast/sharpen.
  - Highlights: quality-ranked selection excluding duplicates/blurry, max 3 per guest for variety, written to `albums`/`album_items`.
  - Slideshow: letterboxed 720p MP4 via ffmpeg, stored in the `exports` bucket.
  - Resilient poll loop (jobs can never kill the loop), `/healthz` with counters, graceful idle when unconfigured.
- Dockerfile (python:3.12-slim + ffmpeg) and a 22-test pytest suite (synthetic-image ops, selection logic, stubbed-API pipeline).

## [0.7.0] — 2026-07-07 · Phase 7: Notifications

### Added
- Notification generation in the database (migration 0005): guest joined, first-upload + every-25-uploads milestones, storage-low at 90% quota (single-fire), all respecting per-host notification preferences; expiry warnings deduped once per day.
- `event-expiry` Edge Function (scheduled daily): expiry sweep + T-3-day warnings. Service-key guarded.
- `send-notification` Edge Function (scheduled per minute): FCM HTTP v1 fan-out with service-account JWT signing, stale-token cleanup, `pushed_at` bookkeeping — degrades gracefully to in-app-only until `FCM_SERVICE_ACCOUNT_JSON` is set.
- Payment-success notification issued by the Razorpay webhook.
- In-app notification center: live Realtime list, unread highlighting, tap-through to the event dashboard, mark-read/mark-all-read, swipe-to-delete; unread badge on home.
- `PushGateway` abstraction with a no-op default — `firebase_messaging` plugs in behind it when Firebase config arrives, with token registration + refresh already wired.
- 6 new tests (76 total).

## [0.6.0] — 2026-07-07 · Phase 6: Payments

### Added
- `razorpay-order` Edge Function: host-ownership + plan validation, server-side Razorpay order creation (secret never leaves the server; the public key id is returned per-order so no client config is needed), `payments` lifecycle row.
- `razorpay-webhook` Edge Function: constant-time HMAC-SHA256 signature verification, idempotent capture handling, instant event upgrade (new quota + expiry from plan, expired events revive), invoice number issuance, failure recording.
- Plans screen: catalog with current-plan highlight, per-plan checkout via a `CheckoutGateway` abstraction wrapping razorpay_flutter (test- and platform-substitutable), success/cancel/failure states.
- Payment history screen with invoice numbers and a detail dialog; entry points on home and the event dashboard.
- Pre-provisioning behavior: plan catalog renders from static seed copy; purchases fail with a clear message until Razorpay env vars are set — fully modular for later credential drop-in.
- 10 new tests (70 total): model parsing and full checkout widget flows (success, cancel, order failure, history).

## [0.5.0] — 2026-07-07 · Phase 5: Album

### Added
- Album feature (host + guest): live grid gallery driven by Supabase Realtime with uploader-name resolution and signed-URL previews.
- Full-screen viewer: swipe between items (PageView), pinch-to-zoom photos (InteractiveViewer), in-app video playback with scrubbing (video_player), caption + uploader + timestamp overlay.
- Favorites: toggle from the viewer, live favorites stream, Favourites filter chip.
- Sort (newest / oldest / by guest), media filters (all / photos / videos / favourites), and search across guest names and captions.
- Downloads: single item and batch "download all" via the native share sheet.
- Routes `/album/:eventId` and `/album/:eventId/view` (member-visible, not host-guarded); entry buttons on the host dashboard and guest event screen.
- 11 new tests (60 total): view-state unit coverage and full widget flows (live updates, search, viewer swipe, favorite round-trip, empty state).

## [0.4.0] — 2026-07-07 · Phase 4: Uploads

### Added
- `create-upload-url` Edge Function: session check, guest membership + ban check, event active/expiry check, quota gate, mime whitelist (JPEG/PNG/WebP/HEIC + MP4/MOV/WebM), size caps (25 MB photo / 250 MB video), 30-per-minute per-guest rate limit, signed upload URL issuance with pending-row rollback on failure.
- Upload queue: 3-way parallel worker pool with per-file byte-level progress (chunked PUT to signed URL), typed error mapping, retry single/all, clear completed.
- Offline persistence: unfinished tasks survive app restarts (shared_preferences) and resume as queued.
- Quota-full handling: blocking a full album stops the whole queue with clear messaging; unsupported file types surface as visible failures.
- Guest event screen now hosts the full upload experience (multi-select via image_picker `pickMultipleMedia`).
- 9 new tests (49 total): worker-pool unit coverage (success, retry, quota, unsupported, clear) and widget flows.

## [0.3.0] — 2026-07-07 · Phase 3: Events

### Added
- Events feature (clean architecture): `Event` entity + `EventsRepository` with Supabase Realtime streams, PostgREST CRUD, cover upload to the `covers` bucket with signed-URL display.
- Create/edit event wizard: type chips, title/description/location, date picker, optional cover image (image_picker) — events start on the Free plan; code/slug/limits assigned by DB triggers.
- Host dashboard: live stat grid (guests, uploads used/left, videos, storage, days to expiry), QR code (qr_flutter), tap-to-copy event code, copy link, native share sheet (share_plus).
- Home: live event list with counter chips and expired badges; empty state with create action; FAB.
- Soft delete with confirmation; edit pre-filled from the dashboard menu.
- Router: `/events/new`, `/events/:id`, `/events/:id/edit` — host-guarded.
- 9 new tests (40 total): entity parsing/quota helpers, full create→dashboard, edit, delete widget flows with a live fake stream.

## [0.2.0] — 2026-07-07 · Phase 2: Auth

### Added
- Host authentication: email/password sign-in + sign-up, Google OAuth (Supabase provider), friendly error mapping, session persistence.
- Guest join flow: event code / QR deep link (`/j/<code>`) → event preview → name + optional phone → anonymous-auth join (idempotent re-join).
- Session-aware routing: splash routes by session, go_router redirects (hosts skip auth pages; home is host-only once backend is configured), auth-state refresh stream.
- Clean-architecture auth + guest features: repository interfaces, Supabase implementations, unconfigured fallbacks, Riverpod controllers.
- Shared `AppTextField`; form validators (email, password, name, phone, event code).
- Home shows the signed-in host and working sign-out.
- 19 new tests (31 total): controller units, validators, full sign-in/sign-up/join widget flows with fakes.

### Fixed
- `AppButton` and sign-in footer overflow on narrow screens.

## [0.1.0] — 2026-07-07 · Phase 1: Foundation

### Added
- Monorepo structure: `app/` (Flutter), `supabase/` (DB + functions), `worker/` (AI, scaffold), `docs/`.
- PostgreSQL schema (13 tables), enums, indexes across 4 migrations.
- Trigger layer: profile bootstrap, collision-safe event codes, race-safe quota enforcement, denormalized counters, audit logging, expiry sweep.
- Row Level Security policies on every table + private storage buckets with path-prefix policies.
- Seed data: plan catalog (Free/Basic/Plus/Premium) and default feature flags.
- Flutter app skeleton: Material 3 design system (light/dark, bundled Inter + Plus Jakarta Sans, glassmorphism card), Riverpod DI, go_router navigation.
- Screens: animated splash, 3-page onboarding, home shell with empty state.
- Shared widgets: `AppButton` (loading-aware), `GlassCard`, `LoadingView`/`ErrorView`/`EmptyView`.
- Typed error hierarchy (`AppException`) and central logging.
- Test suite: 12 tests (theme, shared widgets, full onboarding navigation flow) — all green; `flutter analyze` clean.
- Documentation set: README, PLAN, ARCHITECTURE, DATABASE, API, SECURITY, DEPLOYMENT, CHANGELOG, TASKS.
