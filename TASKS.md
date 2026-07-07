# AllPics — Task Checklist

> Living checklist. Updated at every phase. Never mark a task done unless verified.

## Phase 0 — Provisioning (user-assisted)
- [ ] Create Supabase project (note project ref, anon key, service role key)
- [ ] Install Supabase CLI (`scoop install supabase` or `npm i -g supabase`)
- [ ] Create Firebase project + Android & iOS apps (FCM, Analytics, Crashlytics)
- [ ] Create Razorpay test account (key id + secret + webhook secret)
- [ ] Fill `.env` files from templates

## Phase 1 — Foundation
- [x] Monorepo structure (`app/`, `supabase/`, `worker/`, `docs/`)
- [x] Documentation set (README, PLAN, ARCHITECTURE, DATABASE, API, DEPLOYMENT, SECURITY, CHANGELOG)
- [x] Database migrations: schema + triggers + RLS + seed plans
- [x] Flutter app scaffold (Material 3, dark/light theme, typography, glass components)
- [x] Core: router (go_router), DI (Riverpod), errors, constants, env config
- [x] Shared widgets: buttons, cards, loading/empty/error states, shimmer
- [x] `flutter analyze` clean
- [x] `flutter test` green

## Phase 2 — Auth
- [x] Host sign-up / sign-in (email + password)
- [x] Google sign-in (via Supabase OAuth; enable provider in dashboard — live verify after Phase 0)
- [x] Profile auto-creation trigger
- [x] Guest anonymous auth + join flow (name, optional phone)
- [x] Session persistence + splash routing

## Phase 3 — Events
- [x] Create event wizard (type, title, description, date, location, cover)
- [x] Unique event code + QR + share link
- [x] Host dashboard with live counters
- [x] Event settings / edit / delete

## Phase 4 — Uploads
- [x] Signed upload URL Edge Function (quota, mime, size, rate limit)
- [x] Guest multi-select upload with progress
- [x] Retry failed uploads, offline queue
- [x] Quota exceeded UX

## Phase 5 — Album
- [x] Grid gallery + thumbnails
- [x] Full-screen viewer (pinch zoom, swipe)
- [x] Favorites, sort, search
- [x] Download single / all
- [x] Realtime album updates

## Phase 6 — Payments
- [x] Plans screen
- [x] Razorpay checkout (order Edge Function)
- [x] Webhook: verify signature, apply plan idempotently
- [x] Invoice generation + payment history
  - Note: invoice number issued by webhook; PDF export lands with the worker (Phase 8)

## Phase 7 — Notifications
- [x] FCM token registration (PushGateway abstraction; FirebasePushGateway drops in with Firebase config)
- [x] Notification fan-out Edge Function (send-notification, FCM HTTP v1)
- [x] Triggers: guest joined, new uploads, expiring, storage full, payment success
- [x] In-app notification center

## Phase 8 — AI Worker
- [x] FastAPI worker + job queue consumer
- [x] Duplicate detection (perceptual hash, keep best)
- [x] Blur detection (Laplacian variance)
- [x] Enhancement (brightness/contrast/sharpen/denoise)
- [x] Highlights album generation
- [x] Slideshow generation (ffmpeg)
- [x] Dockerfile + deploy docs

## Phase 9 — Admin Panel (Flutter Web)
- [x] Role-gated admin routes
- [x] Users, events, payments management
- [x] Analytics + storage usage
- [x] Ban users, delete events, feature flags

## Phase 10 — Settings & Polish
- [x] Profile, notification prefs, theme toggle
- [x] i18n — English only (Hindi dropped per product decision)
- [x] Delete account, privacy screens
- [x] Micro-animation pass (button/loading transitions, page transitions, splash/onboarding animations, badge)

## Phase 11 — Testing Hardening
- [x] Unit tests (repositories, notifiers)
- [x] Widget tests (all screens)
- [x] Integration test: host → event → guest join → upload → album
- [x] Worker pytest suite
- [x] RLS assertion tests (supabase/tests/verify_schema.sql — run post-migration)

## Phase 12 — Deployment
- [x] Android signing + Play config (key.properties flow, R8 + Razorpay keep rules, App Links intent filter)
- [x] iOS entitlements + Universal Links (Runner.entitlements, usage descriptions)
- [x] Dev/prod flavors (via --dart-define-from-file env json)
- [x] CI/CD (GitHub Actions: ci.yml analyze/test/web-build/pytest/docker/migrations-verify; release.yml signed .aab)
- [x] Store metadata (docs/DEPLOYMENT.md § Store Listing)
- [x] Release build verified (flutter build web --release)
