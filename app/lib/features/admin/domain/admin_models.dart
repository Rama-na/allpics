/// Admin panel models (RPC row shapes).
class AdminStats {
  const AdminStats({
    required this.hosts,
    required this.eventsTotal,
    required this.eventsActive,
    required this.guests,
    required this.uploads,
    required this.storageBytes,
    required this.revenuePaise,
    required this.paymentsCaptured,
    required this.jobsQueued,
    required this.jobsFailed,
  });

  final int hosts;
  final int eventsTotal;
  final int eventsActive;
  final int guests;
  final int uploads;
  final int storageBytes;
  final int revenuePaise;
  final int paymentsCaptured;
  final int jobsQueued;
  final int jobsFailed;

  String get revenueLabel => '₹${(revenuePaise / 100).toStringAsFixed(0)}';

  String get storageLabel {
    if (storageBytes < 1024 * 1024 * 1024) {
      return '${(storageBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(storageBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  factory AdminStats.fromMap(Map<String, dynamic> map) => AdminStats(
        hosts: (map['hosts'] as num?)?.toInt() ?? 0,
        eventsTotal: (map['events_total'] as num?)?.toInt() ?? 0,
        eventsActive: (map['events_active'] as num?)?.toInt() ?? 0,
        guests: (map['guests'] as num?)?.toInt() ?? 0,
        uploads: (map['uploads'] as num?)?.toInt() ?? 0,
        storageBytes: (map['storage_bytes'] as num?)?.toInt() ?? 0,
        revenuePaise: (map['revenue_paise'] as num?)?.toInt() ?? 0,
        paymentsCaptured: (map['payments_captured'] as num?)?.toInt() ?? 0,
        jobsQueued: (map['jobs_queued'] as num?)?.toInt() ?? 0,
        jobsFailed: (map['jobs_failed'] as num?)?.toInt() ?? 0,
      );
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isBanned,
    required this.eventCount,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String role;
  final bool isBanned;
  final int eventCount;
  final DateTime createdAt;

  bool get isAdmin => role == 'admin';

  factory AdminUser.fromMap(Map<String, dynamic> map) => AdminUser(
        id: map['id'] as String,
        fullName: (map['full_name'] as String?) ?? '',
        email: (map['email'] as String?) ?? '',
        role: (map['role'] as String?) ?? 'host',
        isBanned: (map['is_banned'] as bool?) ?? false,
        eventCount: (map['event_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class AdminEvent {
  const AdminEvent({
    required this.id,
    required this.title,
    required this.hostName,
    required this.status,
    required this.uploadsUsed,
    required this.photoLimit,
    required this.guestCount,
    required this.bytesUsed,
    required this.expiresAt,
  });

  final String id;
  final String title;
  final String hostName;
  final String status;
  final int uploadsUsed;
  final int photoLimit;
  final int guestCount;
  final int bytesUsed;
  final DateTime expiresAt;

  factory AdminEvent.fromMap(Map<String, dynamic> map) => AdminEvent(
        id: map['id'] as String,
        title: map['title'] as String,
        hostName: (map['host_name'] as String?) ?? '',
        status: (map['status'] as String?) ?? 'active',
        uploadsUsed: ((map['photo_count'] as num?)?.toInt() ?? 0) +
            ((map['video_count'] as num?)?.toInt() ?? 0),
        photoLimit: (map['photo_limit'] as num?)?.toInt() ?? 0,
        guestCount: (map['guest_count'] as num?)?.toInt() ?? 0,
        bytesUsed: (map['bytes_used'] as num?)?.toInt() ?? 0,
        expiresAt: DateTime.parse(map['expires_at'] as String),
      );
}

class FeatureFlag {
  const FeatureFlag({required this.key, required this.enabled});

  final String key;
  final bool enabled;

  factory FeatureFlag.fromMap(Map<String, dynamic> map) => FeatureFlag(
        key: map['key'] as String,
        enabled: (map['enabled'] as bool?) ?? false,
      );
}
