import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_env.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/providers.dart';

/// Host home shell. Phase 3 replaces the body with the events list +
/// create-event flow.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AllPics'),
        actions: [
          if (user != null)
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!AppEnv.isSupabaseConfigured)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Text(
                'Backend not configured. Run with '
                '--dart-define-from-file=env/dev.json after provisioning '
                'Supabase (see docs/DEPLOYMENT.md).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: EmptyView(
              icon: Icons.celebration_rounded,
              title: user?.fullName?.isNotEmpty == true
                  ? 'Welcome, ${user!.fullName}!'
                  : 'No events yet',
              subtitle:
                  'Create your first event and collect every photo from every guest with one QR code.',
            ),
          ),
        ],
      ),
    );
  }
}
