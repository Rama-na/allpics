import 'dart:typed_data';
import 'dart:ui' as ui;

import 'capture_filter.dart';

/// Bakes a [CaptureFilter] into photo bytes using dart:ui only (no extra
/// dependencies). The identity filter returns the original bytes untouched,
/// preserving the camera's JPEG; filtered output is re-encoded as PNG.
Future<Uint8List> bakeFilter(Uint8List bytes, CaptureFilter filter) async {
  if (filter.isNone) return bytes;

  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImage(
      image,
      ui.Offset.zero,
      ui.Paint()..colorFilter = filter.colorFilter,
    );
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(image.width, image.height);
    try {
      final data =
          await rendered.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return bytes;
      return data.buffer.asUint8List();
    } finally {
      rendered.dispose();
    }
  } finally {
    image.dispose();
  }
}
