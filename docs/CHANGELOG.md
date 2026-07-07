# Changelog

All notable changes to AllPics. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [SemVer](https://semver.org/).

## [Unreleased]

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
