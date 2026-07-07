import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_env.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/providers.dart';
import '../../events/presentation/widgets/event_card.dart';
import '../../events/providers.dart';

/// Host home: live list of events + create action.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final eventsAsync = ref.watch(myEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AllPics'),
        actions: [
          if (user != null)
            IconButton(
              tooltip: 'Payment history',
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () => context.pushNamed(AppRoute.paymentHistory),
            ),
          if (user != null)
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.goNamed(AppRoute.createEvent),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New event'),
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
            child: eventsAsync.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                message: error is AppException
                    ? error.message
                    : 'Could not load your events.',
                onRetry: () => ref.invalidate(myEventsProvider),
              ),
              data: (events) {
                if (events.isEmpty) {
                  return EmptyView(
                    icon: Icons.celebration_rounded,
                    title: user?.fullName?.isNotEmpty == true
                        ? 'Welcome, ${user!.fullName}!'
                        : 'No events yet',
                    subtitle:
                        'Create your first event and collect every photo from every guest with one QR code.',
                    actionLabel: 'Create event',
                    onAction: () => context.goNamed(AppRoute.createEvent),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    96, // clear the FAB
                  ),
                  itemCount: events.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return EventCard(
                      event: event,
                      onTap: () => context.goNamed(
                        AppRoute.eventDashboard,
                        pathParameters: {'eventId': event.id},
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
