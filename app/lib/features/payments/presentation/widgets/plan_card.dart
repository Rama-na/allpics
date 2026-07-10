import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/payment_models.dart';
import '../../domain/plan_presentation.dart';

/// Merchandised plan card: popular ribbon, feature bullets, value framing.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
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
    final highlight = plan.isPopular && !isCurrent;

    return Semantics(
      label: '${plan.name} plan, ${plan.priceLabel}'
          '${plan.isPopular ? ', most popular' : ''}'
          '${isCurrent ? ', current plan' : ''}',
      child: Card(
        elevation: highlight ? 3 : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: isCurrent || highlight
              ? BorderSide(
                  color: theme.colorScheme.primary,
                  width: highlight ? 2 : 1.5,
                )
              : BorderSide.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (highlight)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.radiusLg),
                  ),
                ),
                child: Text(
                  'MOST POPULAR',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(plan.name,
                                style: theme.textTheme.titleLarge),
                            if (plan.tagline.isNotEmpty)
                              Text(
                                plan.tagline,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(plan.priceLabel,
                              style: theme.textTheme.headlineSmall),
                          if (plan.perUploadLabel.isNotEmpty)
                            Text(
                              plan.perUploadLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...plan.bullets.map(
                    (bullet) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        children: [
                          Icon(Icons.check_rounded,
                              size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(bullet,
                                style: theme.textTheme.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
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
                      variant: highlight
                          ? AppButtonVariant.primary
                          : AppButtonVariant.secondary,
                      onPressed: onBuy,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
