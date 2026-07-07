import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/album_item.dart';
import '../domain/album_repository.dart';

/// Production [AlbumRepository]: realtime uploads stream + guest-name join,
/// favorites stream, signed URLs, and byte downloads.
class SupabaseAlbumRepository implements AlbumRepository {
  SupabaseAlbumRepository(this._client);

  final sb.SupabaseClient _client;
  static final _log = AppLogger.get('album');

  /// Guest names per event, cached; invalidated when unknown ids appear.
  final _guestNames = <String, Map<String, String>>{};

  Future<Map<String, String>> _namesFor(
      String eventId, Iterable<String> guestIds) async {
    final cached = _guestNames[eventId];
    if (cached != null && guestIds.every(cached.containsKey)) return cached;
    final rows = await _client
        .from('event_guests')
        .select('id, name')
        .eq('event_id', eventId);
    final map = {
      for (final row in rows) row['id'] as String: row['name'] as String,
    };
    _guestNames[eventId] = map;
    return map;
  }

  static const _visibleStatuses = {'uploaded', 'processing', 'ready'};

  @override
  Stream<List<AlbumItem>> watchAlbum(String eventId) {
    return _client
        .from('uploads')
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId)
        .order('created_at')
        .asyncMap((rows) async {
          final visible = rows
              .where((r) => _visibleStatuses.contains(r['status']))
              .toList();
          final names = await _namesFor(
            eventId,
            visible.map((r) => r['guest_id'] as String),
          );
          return visible
              .map((r) => AlbumItem.fromMap(
                    r,
                    guestName: names[r['guest_id']] ?? 'Guest',
                  ))
              .toList();
        });
  }

  @override
  Stream<Set<String>> watchFavoriteIds() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return Stream.value(const {});
    return _client
        .from('favorites')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .map((rows) => rows.map((r) => r['upload_id'] as String).toSet());
  }

  @override
  Future<void> setFavorite(String uploadId, bool favorite) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw const AuthException('You need to sign in first.');
    }
    try {
      if (favorite) {
        await _client.from('favorites').upsert(
          {'upload_id': uploadId, 'user_id': uid},
          onConflict: 'upload_id,user_id',
          ignoreDuplicates: true,
        );
      } else {
        await _client
            .from('favorites')
            .delete()
            .eq('upload_id', uploadId)
            .eq('user_id', uid);
      }
    } on sb.PostgrestException catch (e) {
      _log.warning('favorite toggle failed: ${e.code}');
      throw UnexpectedException(cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  /// Splits `bucket/path…` into (bucket, objectPath).
  (String, String) _split(String path) {
    final slash = path.indexOf('/');
    return (path.substring(0, slash), path.substring(slash + 1));
  }

  @override
  Future<String> signedMediaUrl(String path) async {
    final (bucket, objectPath) = _split(path);
    try {
      return await _client.storage
          .from(bucket)
          .createSignedUrl(objectPath, 3600);
    } on sb.StorageException catch (e) {
      throw UnexpectedException(cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<Uint8List> downloadBytes(String path) async {
    final (bucket, objectPath) = _split(path);
    try {
      return await _client.storage.from(bucket).download(objectPath);
    } on sb.StorageException catch (e) {
      throw UnexpectedException(cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }
}
