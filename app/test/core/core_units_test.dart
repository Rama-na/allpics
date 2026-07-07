import 'dart:async';

import 'package:allpics/core/errors/app_exception.dart';
import 'package:allpics/core/router/go_router_refresh_stream.dart';
import 'package:allpics/features/album/domain/album_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GoRouterRefreshStream', () {
    test('notifies listeners on every stream event', () async {
      final controller = StreamController<int>();
      final refresh = GoRouterRefreshStream(controller.stream);
      var notified = 0;
      refresh.addListener(() => notified++);

      controller.add(1);
      controller.add(2);
      await Future<void>.delayed(Duration.zero);

      expect(notified, 2);
      refresh.dispose();
      await controller.close();
    });
  });

  group('AlbumItem', () {
    test('parses rows and prefers thumbnails for previews', () {
      final item = AlbumItem.fromMap({
        'id': 'u1',
        'event_id': 'e1',
        'guest_id': 'g1',
        'media_type': 'photo',
        'storage_path': 'media/e1/u1.jpg',
        'thumb_path': 'thumbs/e1/u1.jpg',
        'caption': 'Sunset',
        'status': 'ready',
        'created_at': '2026-07-01T10:00:00Z',
      }, guestName: 'Anita');

      expect(item.previewPath, 'thumbs/e1/u1.jpg');
      expect(item.isVideo, isFalse);
      expect(item.isReady, isTrue);
      expect(item.guestName, 'Anita');
    });

    test('falls back to the original when no thumbnail exists yet', () {
      final item = AlbumItem.fromMap({
        'id': 'u2',
        'event_id': 'e1',
        'guest_id': 'g1',
        'media_type': 'video',
        'storage_path': 'media/e1/u2.mp4',
        'thumb_path': null,
        'status': 'processing',
        'created_at': '2026-07-01T10:00:00Z',
      }, guestName: 'Rahul');

      expect(item.previewPath, 'media/e1/u2.mp4');
      expect(item.isVideo, isTrue);
      expect(item.isReady, isFalse);
    });
  });

  group('AppException messages', () {
    test('user-safe messages never expose causes', () {
      const exceptions = <AppException>[
        NetworkException(cause: 'SocketException: 10.0.2.2'),
        QuotaExceededException(),
        EventExpiredException(),
        UnexpectedException(cause: 'stack trace details'),
      ];
      for (final e in exceptions) {
        expect(e.message, isNotEmpty);
        expect(e.message.contains('SocketException'), isFalse);
        expect(e.message.contains('stack trace'), isFalse);
      }
    });
  });
}
