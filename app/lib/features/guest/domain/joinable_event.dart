/// Public event preview returned by the pre-join lookup
/// (`get_event_for_join` RPC — safe fields only).
class JoinableEvent {
  const JoinableEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.location,
    required this.photoCount,
    required this.videoCount,
    required this.photoLimit,
    required this.isFull,
    this.eventDate,
    this.coverUrl,
  });

  final String id;
  final String title;
  final String description;
  final String type;
  final DateTime? eventDate;
  final String location;
  final String? coverUrl;
  final int photoCount;
  final int videoCount;
  final int photoLimit;
  final bool isFull;

  int get uploadsUsed => photoCount + videoCount;

  factory JoinableEvent.fromMap(Map<String, dynamic> map) => JoinableEvent(
        id: map['id'] as String,
        title: map['title'] as String,
        description: (map['description'] as String?) ?? '',
        type: (map['type'] as String?) ?? 'custom',
        eventDate: map['event_date'] == null
            ? null
            : DateTime.tryParse(map['event_date'] as String),
        location: (map['location'] as String?) ?? '',
        coverUrl: map['cover_url'] as String?,
        photoCount: (map['photo_count'] as num?)?.toInt() ?? 0,
        videoCount: (map['video_count'] as num?)?.toInt() ?? 0,
        photoLimit: (map['photo_limit'] as num?)?.toInt() ?? 0,
        isFull: (map['is_full'] as bool?) ?? false,
      );
}

/// A guest's membership in an event.
class EventGuest {
  const EventGuest({
    required this.id,
    required this.eventId,
    required this.name,
    this.phone,
  });

  final String id;
  final String eventId;
  final String name;
  final String? phone;

  factory EventGuest.fromMap(Map<String, dynamic> map) => EventGuest(
        id: map['id'] as String,
        eventId: map['event_id'] as String,
        name: map['name'] as String,
        phone: map['phone'] as String?,
      );
}
