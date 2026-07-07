/// A media item visible in an event album (an `uploads` row joined with the
/// uploader's name).
class AlbumItem {
  const AlbumItem({
    required this.id,
    required this.eventId,
    required this.guestId,
    required this.guestName,
    required this.isVideo,
    required this.storagePath,
    required this.createdAt,
    this.thumbPath,
    this.caption = '',
    this.isReady = true,
  });

  final String id;
  final String eventId;
  final String guestId;
  final String guestName;
  final bool isVideo;

  /// Full path including bucket prefix, e.g. `media/{event}/{upload}.jpg`.
  final String storagePath;

  /// Worker-generated thumbnail (Phase 8); null until processed.
  final String? thumbPath;

  final String caption;
  final DateTime createdAt;

  /// False while still processing server-side.
  final bool isReady;

  /// Path used for grid previews (thumb when available).
  String get previewPath => thumbPath ?? storagePath;

  static AlbumItem fromMap(
    Map<String, dynamic> map, {
    required String guestName,
  }) =>
      AlbumItem(
        id: map['id'] as String,
        eventId: map['event_id'] as String,
        guestId: map['guest_id'] as String,
        guestName: guestName,
        isVideo: map['media_type'] == 'video',
        storagePath: map['storage_path'] as String,
        thumbPath: map['thumb_path'] as String?,
        caption: (map['caption'] as String?) ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
        isReady: map['status'] == 'ready' || map['status'] == 'uploaded',
      );
}

/// Album sort orders.
enum AlbumSort {
  newest('Newest'),
  oldest('Oldest'),
  byGuest('By guest');

  const AlbumSort(this.label);

  final String label;
}

/// Album media filters.
enum AlbumFilter {
  all('All'),
  photos('Photos'),
  videos('Videos'),
  favorites('Favourites');

  const AlbumFilter(this.label);

  final String label;
}
