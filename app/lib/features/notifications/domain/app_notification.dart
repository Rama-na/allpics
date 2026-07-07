/// Notification categories (mirrors the `notification_type` enum).
enum AppNotificationType {
  guestJoined('guest_joined'),
  newUploads('new_uploads'),
  albumExpiring('album_expiring'),
  storageLow('storage_low'),
  paymentSuccess('payment_success'),
  system('system');

  const AppNotificationType(this.dbValue);

  final String dbValue;

  static AppNotificationType fromDb(String? value) =>
      AppNotificationType.values.firstWhere(
        (t) => t.dbValue == value,
        orElse: () => AppNotificationType.system,
      );
}

/// An in-app notification (a `notifications` row).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.data = const {},
    this.readAt,
  });

  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  /// Deep-link target when the notification concerns an event.
  String? get eventId => data['event_id'] as String?;

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        id: map['id'] as String,
        type: AppNotificationType.fromDb(map['type'] as String?),
        title: map['title'] as String,
        body: (map['body'] as String?) ?? '',
        data: (map['data'] as Map<String, dynamic>?) ?? const {},
        createdAt: DateTime.parse(map['created_at'] as String),
        readAt: map['read_at'] == null
            ? null
            : DateTime.tryParse(map['read_at'] as String),
      );
}
