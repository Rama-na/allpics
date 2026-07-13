import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/state_views.dart';
import '../../events/domain/event.dart';
import '../../uploads/presentation/widgets/upload_panel.dart';
import '../domain/joinable_event.dart';
import '../providers.dart';
import 'controllers/join_flow_controller.dart';
import 'widgets/event_preview_card.dart';

/// Guest landing after joining: event details + the upload experience.
/// Reachable straight from the join flow (in-memory state) or via My Events
/// / app restart, where it rehydrates from the backend.
class GuestEventScreen extends ConsumerWidget {
  const GuestEventScreen({super.key, required this.eventId});

  final String eventId;

  JoinableEvent _joinableFromEvent(Event event) => JoinableEvent(
    id: event.id,
    title: event.title,
    description: event.description,
    type: event.type.dbValue,
    eventDate: event.eventDate,
    location: event.location,
    photoCount: event.photoCount,
    videoCount: event.videoCount,
    photoLimit: event.photoLimit,
    isFull: event.isFull,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(joinFlowControllerProvider);

    // Fresh join: use the in-memory flow state directly.
    if (state is Joined && state.event.id == eventId) {
      return _GuestEventView(
        event: state.event,
        guestName: state.guest.name,
        welcome: true,
      );
    }

    // My Events / app restart: rehydrate from the backend.
    final hydration = ref.watch(guestEventHydrationProvider(eventId));
    return hydration.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Event')),
        body: const LoadingView(),
      ),
      error: (_, _) => _rejoinFallback(context, ref),
      data: (record) {
        final (event, membership) = record;
        if (membership == null) return _rejoinFallback(context, ref);
        return _GuestEventView(
          event: _joinableFromEvent(event),
          guestName: membership.name,
          welcome: false,
        );
      },
    );
  }

  Widget _rejoinFallback(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event')),
      body: ErrorView(
        icon: Icons.qr_code_rounded,
        message: 'Let\'s find your event again — enter its code.',
        onRetry: () {
          ref.read(joinFlowControllerProvider.notifier).reset();
          context.goNamed(AppRoute.join);
        },
      ),
    );
  }
}

class _GuestEventView extends ConsumerWidget {
  const _GuestEventView({
    required this.event,
    required this.guestName,
    required this.welcome,
  });

  final JoinableEvent event;
  final String guestName;

  /// Fresh joins get the celebratory banner; returning visits a calmer one.
  final bool welcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(event.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            welcome
                                ? 'You\'re in, $guestName! Add your photos below.'
                                : 'Welcome back, $guestName! Keep the photos coming.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  EventPreviewCard(event: event),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () => context.pushNamed(
                      AppRoute.album,
                      pathParameters: {'eventId': event.id},
                    ),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('View album'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  UploadPanel(eventId: event.id, isFull: event.isFull),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
