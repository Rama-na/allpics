import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/event.dart';
import '../providers.dart';
import 'controllers/event_form_controller.dart';
import 'widgets/event_card.dart';
import 'widgets/qr_share_card.dart';
import 'widgets/stat_tile.dart';

/// Live host dashboard: counters, QR/share, expiry — updates in realtime.
class EventDashboardScreen extends ConsumerWidget {
  const EventDashboardScreen({super.key, required this.eventId});

  final String eventId;

  static String formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text(
          '"${event.title}" and all its photos will be removed. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok =
        await ref.read(eventFormControllerProvider.notifier).delete(event.id);
    if (ok && context.mounted) context.goNamed(AppRoute.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final eventAsync = ref.watch(eventProvider(eventId));

    ref.listen(eventFormControllerProvider, (_, next) {
      final error = next.error;
      if (error is AppException) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
      }
    });

    return eventAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.goNamed(AppRoute.home)),
        ),
        body: const LoadingView(),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.goNamed(AppRoute.home)),
        ),
        body: ErrorView(
          message: error is AppException
              ? error.message
              : 'Could not load this event.',
          onRetry: () => ref.invalidate(eventProvider(eventId)),
        ),
      ),
      data: (event) => Scaffold(
        appBar: AppBar(
          title: Text(event.title),
          leading: BackButton(onPressed: () => context.goNamed(AppRoute.home)),
          actions: [
            PopupMenuButton<String>(
              onSelected: (action) {
                switch (action) {
                  case 'edit':
                    context.goNamed(
                      AppRoute.editEvent,
                      pathParameters: {'eventId': event.id},
                      extra: event,
                    );
                  case 'delete':
                    _confirmDelete(context, ref, event);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit event'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded),
                    title: Text('Delete event'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(eventTypeIcon(event.type),
                            size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            [
                              event.type.label,
                              if (event.eventDate != null)
                                DateFormat.yMMMMd().format(event.eventDate!),
                              if (event.location.isNotEmpty) event.location,
                            ].join(' · '),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 1.9,
                      children: [
                        StatTile(
                          icon: Icons.people_outline_rounded,
                          label: 'Guests',
                          value: '${event.guestCount}',
                        ),
                        StatTile(
                          icon: Icons.photo_library_outlined,
                          label: 'Uploads used',
                          value: '${event.uploadsUsed}/${event.photoLimit}',
                          emphasize: event.isFull,
                        ),
                        StatTile(
                          icon: Icons.videocam_outlined,
                          label: 'Videos',
                          value: '${event.videoCount}',
                        ),
                        StatTile(
                          icon: Icons.cloud_outlined,
                          label: 'Storage used',
                          value: formatBytes(event.bytesUsed),
                        ),
                        StatTile(
                          icon: Icons.photo_outlined,
                          label: 'Uploads left',
                          value: '${event.uploadsRemaining}',
                          emphasize: event.uploadsRemaining == 0,
                        ),
                        StatTile(
                          icon: Icons.schedule_rounded,
                          label: 'Days until expiry',
                          value: '${event.daysUntilExpiry}',
                          emphasize: event.daysUntilExpiry <= 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: () => context.pushNamed(
                        AppRoute.album,
                        pathParameters: {'eventId': event.id},
                      ),
                      icon: const Icon(Icons.photo_library_rounded, size: 18),
                      label: const Text('View album'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () => context.pushNamed(
                        AppRoute.plans,
                        pathParameters: {'eventId': event.id},
                      ),
                      icon: const Icon(Icons.workspace_premium_rounded,
                          size: 18),
                      label: const Text('Upgrade plan'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    QrShareCard(event: event),
                    if (event.description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('About',
                                  style: theme.textTheme.titleMedium),
                              const SizedBox(height: AppSpacing.sm),
                              Text(event.description,
                                  style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
