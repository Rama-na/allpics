import 'package:flutter/material.dart';

/// AllPics brand palette.
///
/// Seeded Material 3 scheme from [seed], with hand-tuned surfaces for a
/// premium look in both modes.
abstract final class AppColors {
  /// Brand seed — soft violet.
  static const Color seed = Color(0xFF6C5CE7);

  /// Accent used for gradients and highlights.
  static const Color accent = Color(0xFFFF7A85);

  static const Color success = Color(0xFF2ECC8F);
  static const Color warning = Color(0xFFF5A623);

  // Light surfaces
  static const Color lightBackground = Color(0xFFFAFAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F0F7);

  // Dark surfaces
  static const Color darkBackground = Color(0xFF0E0D12);
  static const Color darkSurface = Color(0xFF17161D);
  static const Color darkSurfaceVariant = Color(0xFF211F2A);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [seed, accent],
  );
}
