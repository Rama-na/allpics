import 'dart:typed_data';

import 'album_item.dart';

/// Album read/interaction contract (host + guest).
abstract interface class AlbumRepository {
  /// Live list of visible album items for an event (uploaded/ready only),
  /// with uploader names resolved.
  Stream<List<AlbumItem>> watchAlbum(String eventId);

  /// Live set of the current user's favorited upload ids.
  Stream<Set<String>> watchFavoriteIds();

  Future<void> setFavorite(String uploadId, bool favorite);

  /// Short-lived signed URL for displaying a storage path.
  Future<String> signedMediaUrl(String path);

  /// Downloads the full bytes of an item (for save/share).
  Future<Uint8List> downloadBytes(String path);
}
