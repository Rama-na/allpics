import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_env.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/app_logger.dart';
import '../auth/providers.dart';
import 'data/supabase_notifications_repository.dart';
import 'domain/app_notification.dart';
import 'domain/notifications_repository.dart';

/// Pre-provisioning fallback.
class _UnconfiguredNotificationsRepository implements NotificationsRepository {
  const _UnconfiguredNotificationsRepository();

  static const _error = UnexpectedException(
    cause: 'Backend not configured — see docs/DEPLOYMENT.md',
  );

  @override
  Stream<List<AppNotification>> watchNotifications() =>
      Stream.value(const []);

  @override
  Future<void> markRead(String notificationId) async => throw _error;

  @override
  Future<void> markAllRead() async => throw _error;

  @override
  Future<void> delete(String notificationId) async => throw _error;

  @override
  Future<void> registerPushToken(String token) async => throw _error;
}

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  if (!AppEnv.isSupabaseConfigured) {
    return const _UnconfiguredNotificationsRepository();
  }
  return SupabaseNotificationsRepository(ref.watch(supabaseClientProvider));
});

/// Swapped for `FirebasePushGateway` once google-services config is added.
final pushGatewayProvider = Provider<PushGateway>((ref) {
  return const NoopPushGateway();
});

/// Live notification list for the signed-in host.
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isHost) return Stream.value(const []);
  return ref.watch(notificationsRepositoryProvider).watchNotifications();
});

final unreadCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).value ?? const [];
  return notifications.where((n) => !n.isRead).length;
});

/// Registers the device push token for the signed-in host. Safe to call
/// unconditionally: no-ops without Firebase or without a session.
final pushRegistrationProvider = Provider<void>((ref) {
  final log = AppLogger.get('push');
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isHost) return;

  final gateway = ref.watch(pushGatewayProvider);
  final repo = ref.watch(notificationsRepositoryProvider);

  Future(() async {
    try {
      final token = await gateway.obtainToken();
      if (token != null) await repo.registerPushToken(token);
    } on AppException catch (e) {
      log.warning('push registration failed: ${e.message}');
    }
  });

  final sub = gateway.onTokenRefresh.listen((token) async {
    try {
      await repo.registerPushToken(token);
    } on AppException catch (e) {
      log.warning('token refresh failed: ${e.message}');
    }
  });
  ref.onDispose(sub.cancel);
});
