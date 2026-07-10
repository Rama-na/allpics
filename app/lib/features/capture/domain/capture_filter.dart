import 'package:flutter/painting.dart';

/// A named 4x5 color-matrix filter applied to the camera preview and baked
/// into captured photos. Videos keep the filter preview-only.
class CaptureFilter {
  const CaptureFilter(this.name, this.matrix);

  final String name;

  /// 4x5 color matrix, or null for the identity (no filter).
  final List<double>? matrix;

  bool get isNone => matrix == null;

  ColorFilter? get colorFilter =>
      matrix == null ? null : ColorFilter.matrix(matrix!);

  /// Swipeable filter deck, Snapchat-style but SDK-free.
  static const List<CaptureFilter> all = [
    CaptureFilter('Original', null),
    CaptureFilter('Mono', [
      0.2126, 0.7152, 0.0722, 0, 0, //
      0.2126, 0.7152, 0.0722, 0, 0, //
      0.2126, 0.7152, 0.0722, 0, 0, //
      0, 0, 0, 1, 0,
    ]),
    CaptureFilter('Sepia', [
      0.393, 0.769, 0.189, 0, 0, //
      0.349, 0.686, 0.168, 0, 0, //
      0.272, 0.534, 0.131, 0, 0, //
      0, 0, 0, 1, 0,
    ]),
    CaptureFilter('Vivid', [
      1.25, 0, 0, 0, -12, //
      0, 1.25, 0, 0, -12, //
      0, 0, 1.25, 0, -12, //
      0, 0, 0, 1, 0,
    ]),
    CaptureFilter('Warm', [
      1.08, 0, 0, 0, 12, //
      0, 1.02, 0, 0, 4, //
      0, 0, 0.92, 0, -8, //
      0, 0, 0, 1, 0,
    ]),
    CaptureFilter('Cool', [
      0.92, 0, 0, 0, -8, //
      0, 1.02, 0, 0, 2, //
      0, 0, 1.08, 0, 12, //
      0, 0, 0, 1, 0,
    ]),
  ];
}
