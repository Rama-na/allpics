# AllPics — Deployment & Provisioning

## Phase 0 — Provisioning Checklist

### 1. Supabase
1. Create a project at https://supabase.com/dashboard (region closest to your users, e.g. `ap-south-1`).
2. Note: **Project URL**, **anon/publishable key**, **service-role key** (Settings → API).
3. Enable **anonymous sign-ins**: Authentication → Providers → Anonymous → enable.
4. Install the CLI and link:
   ```sh
   scoop install supabase        # or: npm i -g supabase
   cd supabase
   supabase login
   supabase link --project-ref <PROJECT_REF>
   supabase db push              # applies migrations
   supabase db seed              # or run seed.sql in the SQL editor
   ```

### 2. Firebase
1. Create a project at https://console.firebase.google.com.
2. Add an **Android app** (package `com.allpics.allpics`) → download `google-services.json` into `app/android/app/`.
3. Add an **iOS app** (bundle `com.allpics.allpics`) → download `GoogleService-Info.plist` into `app/ios/Runner/`.
4. Enable Cloud Messaging, Analytics, Crashlytics. (Wired into the app in Phase 7.)

### 3. Razorpay
1. Create an account at https://dashboard.razorpay.com (start in **Test Mode**).
2. Note **Key Id** and **Key Secret** (Settings → API Keys).
3. Webhook (Phase 6): add endpoint `https://<PROJECT_REF>.functions.supabase.co/razorpay-webhook`, events `payment.captured`, `payment.failed`; note the **webhook secret**.

### 4. Environment Files
Create `app/env/dev.json` from the template (never commit real values):

```sh
cp app/env/env.example.json app/env/dev.json
```

Run with:
```sh
flutter run --dart-define-from-file=env/dev.json
```

Edge Function secrets (set once per environment):
```sh
supabase secrets set RAZORPAY_KEY_ID=... RAZORPAY_KEY_SECRET=... RAZORPAY_WEBHOOK_SECRET=... FCM_SERVICE_ACCOUNT_JSON=...
```

## Local Development

```sh
# Full local stack (Postgres + Auth + Storage + Realtime)
cd supabase && supabase start && supabase db reset

# App against local stack — use the URL/key printed by `supabase start`
cd ../app && flutter run --dart-define-from-file=env/local.json
```

## Release Builds (finalized in Phase 12)

```sh
cd app
flutter build appbundle --release --dart-define-from-file=env/prod.json   # Android
flutter build ipa --release --dart-define-from-file=env/prod.json         # iOS (macOS + Xcode required)
flutter build web --release --dart-define-from-file=env/prod.json         # Admin panel
```

Phase 12 adds: Android keystore + Play Console setup, iOS signing + Universal Links entitlements, dev/prod flavors, CI/CD via GitHub Actions, and store listing metadata.

## AI Worker (Phase 8)

```sh
cd worker
docker build -t allpics-worker .
docker run -e SUPABASE_URL=... -e SUPABASE_SERVICE_ROLE_KEY=... allpics-worker
```
Deployable to any container host (Fly.io, Railway, Cloud Run, a VM).
