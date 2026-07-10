import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/glass_card.dart';

/// Action-first landing: try the app before creating an account.
///
/// Guests jump straight into an event; hosts can start building an event and
/// only meet the sign-up step when they publish it.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Soft brand wash behind the glass hero.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x336C5CE7), Color(0x22FF7A85)],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            gradient: AppColors.brandGradient,
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                          ),
                          child: const Icon(
                            Icons.photo_camera_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Every photo and video.\nOne album.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Collect every guest\'s photos and videos through '
                        'one QR code — no app installs, no accounts for guests.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      GlassCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              button: true,
                              label: 'Join an event with a code or QR',
                              child: AppButton(
                                label: 'Join an event',
                                icon: Icons.qr_code_rounded,
                                onPressed: () => context.goNamed(AppRoute.join),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Semantics(
                              button: true,
                              label: 'Create an event for free',
                              child: AppButton(
                                label: 'Create an event — free',
                                icon: Icons.add_a_photo_rounded,
                                variant: AppButtonVariant.secondary,
                                onPressed: () =>
                                    context.goNamed(AppRoute.createEvent),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Free to start — 10 uploads, 30 days. '
                              'No card needed.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Already hosting?',
                            style: theme.textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: () => context.goNamed(AppRoute.signIn),
                            child: const Text('Sign in'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
