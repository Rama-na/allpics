# AllPics — Product & Engineering Plan

## Mission
Allow event organizers to collect every photo and video from every guest through one QR code, into one beautiful shared event album. Guests upload instantly without creating an account.

## Target Users
Weddings · Birthdays · Baby Showers · College Farewells · Trips · Family Functions · Corporate Events · Music Festivals · School Reunions

## User Types
- **Host** — creates events, purchases plans, manages the album
- **Guest** — scans QR / opens link, enters a name, uploads (no account)
- **Admin** — internal operators using the web admin panel

## Tech Stack
| Concern | Choice |
|---|---|
| Mobile + admin web | Flutter (Material 3, Riverpod, go_router) |
| Backend | Supabase (PostgreSQL, Auth, Storage, Edge Functions, Realtime) |
| Guest identity | Supabase anonymous auth (real uid → RLS works) |
| Payments | Razorpay (orders + webhooks in Edge Functions) |
| Push / analytics / crashes | Firebase FCM, Analytics, Crashlytics |
| AI processing | Python worker (FastAPI, OpenCV, imagehash, ffmpeg) via `processing_jobs` queue |
| QR codes | Generated client-side (qr_flutter) from the event share link |

## Phase Roadmap

| Phase | Deliverable | Status |
|---|---|---|
| 0 | Provisioning: Supabase, Firebase, Razorpay accounts + env files | pending (user-assisted — credentials to be provided) |
| 1 | Foundation: docs, monorepo, DB schema + RLS, Flutter skeleton + design system | **done** |
| 2 | Auth: host email/Google sign-in, guest anonymous join | **done** |
| 3 | Events: creation wizard, event code + QR + share link, realtime dashboard | **done** |
| 4 | Uploads: signed URLs, progress, retry, offline queue | **done** |
| 5 | Album: gallery, viewer, favorites, sort/search, downloads, live updates | **done** |
| 6 | Payments: Razorpay checkout, webhook quota updates, invoices | **done** |
| 7 | Notifications: FCM fan-out + in-app center | **done** |
| 8 | AI worker: dedupe, blur, enhance, highlights, slideshow | **done** |
| 9 | Admin panel (Flutter web) | **done** |
| 10 | Settings, polish (English-only) | **done** |
| 11 | Testing hardening | **done** |
| 12 | Deployment: signing, CI/CD, store metadata | **done** |

## Per-Phase Quality Gates
1. `flutter analyze` — zero issues
2. `flutter test` — green
3. `supabase db reset` — migrations apply cleanly
4. No regression of previously working flows
5. [TASKS.md](../TASKS.md) updated

## Key Product Rules
- Photo limit applies per event (photos + videos combined) and is enforced in the database (trigger) *and* at the signed-URL gate.
- Events expire per plan (`storage_days`); expired events become read-only and are swept by a scheduled function.
- Guests are always free; only hosts pay.
- Payment success must update the event quota immediately (webhook + client confirmation fallback).
