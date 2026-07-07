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

## Release Builds

### Android
1. Generate a keystore and configure signing:
   ```sh
   keytool -genkey -v -keystore app/android/allpics-release.keystore \
     -keyalg RSA -keysize 2048 -validity 10000 -alias allpics
   cp app/android/key.properties.example app/android/key.properties  # fill values
   ```
   `build.gradle.kts` picks up `key.properties` automatically (falls back to
   debug signing when absent so release builds never block). R8 minification
   + Razorpay keep rules are pre-configured.
2. Build:
   ```sh
   cd app
   flutter build appbundle --release --dart-define-from-file=env/prod.json
   ```
3. Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console
   (app id `com.allpics.allpics`).
4. App Links: host `/.well-known/assetlinks.json` on `allpics.app` with the
   release SHA-256 fingerprint so QR links open the app directly.

### iOS (requires macOS + Xcode)
1. Open `app/ios/Runner.xcworkspace`; set the team; the bundle id is
   `com.allpics.allpics`.
2. Enable the **Associated Domains** capability — `Runner.entitlements`
   already declares `applinks:allpics.app`; host
   `/.well-known/apple-app-site-association` on the domain.
3. Photo/camera/microphone usage descriptions are pre-filled in `Info.plist`.
4. Build: `flutter build ipa --release --dart-define-from-file=env/prod.json`
   and upload with Transporter / `xcrun altool`.

### Admin panel (web)
```sh
cd app && flutter build web --release --dart-define-from-file=env/prod.json
```
Deploy `build/web/` to any static host (Supabase Hosting, Netlify, Vercel).

## CI/CD

- `.github/workflows/ci.yml` — on every push/PR: `flutter analyze` + full
  test suite + web build; worker pytest + Docker build; Supabase migrations
  applied to a disposable stack and verified with
  `supabase/tests/verify_schema.sql`.
- `.github/workflows/release.yml` — manual dispatch; produces a signed
  `.aab` using repo secrets `ANDROID_KEYSTORE_BASE64`,
  `ANDROID_KEY_PROPERTIES`, and `PROD_ENV_JSON`.

## Scheduled Functions

After `supabase functions deploy`, register the schedules (Dashboard →
Edge Functions → Schedules, or `supabase functions schedule`):

| Function | Schedule | Purpose |
|---|---|---|
| `event-expiry` | `0 1 * * *` (daily) | expiry sweep + T-3d warnings |
| `send-notification` | `* * * * *` (per minute) | FCM push fan-out |

Both require the service-role key as the Bearer token (configure the
schedule's Authorization header accordingly).

## Store Listing (copy-ready)

- **Name:** AllPics — Every Photo. One Album.
- **Short description:** Collect every guest's photos with one QR code.
- **Full description:** AllPics gives your wedding, birthday, trip, or
  corporate event a single shared album. Create an event, show the QR code,
  and every guest can add their photos and videos instantly — no app
  download or account required for guests. Watch the album grow live,
  favorite the best shots, download everything, and let AllPics remove
  duplicates and pick highlights automatically. Plans from free (10 photos)
  to Premium (1000 photos, 6-month storage). Guests always upload free.
- **Category:** Photography · **Content rating:** Everyone
- **Privacy policy URL:** https://allpics.app/privacy

## When Credentials Arrive (drop-in checklist)

1. **Supabase**: fill `app/env/dev.json` + `env/prod.json`; then
   `supabase link --project-ref <REF> && supabase db push && supabase functions deploy`;
   enable anonymous sign-ins; run `tests/verify_schema.sql` against the
   project; seed plans via `seed.sql`.
2. **Razorpay**: `supabase secrets set RAZORPAY_KEY_ID=… RAZORPAY_KEY_SECRET=… RAZORPAY_WEBHOOK_SECRET=…`;
   add the webhook endpoint (`payment.captured`, `payment.failed`).
3. **Firebase**: drop `google-services.json` + `GoogleService-Info.plist`
   into the app; add `firebase_messaging` and implement
   `FirebasePushGateway` behind the existing `PushGateway` interface
   (single provider swap in `notifications/providers.dart`); set
   `FCM_SERVICE_ACCOUNT_JSON` secret for server push.
4. **Worker**: deploy the container with `SUPABASE_URL` +
   `SUPABASE_SERVICE_ROLE_KEY`.

## AI Worker (Phase 8)

```sh
cd worker
docker build -t allpics-worker .
docker run -e SUPABASE_URL=... -e SUPABASE_SERVICE_ROLE_KEY=... allpics-worker
```
Deployable to any container host (Fly.io, Railway, Cloud Run, a VM).
