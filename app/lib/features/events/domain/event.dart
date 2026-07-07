/// Event types supported by AllPics (mirrors the `event_type` enum).
enum EventType {
  wedding('wedding', 'Wedding'),
  birthday('birthday', 'Birthday'),
  party('party', 'Party'),
  trip('trip', 'Trip'),
  corporate('corporate', 'Corporate'),
  babyShower('baby_shower', 'Baby Shower'),
  custom('custom', 'Custom');

  const EventType(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static EventType fromDb(String? value) => EventType.values.firstWhere(
        (t) => t.dbValue == value,
        orElse: () => EventType.custom,
      );
}

/// Event lifecycle (mirrors the `event_status` enum).
enum EventStatus {
  active('active'),
  expired('expired'),
  deleted('deleted');

  const EventStatus(this.dbValue);

  final String dbValue;

  static EventStatus fromDb(String? value) => EventStatus.values.firstWhere(
        (s) => s.dbValue == value,
        orElse: () => EventStatus.active,
      );
}

/// A host's event album (full `events` row).
class Event {
  const Event({
    required this.id,
    required this.hostId,
    required this.type,
    required this.status,
    required this.title,
    required this.description,
    required this.location,
    required this.eventCode,
    required this.shareSlug,
    required this.photoLimit,
    required this.expiresAt,
    required this.guestCount,
    required this.photoCount,
    required this.videoCount,
    required this.bytesUsed,
    required this.createdAt,
    this.eventDate,
    this.coverPath,
  });

  final String id;
  final String hostId;
  final EventType type;
  final EventStatus status;
  final String title;
  final String description;
  final DateTime? eventDate;
  final String location;
  final String? coverPath;
  final String eventCode;
  final String shareSlug;
  final int photoLimit;
  final DateTime expiresAt;
  final int guestCount;
  final int photoCount;
  final int videoCount;
  final int bytesUsed;
  final DateTime createdAt;

  int get uploadsUsed => photoCount + videoCount;
  int get uploadsRemaining =>
      (photoLimit - uploadsUsed).clamp(0, photoLimit);
  bool get isFull => uploadsUsed >= photoLimit;

  int get daysUntilExpiry {
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inDays;
  }

  bool get isActive => status == EventStatus.active;

  /// Share link that guests open (routes to the join deep link).
  String shareLink(String baseUrl) => '$baseUrl/j/$shareSlug';

  factory Event.fromMap(Map<String, dynamic> map) => Event(
        id: map['id'] as String,
        hostId: map['host_id'] as String,
        type: EventType.fromDb(map['type'] as String?),
        status: EventStatus.fromDb(map['status'] as String?),
        title: map['title'] as String,
        description: (map['description'] as String?) ?? '',
        eventDate: map['event_date'] == null
            ? null
            : DateTime.tryParse(map['event_date'] as String),
        location: (map['location'] as String?) ?? '',
        coverPath: map['cover_url'] as String?,
        eventCode: map['event_code'] as String,
        shareSlug: map['share_slug'] as String,
        photoLimit: (map['photo_limit'] as num).toInt(),
        expiresAt: DateTime.parse(map['expires_at'] as String),
        guestCount: (map['guest_count'] as num?)?.toInt() ?? 0,
        photoCount: (map['photo_count'] as num?)?.toInt() ?? 0,
        videoCount: (map['video_count'] as num?)?.toInt() ?? 0,
        bytesUsed: (map['bytes_used'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

/// Input for creating or editing an event.
class EventDraft {
  const EventDraft({
    required this.type,
    required this.title,
    this.description = '',
    this.eventDate,
    this.location = '',
  });

  final EventType type;
  final String title;
  final String description;
  final DateTime? eventDate;
  final String location;
}
