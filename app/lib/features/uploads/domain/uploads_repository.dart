import 'dart:typed_data';

/// A granted upload slot from the `create-upload-url` Edge Function.
class UploadSlot {
  const UploadSlot({
    required this.uploadId,
    required this.storagePath,
    required this.signedUrl,
    required this.token,
  });

  final String uploadId;
  final String storagePath;
  final String signedUrl;
  final String token;

  factory UploadSlot.fromMap(Map<String, dynamic> map) => UploadSlot(
    uploadId: map['upload_id'] as String,
    storagePath: map['storage_path'] as String,
    signedUrl: map['signed_url'] as String,
    token: map['token'] as String,
  );
}

/// Upload transport contract.
abstract interface class UploadsRepository {
  /// Requests a validated upload slot. Throws typed [AppException]s:
  /// [QuotaExceededException], [EventExpiredException], [ValidationException]
  /// (unsupported/too large/rate limited), [AuthException], [NetworkException].
  Future<UploadSlot> requestSlot({
    required String eventId,
    required String fileName,
    required String mimeType,
    required int bytes,
  });

  /// Streams [bytes] to the signed URL, reporting [onProgress] in 0..1.
  Future<void> uploadBytes({
    required UploadSlot slot,
    required Uint8List bytes,
    required String mimeType,
    void Function(double progress)? onProgress,
  });

  /// Confirms the upload server-side (`status = uploaded`), optionally
  /// attaching a caption (in-app camera captures).
  Future<void> confirmUploaded(String uploadId, {String? caption});
}
