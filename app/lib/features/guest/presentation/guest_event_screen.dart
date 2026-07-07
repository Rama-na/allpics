import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/state_views.dart';
import '../../uploads/presentation/widgets/upload_panel.dart';
import 'controllers/join_flow_controller.dart';
import 'widgets/event_preview_card.dart';

/// Guest landing after joining: event details + the upload experience.
class GuestEventScreen extends ConsumerWidget {
  const GuestEventScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(joinFlowControllerProvider);

    if (state is! Joined || state.event.id != eventId) {
      // Direct navigation without flow state (e.g. app restart): send the
      // guest back through the code flow, which restores membership.
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

    return Scaffold(
      appBar: AppBar(title: Text(state.event.title)),
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
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'You\'re in, ${state.guest.name}! Add your photos below.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  EventPreviewCard(event: state.event),
                  const SizedBox(height: AppSpacing.lg),
                  UploadPanel(
                    eventId: state.event.id,
                    isFull: state.event.isFull,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
