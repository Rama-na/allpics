# AllPics

**Every Photo. One Album.**

AllPics lets event organizers collect every photo and video from every guest through one QR code. Instead of photos scattered across WhatsApp, AirDrop, Google Photos and Instagram, AllPics creates one beautiful shared event album. Guests upload instantly — no account required.

## Monorepo Layout

| Path | Description |
|---|---|
| [app/](app/) | Flutter application (Android, iOS, and Web admin panel) |
| [supabase/](supabase/) | Database migrations, RLS policies, seed data, Edge Functions |
| [worker/](worker/) | Python AI worker (dedupe, blur detection, enhancement, highlights, slideshow) — Phase 8 |
| [docs/](docs/) | Full project documentation |
| [TASKS.md](TASKS.md) | Living task checklist across all phases |

## Quick Start

Prerequisites: Flutter ≥ 3.44, Supabase CLI, a provisioned Supabase project (see [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)).

```sh
# 1. Apply database migrations (local stack)
cd supabase
supabase start
supabase db reset          # applies migrations + seed.sql

# 2. Run the app
cd ../app
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```

The app boots without Supabase credentials (backend features disabled) so UI work and tests never block on provisioning.

## Verification

```sh
cd app
flutter analyze   # must be clean
flutter test      # must be green
```

## Documentation

- [docs/PLAN.md](docs/PLAN.md) — product plan and phase roadmap
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — system and app architecture
- [docs/DATABASE.md](docs/DATABASE.md) — schema, triggers, RLS
- [docs/API.md](docs/API.md) — Edge Functions and RPC surface
- [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) — provisioning and release
- [docs/SECURITY.md](docs/SECURITY.md) — threat model and controls
- [docs/CHANGELOG.md](docs/CHANGELOG.md) — release history

## Plans

| Plan | Photos | Storage | Price |
|---|---|---|---|
| Free | 10 | 30 days | ₹0 |
| Basic | 100 | 30 days | ₹159 |
| Plus | 500 | 30 days | ₹299 |
| Premium | 1000 | 6 months | ₹599 |

Hosts purchase the plan; guests always upload free. The photo limit applies to the entire event.
