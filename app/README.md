# AllPics — Flutter app

**Every Photo. One Album.** Android, iOS, and Web client. See the [repo root README](../README.md) for the monorepo overview.

## Run

```sh
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```

`env/dev.json` is gitignored — copy `env/env.example.json` and fill in the Supabase project credentials. The app boots without credentials (backend features disabled).

## Verify

```sh
flutter analyze   # must be clean
flutter test      # must be green
```

## Branding assets

Source assets live in `assets/branding/`:

| File | Used for | Regenerate with |
|---|---|---|
| `app_icon.png` (1024×1024) | Launcher icons (Android adaptive, iOS, web) | `dart run flutter_launcher_icons` |
| `splash_logo.png` (white glyph, transparent) | Native + web splash screens | `dart run flutter_native_splash:create` |

To rebrand: replace the PNG(s), run both commands above, then `cd ios && pod install`. Config lives in `pubspec.yaml` under `flutter_launcher_icons:` and `flutter_native_splash:` (brand violet `#6C5CE7`, dark `#0E0D12`).
