import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_env.dart';
import 'core/utils/app_logger.dart';

/// Initializes services and launches the app.
///
/// The app boots without Supabase credentials (pre-provisioning) so the UI
/// remains testable; backend-dependent features check
/// [AppEnv.isSupabaseConfigured].
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.init();
  final log = AppLogger.get('bootstrap');

  if (AppEnv.isSupabaseConfigured) {
    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      // Supports both legacy anon keys and new publishable keys.
      // ignore: deprecated_member_use
      anonKey: AppEnv.supabaseAnonKey,
      // PKCE is the default, but the Google OAuth deep-link return
      // (io.allpics.app://login-callback/) depends on it — keep explicit.
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    log.info('Supabase initialized (${AppEnv.environment})');
  } else {
    log.warning('Supabase env not set — running in unconfigured mode');
  }

  runApp(const ProviderScope(child: AllPicsApp()));
}
