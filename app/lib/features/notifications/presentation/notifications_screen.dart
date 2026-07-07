import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/app_notification.dart';
import '../providers.dart';

/// In-app notification center for hosts.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _icon(AppNotificationType type) => switch (type) {
        AppNotificationType.guestJoined => Icons.person_add_alt_1_rounded,
        AppNotificationType.newUploads => Icons.add_photo_alternate_rounded,
        AppNotificationType.albumExpiring => Icons.schedule_rounded,
        AppNotificationType.storageLow => Icons.data_usage_rounded,
        AppNotificationType.paymentSuccess => Icons.verified_rounded,
        AppNotificationType.system => Icons.info_outline_rounded,
      };

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    try {
      if (!notification.isRead) {
        await ref
            .read(notificationsRepositoryProvider)
            .markRead(notification.id);
      }
    } on AppException {
      // Read-state is cosmetic; navigation still proceeds.
    }
    final eventId = notification.eventId;
    if (eventId != null && context.mounted) {
      context.pushNamed(
        AppRoute.eventDashboard,
        pathParameters: {'eventId': eventId},
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notificationsAsync = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () async {
                try {
                  await ref
                      .read(notificationsRepositoryProvider)
                      .markAllRead();
                } on AppException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(e.message)));
                  }
                }
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error is AppException
              ? error.message
              : 'Could not load notifications.',
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const EmptyView(
              icon: Icons.notifications_none_rounded,
              title: 'All caught up',
              subtitle:
                  'Guest joins, new uploads, expiry reminders and payment '
                  'confirmations show up here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Dismissible(
                key: ValueKey(notification.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: Icon(Icons.delete_outline_rounded,
                      color: theme.colorScheme.onErrorContainer),
                ),
                onDismissed: (_) => ref
                    .read(notificationsRepositoryProvider)
                    .delete(notification.id),
                child: Card(
                  color: notification.isRead
                      ? null
                      : theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.25),
                  child: ListTile(
                    leading: Icon(
                      _icon(notification.type),
                      color: notification.isRead
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.primary,
                    ),
                    title: Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight: notification.isRead
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${notification.body}\n'
                      '${DateFormat.yMMMd().add_jm().format(notification.createdAt)}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    onTap: () => _open(context, ref, notification),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
