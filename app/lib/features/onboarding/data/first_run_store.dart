import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the intro carousel has been seen, so onboarding shows
/// exactly once. Local-first and guarded so tests without the plugin run.
class FirstRunStore {
  const FirstRunStore();

  static const _seenKey = 'allpics.onboarding_seen';

  Future<bool> hasSeenOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_seenKey) ?? false;
    } catch (_) {
      // Plugin unavailable (pure unit-test environment) — show onboarding.
      return false;
    }
  }

  Future<void> markOnboardingSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seenKey, true);
    } catch (_) {
      // Best-effort persistence.
    }
  }
}
