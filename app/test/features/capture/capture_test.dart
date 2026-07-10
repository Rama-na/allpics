import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:allpics/features/capture/domain/capture_filter.dart';
import 'package:allpics/features/capture/domain/filter_baker.dart';
import 'package:allpics/features/uploads/domain/upload_task.dart';
import 'package:allpics/features/uploads/presentation/controllers/upload_queue_controller.dart';
import 'package:allpics/features/uploads/providers.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

/// Renders a tiny solid-color PNG for filter-baking tests.
Future<Uint8List> _solidPng(ui.Color color, {int size = 4}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    ui.Paint()..color = color,
  );
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CaptureFilter', () {
    test('deck starts with the identity filter', () {
      expect(CaptureFilter.all.first.isNone, isTrue);
      expect(CaptureFilter.all.first.colorFilter, isNull);
    });

    test('every non-identity filter carries a 4x5 matrix', () {
      for (final filter in CaptureFilter.all.skip(1)) {
        expect(filter.matrix, hasLength(20), reason: filter.name);
        expect(filter.colorFilter, isNotNull, reason: filter.name);
      }
    });

    test('filter names are unique', () {
      final names = CaptureFilter.all.map((f) => f.name).toSet();
      expect(names.length, CaptureFilter.all.length);
    });
  });

  group('bakeFilter', () {
    test('identity filter returns the original bytes untouched', () async {
      final bytes = await _solidPng(const ui.Color(0xFFFF0000));
      final baked = await bakeFilter(bytes, CaptureFilter.all.first);
      expect(identical(baked, bytes), isTrue);
    });

    test('mono filter turns a red image grey', () async {
      final bytes = await _solidPng(const ui.Color(0xFFFF0000));
      final mono =
          CaptureFilter.all.firstWhere((f) => f.name == 'Mono');
      final baked = await bakeFilter(bytes, mono);

      final codec = await ui.instantiateImageCodec(baked);
      final frame = await codec.getNextFrame();
      final pixels =
          await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final r = pixels!.getUint8(0);
      final g = pixels.getUint8(1);
      final b = pixels.getUint8(2);
      // Luminance-weighted grey: channels equalize.
      expect(r, equals(g));
      expect(g, equals(b));
      expect(r, greaterThan(0));
    });
  });

  group('capture → upload caption plumbing', () {
    test('addFiles forwards captions to confirmUploaded', () async {
      SharedPreferences.setMockInitialValues({});
      final uploads = FakeUploadsRepository();
      final container = ProviderContainer(overrides: [
        uploadsRepositoryProvider.overrideWithValue(uploads),
      ]);
      addTearDown(container.dispose);

      final file = XFile.fromData(
        Uint8List.fromList(List.filled(64, 1)),
        name: 'allpics_shot.png',
        mimeType: 'image/png',
      );
      // Key by file.name — exactly how the capture screen builds the map
      // (XFile.name may differ from the requested name on some platforms).
      await container
          .read(uploadQueueControllerProvider.notifier)
          .addFiles('event-1', [file],
              captionsByName: {file.name: 'Sunset at the beach'});

      // Let the worker pool drain.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(uploads.confirmed, hasLength(1));
      expect(uploads.captionsByUploadId.values.single, 'Sunset at the beach');
      final task =
          container.read(uploadQueueControllerProvider).tasks.single;
      expect(task.caption, 'Sunset at the beach');
      expect(task.status, UploadTaskStatus.success);
    });

    test('caption survives task serialization', () {
      const task = UploadTask(
        id: 't1',
        eventId: 'event-1',
        fileName: 'a.jpg',
        mimeType: 'image/jpeg',
        totalBytes: 10,
        kind: MediaKind.photo,
        filePath: '/tmp/a.jpg',
        caption: 'Hello',
      );
      final restored = UploadTask.fromJson(task.toJson());
      expect(restored?.caption, 'Hello');
    });
  });
}
