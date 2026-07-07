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
- [ ] Profile, notification prefs, theme toggle
- [ ] i18n (en, hi)
- [ ] Delete account, privacy screens
- [ ] Micro-animation pass

## Phase 11 — Testing Hardening
- [ ] Unit tests (repositories, notifiers)
- [ ] Widget tests (all screens)
- [ ] Integration test: host → event → guest join → upload → album
- [ ] Worker pytest suite
- [ ] RLS assertion tests

## Phase 12 — Deployment
- [ ] Android signing + Play config
- [ ] iOS entitlements + Universal Links
- [ ] Dev/prod flavors
- [ ] CI/CD (GitHub Actions)
- [ ] Store metadata
