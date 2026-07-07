import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-selected theme mode — local-first (applies instantly, works without
/// a backend) and synced to the profile from the settings screen.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _prefsKey = 'allpics.theme_mode';

  @override
  ThemeMode build() {
    // Restore asynchronously; guarded so tests without the plugin still run.
    Future(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString(_prefsKey);
        if (saved != null) state = _fromName(saved);
      } catch (_) {
        // Plugin unavailable (pure unit-test environment) — keep default.
      }
    });
    return ThemeMode.system;
  }

  static ThemeMode _fromName(String name) => ThemeMode.values.firstWhere(
        (m) => m.name == name,
        orElse: () => ThemeMode.system,
      );

  void set(ThemeMode mode) {
    state = mode;
    Future(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, mode.name);
      } catch (_) {
        // Best-effort persistence.
      }
    });
  }

  /// Applies a profile-stored theme name ('system'|'light'|'dark').
  void applyProfileTheme(String name) => set(_fromName(name));
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
