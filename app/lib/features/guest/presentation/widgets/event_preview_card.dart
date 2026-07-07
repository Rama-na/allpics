import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/joinable_event.dart';

/// Compact event summary shown before joining and on the guest event screen.
class EventPreviewCard extends StatelessWidget {
  const EventPreviewCard({super.key, required this.event});

  final JoinableEvent event;

  static const _typeIcons = <String, IconData>{
    'wedding': Icons.favorite_rounded,
    'birthday': Icons.cake_rounded,
    'party': Icons.celebration_rounded,
    'trip': Icons.flight_takeoff_rounded,
    'corporate': Icons.business_center_rounded,
    'baby_shower': Icons.child_friendly_rounded,
    'custom': Icons.event_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = event.eventDate;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color:
                        theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(
                    _typeIcons[event.type] ?? Icons.event_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title, style: theme.textTheme.titleLarge),
                      if (date != null || event.location.isNotEmpty)
                        Text(
                          [
                            if (date != null)
                              DateFormat.yMMMMd().format(date),
                            if (event.location.isNotEmpty) event.location,
                          ].join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                event.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.photo_library_outlined,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  '${event.uploadsUsed} / ${event.photoLimit} uploads used',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: event.isFull
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
