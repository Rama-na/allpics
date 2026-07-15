import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../domain/event.dart';
import '../../providers.dart';

/// Icon per event type, shared by cards and dashboards.
IconData eventTypeIcon(EventType type) => switch (type) {
      EventType.wedding => Icons.favorite_rounded,
      EventType.birthday => Icons.cake_rounded,
      EventType.party => Icons.celebration_rounded,
      EventType.trip => Icons.flight_takeoff_rounded,
      EventType.corporate => Icons.business_center_rounded,
      EventType.babyShower => Icons.child_friendly_rounded,
      EventType.custom => Icons.event_rounded,
    };

/// Event summary card on the host home screen.
class EventCard extends ConsumerWidget {
  const EventCard({super.key, required this.event, this.onTap});

  final Event event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final coverPath = event.coverPath;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (coverPath != null)
              SizedBox(
                height: 140,
                child: ref.watch(coverUrlProvider(coverPath)).when(
                      data: (url) => Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _CoverFallback(type: event.type),
                      ),
                      loading: () => _CoverFallback(type: event.type),
                      error: (_, _) => _CoverFallback(type: event.type),
                    ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(eventTypeIcon(event.type),
                          size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        // Flies into the dashboard app-bar title.
                        child: Hero(
                          tag: 'event-title-${event.id}',
                          child: Material(
                            type: MaterialType.transparency,
                            child: Text(
                              event.title,
                              style: theme.textTheme.titleLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      if (!event.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                          child: Text('Expired',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                              )),
                        ),
                    ],
                  ),
                  if (event.eventDate != null || event.location.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      [
                        if (event.eventDate != null)
                          DateFormat.yMMMd().format(event.eventDate!),
                        if (event.location.isNotEmpty) event.location,
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      AppChip(
                        icon: Icons.people_outline_rounded,
                        label: '${event.guestCount}',
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppChip(
                        icon: Icons.photo_library_outlined,
                        label: '${event.uploadsUsed}/${event.photoLimit}',
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppChip(
                        icon: Icons.schedule_rounded,
                        label: '${event.daysUntilExpiry}d left',
                      ),
                    ],
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

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.type});

  final EventType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: Icon(eventTypeIcon(type),
          size: 48, color: theme.colorScheme.primary),
    );
  }
}
