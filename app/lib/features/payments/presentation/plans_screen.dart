import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/providers.dart';
import '../../events/providers.dart';
import '../providers.dart';
import 'controllers/checkout_controller.dart';
import 'widgets/plan_card.dart';

/// Plan picker + Razorpay checkout for one event.
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final plansAsync = ref.watch(plansProvider);
    final eventAsync = ref.watch(eventProvider(eventId));
    final checkout = ref.watch(checkoutControllerProvider);

    ref.listen(checkoutControllerProvider, (_, next) {
      if (next is CheckoutFailure) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.message)));
        ref.read(checkoutControllerProvider.notifier).reset();
      }
    });

    if (checkout is CheckoutSuccess) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Payment received!',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your ${checkout.planName} plan is being applied — the new '
                  'photo limit shows on the dashboard within moments.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Back to dashboard',
                  onPressed: () {
                    ref.read(checkoutControllerProvider.notifier).reset();
                    context.goNamed(
                      AppRoute.eventDashboard,
                      pathParameters: {'eventId': eventId},
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade plan')),
      body: plansAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error is AppException
              ? error.message
              : 'Could not load plans.',
          onRetry: () => ref.invalidate(plansProvider),
        ),
        data: (plans) {
          final event = eventAsync.value;
          final currentLimit = event?.photoLimit ?? 0;
          final sorted = [...plans]
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (event != null) ...[
                _UsageHero(
                  title: event.title,
                  used: event.uploadsUsed,
                  limit: event.photoLimit,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(
                'Guests always upload free. The upload limit applies to the '
                'whole event and upgrades apply instantly after payment.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ...sorted.map((plan) {
                final isCurrent = plan.photoLimit == currentLimit;
                final isProcessing =
                    checkout is CheckoutProcessing &&
                    checkout.planCode == plan.code;
                // The free tier is where every event starts — keep it out of
                // the way unless it is the current plan.
                if (plan.isFree && !isCurrent) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: PlanCard(
                    plan: plan,
                    isCurrent: isCurrent,
                    isProcessing: isProcessing,
                    onBuy: plan.isFree || isCurrent
                        ? null
                        : () => ref
                              .read(checkoutControllerProvider.notifier)
                              .purchase(
                                eventId: eventId,
                                planCode: plan.code,
                                prefillEmail: ref
                                    .read(currentUserProvider)
                                    ?.email,
                              ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

/// Live usage meter so the host sees exactly why an upgrade helps.
class _UsageHero extends StatelessWidget {
  const _UsageHero({
    required this.title,
    required this.used,
    required this.limit,
  });

  final String title;
  final int used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final isFull = limit > 0 && used >= limit;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
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
            const SizedBox(height: AppSpacing.sm),
            Text(
              isFull
                  ? '$used of $limit uploads used — the album is full'
                  : '$used of $limit uploads used',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isFull
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
