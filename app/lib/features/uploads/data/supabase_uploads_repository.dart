import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/uploads_repository.dart';

/// Production [UploadsRepository]: Edge Function slot request + chunked PUT
/// to the signed storage URL with byte-level progress.
class SupabaseUploadsRepository implements UploadsRepository {
  SupabaseUploadsRepository(this._client, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final sb.SupabaseClient _client;
  final http.Client _http;
  static final _log = AppLogger.get('uploads');

  static const _chunkSize = 64 * 1024;

  @override
  Future<UploadSlot> requestSlot({
    required String eventId,
    required String fileName,
    required String mimeType,
    required int bytes,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'create-upload-url',
        body: {
          'event_id': eventId,
          'file_name': fileName,
          'mime_type': mimeType,
          'bytes': bytes,
        },
      );
      return UploadSlot.fromMap(res.data as Map<String, dynamic>);
    } on sb.FunctionException catch (e) {
      throw _mapFunctionError(e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  AppException _mapFunctionError(sb.FunctionException e) {
    final details = e.details;
    String code = 'internal';
    String? message;
    if (details is Map<String, dynamic>) {
      final error = details['error'];
      if (error is Map<String, dynamic>) {
        code = (error['code'] as String?) ?? code;
        message = error['message'] as String?;
      }
    }
    _log.warning('slot request failed: $code (${e.status})');
    return switch (code) {
      'quota_exceeded' => const QuotaExceededException(),
      'event_expired' => const EventExpiredException(),
      'not_joined' ||
      'banned' ||
      'unauthorized' =>
        AuthException(message ?? 'You cannot upload to this event.'),
      'unsupported_media' ||
      'too_large' ||
      'rate_limited' ||
      'bad_request' =>
        ValidationException(message ?? 'This file cannot be uploaded.'),
      _ => UnexpectedException(cause: e),
    };
  }

  @override
  Future<void> uploadBytes({
    required UploadSlot slot,
    required Uint8List bytes,
    required String mimeType,
    void Function(double progress)? onProgress,
  }) async {
    final request = http.StreamedRequest('PUT', Uri.parse(slot.signedUrl))
      ..headers['Content-Type'] = mimeType
      ..headers['x-upsert'] = 'false'
      ..contentLength = bytes.length;

    // Feed chunks into the sink, reporting progress as we go.
    unawaited(Future(() async {
      var sent = 0;
      try {
        for (var offset = 0; offset < bytes.length; offset += _chunkSize) {
          final end = (offset + _chunkSize).clamp(0, bytes.length);
          request.sink.add(bytes.sublist(offset, end));
          sent = end;
          onProgress?.call(sent / bytes.length);
          // Yield so the UI can paint between chunks.
          await Future<void>.delayed(Duration.zero);
        }
      } finally {
        unawaited(request.sink.close());
      }
    }));

    try {
      final response = await _http.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        _log.warning('storage PUT ${response.statusCode}: $body');
        throw const UnexpectedException(cause: 'storage upload failed');
      }
      onProgress?.call(1);
    } on AppException {
      rethrow;
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<void> confirmUploaded(String uploadId) async {
    try {
      await _client
          .from('uploads')
          .update({'status': 'uploaded'}).eq('id', uploadId);
    } on sb.PostgrestException catch (e) {
      throw UnexpectedException(cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }
}
