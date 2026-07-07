/// Compile-time environment configuration.
///
/// Values are injected with `--dart-define` (or `--dart-define-from-file`):
/// ```sh
/// flutter run --dart-define-from-file=env/dev.json
/// ```
abstract final class AppEnv {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Base URL used in guest share links (e.g. https://allpics.app).
  static const String shareBaseUrl = String.fromEnvironment(
    'SHARE_BASE_URL',
    defaultValue: 'https://allpics.app',
  );

  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  /// True once Supabase credentials are provided. The app boots without
  /// them (Phase 0 provisioning) but backend features are disabled.
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get isProd => environment == 'prod';
}
