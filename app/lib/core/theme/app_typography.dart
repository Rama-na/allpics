import 'package:flutter/material.dart';

/// Typography scale: Plus Jakarta Sans for display, Inter for body.
/// Both are bundled variable fonts (assets/fonts) — no runtime fetching.
abstract final class AppTypography {
  static const String bodyFamily = 'Inter';
  static const String displayFamily = 'PlusJakartaSans';

  static TextTheme textTheme(Brightness brightness) {
    final base = (brightness == Brightness.dark
            ? Typography.material2021().white
            : Typography.material2021().black)
        .apply(fontFamily: bodyFamily);

    TextStyle? display(TextStyle? style, FontWeight weight, [double? spacing]) =>
        style?.copyWith(
          fontFamily: displayFamily,
          fontWeight: weight,
          letterSpacing: spacing,
        );

    return base.copyWith(
      displayLarge: display(base.displayLarge, FontWeight.w700, -1.0),
      displayMedium: display(base.displayMedium, FontWeight.w700, -0.5),
      displaySmall: display(base.displaySmall, FontWeight.w700, -0.5),
      headlineLarge: display(base.headlineLarge, FontWeight.w700, -0.5),
      headlineMedium: display(base.headlineMedium, FontWeight.w600),
      headlineSmall: display(base.headlineSmall, FontWeight.w600),
      titleLarge: display(base.titleLarge, FontWeight.w600),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}
