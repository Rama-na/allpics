# Changelog

All notable changes to AllPics. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [SemVer](https://semver.org/).

## [Unreleased]

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
