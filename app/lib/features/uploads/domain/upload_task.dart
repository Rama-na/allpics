import 'dart:typed_data';

/// Media kind, mirrors the `media_type` enum.
enum MediaKind { photo, video }

/// Local lifecycle of one file in the upload queue.
enum UploadTaskStatus {
  /// Waiting for a worker slot.
  queued,

  /// Requesting a signed URL / streaming bytes.
  uploading,

  /// Fully uploaded and confirmed.
  success,

  /// Failed — retryable.
  failed,

  /// Blocked because the event album is full — not retryable.
  blocked,
}

/// One file in the guest's upload queue. Immutable; the controller advances
/// it via [copyWith].
class UploadTask {
  const UploadTask({
    required this.id,
    required this.eventId,
    required this.fileName,
    required this.mimeType,
    required this.totalBytes,
    required this.kind,
    this.filePath,
    this.inMemoryBytes,
    this.caption = '',
    this.status = UploadTaskStatus.queued,
    this.progress = 0,
    this.error,
    this.uploadId,
  });

  /// Local queue id (not the server row id).
  final String id;
  final String eventId;
  final String fileName;
  final String mimeType;
  final int totalBytes;
  final MediaKind kind;

  /// Path on disk (mobile/desktop). Bytes are read lazily at upload time.
  final String? filePath;

  /// Fallback for platforms without stable file paths (web, tests).
  final Uint8List? inMemoryBytes;

  /// Optional caption applied on upload confirmation (in-app camera).
  final String caption;

  final UploadTaskStatus status;

  /// 0..1 while uploading.
  final double progress;

  /// User-safe error message when [status] is failed/blocked.
  final String? error;

  /// Server `uploads.id` once a slot was granted.
  final String? uploadId;

  bool get isRetryable => status == UploadTaskStatus.failed;
  bool get isDone =>
      status == UploadTaskStatus.success || status == UploadTaskStatus.blocked;

  UploadTask copyWith({
    UploadTaskStatus? status,
    double? progress,
    String? error,
    String? uploadId,
    bool clearError = false,
  }) => UploadTask(
    id: id,
    eventId: eventId,
    fileName: fileName,
    mimeType: mimeType,
    totalBytes: totalBytes,
    kind: kind,
    filePath: filePath,
    inMemoryBytes: inMemoryBytes,
    caption: caption,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    error: clearError ? null : (error ?? this.error),
    uploadId: uploadId ?? this.uploadId,
  );

  /// Persistence for offline retry (bytes are NOT serialized — path only,
  /// so in-memory tasks are session-scoped by design).
  Map<String, dynamic> toJson() => {
    'id': id,
    'event_id': eventId,
    'file_name': fileName,
    'mime_type': mimeType,
    'total_bytes': totalBytes,
    'kind': kind.name,
    'file_path': filePath,
    'caption': caption,
    'status': status.name,
    'error': error,
  };

  static UploadTask? fromJson(Map<String, dynamic> json) {
    final filePath = json['file_path'] as String?;
    if (filePath == null || filePath.isEmpty) return null;
    return UploadTask(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      fileName: json['file_name'] as String,
      mimeType: json['mime_type'] as String,
      totalBytes: (json['total_bytes'] as num).toInt(),
      kind: MediaKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => MediaKind.photo,
      ),
      filePath: filePath,
      caption: (json['caption'] as String?) ?? '',
      // Restored tasks resume from queued regardless of prior state.
      status: UploadTaskStatus.queued,
    );
  }
}

/// Mime type inference from a file name (image_picker does not always
/// provide one).
String mimeTypeForFileName(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    _ => 'application/octet-stream',
  };
}

MediaKind mediaKindForMime(String mime) =>
    mime.startsWith('video/') ? MediaKind.video : MediaKind.photo;

bool isSupportedMime(String mime) => const {
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'image/heif',
  'video/mp4',
  'video/quicktime',
  'video/webm',
}.contains(mime);
