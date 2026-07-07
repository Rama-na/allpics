import 'dart:typed_data';

import 'package:allpics/features/uploads/data/upload_queue_store.dart';
import 'package:allpics/features/uploads/domain/upload_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UploadTask serialization', () {
    test('round-trips path-backed tasks and resets status to queued', () {
      const task = UploadTask(
        id: 't1',
        eventId: 'e1',
        fileName: 'a.jpg',
        mimeType: 'image/jpeg',
        totalBytes: 2048,
        kind: MediaKind.photo,
        filePath: '/tmp/a.jpg',
        status: UploadTaskStatus.failed,
        error: 'boom',
      );
      final restored = UploadTask.fromJson(task.toJson());
      expect(restored, isNotNull);
      expect(restored!.id, 't1');
      expect(restored.fileName, 'a.jpg');
      expect(restored.kind, MediaKind.photo);
      // Restored tasks always resume from queued with no stale error.
      expect(restored.status, UploadTaskStatus.queued);
      expect(restored.error, isNull);
    });

    test('in-memory tasks (no path) are not restorable by design', () {
      final task = UploadTask(
        id: 't2',
        eventId: 'e1',
        fileName: 'b.jpg',
        mimeType: 'image/jpeg',
        totalBytes: 10,
        kind: MediaKind.photo,
        inMemoryBytes: Uint8List(10),
      );
      expect(UploadTask.fromJson(task.toJson()), isNull);
    });

    test('mime inference and media kinds', () {
      expect(mimeTypeForFileName('IMG_1.HEIC'), 'image/heic');
      expect(mimeTypeForFileName('clip.MOV'), 'video/quicktime');
      expect(mimeTypeForFileName('noext'), 'application/octet-stream');
      expect(mediaKindForMime('video/mp4'), MediaKind.video);
      expect(mediaKindForMime('image/png'), MediaKind.photo);
      expect(isSupportedMime('image/webp'), isTrue);
      expect(isSupportedMime('application/pdf'), isFalse);
    });
  });

  group('UploadQueueStore', () {
    test('persists only unfinished path-backed tasks', () async {
      SharedPreferences.setMockInitialValues({});
      final store = UploadQueueStore();
      const done = UploadTask(
        id: 'done',
        eventId: 'e1',
        fileName: 'done.jpg',
        mimeType: 'image/jpeg',
        totalBytes: 1,
        kind: MediaKind.photo,
        filePath: '/tmp/done.jpg',
        status: UploadTaskStatus.success,
      );
      const pending = UploadTask(
        id: 'pending',
        eventId: 'e1',
        fileName: 'pending.jpg',
        mimeType: 'image/jpeg',
        totalBytes: 1,
        kind: MediaKind.photo,
        filePath: '/tmp/pending.jpg',
        status: UploadTaskStatus.failed,
      );

      await store.save([done, pending]);
      final restored = await store.restore();

      expect(restored, hasLength(1));
      expect(restored.single.id, 'pending');
      expect(restored.single.status, UploadTaskStatus.queued);
    });

    test('clears storage when everything succeeded', () async {
      SharedPreferences.setMockInitialValues({});
      final store = UploadQueueStore();
      const done = UploadTask(
        id: 'done',
        eventId: 'e1',
        fileName: 'done.jpg',
        mimeType: 'image/jpeg',
        totalBytes: 1,
        kind: MediaKind.photo,
        filePath: '/tmp/done.jpg',
        status: UploadTaskStatus.success,
      );
      await store.save([done]);
      expect(await store.restore(), isEmpty);
    });

    test('corrupt storage is discarded safely', () async {
      SharedPreferences.setMockInitialValues(
          {'allpics.upload_queue.v1': 'not-json{'});
      final store = UploadQueueStore();
      expect(await store.restore(), isEmpty);
    });
  });
}
