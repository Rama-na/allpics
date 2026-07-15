import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/shimmer.dart';
import '../../../../shared/widgets/staggered_entrance.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/providers.dart';
import '../../../events/domain/my_event.dart';
import '../../../events/presentation/widgets/event_card.dart';
import '../../providers.dart';

/// Shell page 0: every event the user hosts or joined, past and present.
class MyEventsPage extends ConsumerWidget {
  const MyEventsPage({super.key});

  void _open(BuildContext context, MyEvent item) {
    if (item.isHost) {
      context.pushNamed(
        AppRoute.eventDashboard,
        pathParameters: {'eventId': item.event.id},
      );
    } else {
      context.pushNamed(
        AppRoute.guestEvent,
        pathParameters: {'eventId': item.event.id},
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final eventsAsync = ref.watch(myEventsShellProvider);
    final user = ref.watch(currentUserProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            // Clears the shell's floating top overlay.
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 72, AppSpacing.md, AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child:
                      Text('My events', style: theme.textTheme.headlineSmall),
                ),
                FilledButton.tonalIcon(
                  // The app theme defaults buttons to full width; this one
                  // shares a Row with the title.
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: () => context.pushNamed(AppRoute.createEvent),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create'),
                ),
              ],
            ),
          ),
          if (!AppEnv.isSupabaseConfigured)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Text(
                'Backend not configured. Run with '
                '--dart-define-from-file=env/dev.json after provisioning '
                'Supabase (see docs/DEPLOYMENT.md).',
                style: theme.textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: eventsAsync.when(
                loading: () => const SkeletonEventList(),
                error: (error, _) => ErrorView(
                  message: error is AppException
                      ? error.message
                      : 'Could not load your events.',
                  onRetry: () => ref.invalidate(myEventsShellProvider),
                ),
                data: (events) {
                  if (events.isEmpty) {
                    return _EmptyEvents(signedIn: user != null && user.isHost);
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(myEventsShellProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        120, // clear the shell bottom bar
                      ),
                      itemCount: events.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final item = events[index];
                        return StaggeredEntrance(
                          index: index,
                          child: _MyEventTile(
                            item: item,
                            onTap: () => _open(context, item),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// EventCard with role (Host/Guest) and status (Live/Ended) chips overlaid.
class _MyEventTile extends StatelessWidget {
  const _MyEventTile({required this.item, required this.onTap});

  final MyEvent item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        EventCard(event: item.event, onTap: onTap),
        Positioned(
          top: AppSpacing.sm,
          right: AppSpacing.sm,
          child: Row(
            children: [
              AppChip(
                label: item.isHost ? 'Host' : 'Guest',
                background: theme.colorScheme.secondaryContainer,
                foreground: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: AppSpacing.xs),
              AppChip(
                label: item.isLive ? 'Live' : 'Ended',
                background: item.isLive
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                foreground: item.isLive
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ],
    );
  }

}

class _EmptyEvents extends ConsumerWidget {
  const _EmptyEvents({required this.signedIn});

  final bool signedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 120), // clear the bottom bar
      children: [
        EmptyView(
          icon: Icons.celebration_rounded,
          title: 'No events yet',
          subtitle:
              'Create your own event — free — or join one with a code. '
              'Every photo and video lands in one shared album.',
          actionLabel: 'Create an event — free',
          onAction: () => context.pushNamed(AppRoute.createEvent),
        ),
        if (!signedIn)
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Already hosting?'),
              TextButton(
                onPressed: () => context.pushNamed(AppRoute.signIn),
                child: const Text('Sign in'),
              ),
            ],
          ),
      ],
    );
  }
}
