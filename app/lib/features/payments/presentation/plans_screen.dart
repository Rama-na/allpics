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
import '../domain/payment_models.dart';
import '../providers.dart';
import 'controllers/checkout_controller.dart';

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
                Icon(Icons.check_circle_rounded,
                    size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: AppSpacing.lg),
                Text('Payment received!',
                    style: theme.textTheme.headlineMedium),
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
          final currentLimit = eventAsync.value?.photoLimit ?? 0;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                'Guests always upload free. The photo limit applies to the '
                'whole event and upgrades apply instantly after payment.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ...plans.map((plan) {
                final isCurrent = plan.photoLimit == currentLimit;
                final isProcessing = checkout is CheckoutProcessing &&
                    checkout.planCode == plan.code;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _PlanCard(
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
                              prefillEmail:
                                  ref.read(currentUserProvider)?.email,
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.isProcessing,
    this.onBuy,
  });

  final Plan plan;
  final bool isCurrent;
  final bool isProcessing;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: isCurrent
            ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(plan.name, style: theme.textTheme.titleLarge),
                ),
                Text(plan.priceLabel, style: theme.textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.photo_library_outlined,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('${plan.photoLimit} uploads',
                    style: theme.textTheme.bodyMedium),
                const SizedBox(width: AppSpacing.md),
                Icon(Icons.schedule_rounded,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('${plan.storageLabel} storage',
                    style: theme.textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (isCurrent)
              Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Current plan',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              )
            else if (!plan.isFree)
              AppButton(
                label: 'Get ${plan.name}',
                isLoading: isProcessing,
                onPressed: onBuy,
              ),
          ],
        ),
      ),
    );
  }
}
