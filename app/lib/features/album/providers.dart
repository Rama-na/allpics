import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_env.dart';
import '../../core/errors/app_exception.dart';
import '../auth/providers.dart';
import 'data/supabase_album_repository.dart';
import 'domain/album_item.dart';
import 'domain/album_repository.dart';

/// Pre-provisioning fallback.
class _UnconfiguredAlbumRepository implements AlbumRepository {
  const _UnconfiguredAlbumRepository();

  static const _error = UnexpectedException(
    cause: 'Backend not configured — see docs/DEPLOYMENT.md',
  );

  @override
  Stream<List<AlbumItem>> watchAlbum(String eventId) =>
      Stream.value(const []);

  @override
  Stream<Set<String>> watchFavoriteIds() => Stream.value(const {});

  @override
  Future<void> setFavorite(String uploadId, bool favorite) async =>
      throw _error;

  @override
  Future<String> signedMediaUrl(String path) async => throw _error;

  @override
  Future<Uint8List> downloadBytes(String path) async => throw _error;
}

final albumRepositoryProvider = Provider<AlbumRepository>((ref) {
  if (!AppEnv.isSupabaseConfigured) return const _UnconfiguredAlbumRepository();
  return SupabaseAlbumRepository(ref.watch(supabaseClientProvider));
});

/// Live album items for an event.
final albumItemsProvider =
    StreamProvider.family<List<AlbumItem>, String>((ref, eventId) {
  return ref.watch(albumRepositoryProvider).watchAlbum(eventId);
});

/// Live favorite ids for the current user.
final favoriteIdsProvider = StreamProvider<Set<String>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(albumRepositoryProvider).watchFavoriteIds();
});

/// Signed URL cache per storage path (1h TTL server-side).
final mediaUrlProvider = FutureProvider.family<String, String>((ref, path) {
  return ref.watch(albumRepositoryProvider).signedMediaUrl(path);
});
