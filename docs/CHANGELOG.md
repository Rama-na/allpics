# Changelog

All notable changes to AllPics. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [SemVer](https://semver.org/).

## [Unreleased]

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
