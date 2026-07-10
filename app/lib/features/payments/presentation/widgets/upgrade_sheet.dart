import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../events/domain/event.dart';
import '../../domain/plan_presentation.dart';
import '../../providers.dart';

/// Session-scoped set of event ids whose upgrade nudge already fired, so the
/// sheet appears at most once per event per app session.
class UpgradeNudgeShown extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void mark(String eventId) => state = {...state, eventId};
}

final upgradeNudgeShownProvider =
    NotifierProvider<UpgradeNudgeShown, Set<String>>(UpgradeNudgeShown.new);

/// Whether [event] is close enough to its limit to warrant a nudge.
bool isNearQuota(Event event) =>
    event.photoLimit > 0 && event.uploadsUsed >= 0.8 * event.photoLimit;

/// Contextual upgrade moment: shown to hosts when the album is (nearly) full.
Future<void> showUpgradeSheet(BuildContext context, Event event) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => _UpgradeSheetBody(event: event),
  );
}

class _UpgradeSheetBody extends ConsumerWidget {
  const _UpgradeSheetBody({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isFull = event.isFull;
    final ratio = event.photoLimit > 0
        ? (event.uploadsUsed / event.photoLimit).clamp(0.0, 1.0)
        : 0.0;

    // Smallest plan that actually adds headroom.
    final plans = ref.watch(plansProvider).value ?? const [];
    final upgrades = plans
        .where((p) => !p.isFree && p.photoLimit > event.photoLimit)
        .toList()
      ..sort((a, b) => a.photoLimit.compareTo(b.photoLimit));
    final recommended = upgrades.firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isFull
                ? 'Your album is full'
                : 'Your album is ${(ratio * 100).round()}% full',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isFull
                ? 'Guests can\'t add more memories to "${event.title}". '
                    'Upgrade to reopen uploads instantly.'
                : 'Only ${event.uploadsRemaining} uploads left for '
                    '"${event.title}". Upgrade before the moment passes.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: isFull
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
          ),
          if (recommended != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${recommended.name} — ${recommended.photoLimit} uploads, '
                      '${recommended.storageLabel}, ${recommended.priceLabel}'
                      '${recommended.perUploadLabel.isEmpty ? '' : ' (${recommended.perUploadLabel})'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'See upgrade options',
            icon: Icons.workspace_premium_rounded,
            onPressed: () {
              Navigator.of(context).pop();
              context.pushNamed(
                AppRoute.plans,
                pathParameters: {'eventId': event.id},
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Not now',
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
