import 'app_notification.dart';

/// Notification center + push token contract.
abstract interface class NotificationsRepository {
  /// Live notifications for the signed-in user, newest first.
  Stream<List<AppNotification>> watchNotifications();

  Future<void> markRead(String notificationId);

  Future<void> markAllRead();

  Future<void> delete(String notificationId);

  /// Stores the device push token on the user's profile.
  Future<void> registerPushToken(String token);
}

/// Platform push abstraction. The default implementation is a no-op until
/// Firebase is provisioned; `FirebasePushGateway` (firebase_messaging) plugs
/// in behind this interface without touching any feature code.
abstract interface class PushGateway {
  /// Asks for permission and returns the device token, or null when push is
  /// unavailable (no Firebase config, permission denied, unsupported).
  Future<String?> obtainToken();

  /// Emits refreshed tokens over the app lifetime.
  Stream<String> get onTokenRefresh;
}

class NoopPushGateway implements PushGateway {
  const NoopPushGateway();

  @override
  Future<String?> obtainToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
}
