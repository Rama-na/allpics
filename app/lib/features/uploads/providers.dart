import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_env.dart';
import '../../core/errors/app_exception.dart';
import '../auth/providers.dart';
import 'data/supabase_uploads_repository.dart';
import 'domain/uploads_repository.dart';

/// Pre-provisioning fallback.
class _UnconfiguredUploadsRepository implements UploadsRepository {
  const _UnconfiguredUploadsRepository();

  static const _error = UnexpectedException(
    cause: 'Backend not configured — see docs/DEPLOYMENT.md',
  );

  @override
  Future<UploadSlot> requestSlot({
    required String eventId,
    required String fileName,
    required String mimeType,
    required int bytes,
  }) async => throw _error;

  @override
  Future<void> uploadBytes({
    required UploadSlot slot,
    required Uint8List bytes,
    required String mimeType,
    void Function(double progress)? onProgress,
  }) async => throw _error;

  @override
  Future<void> confirmUploaded(String uploadId, {String? caption}) async =>
      throw _error;
}

final uploadsRepositoryProvider = Provider<UploadsRepository>((ref) {
  if (!AppEnv.isSupabaseConfigured) {
    return const _UnconfiguredUploadsRepository();
  }
  return SupabaseUploadsRepository(ref.watch(supabaseClientProvider));
});
