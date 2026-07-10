import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../domain/capture_filter.dart';
import '../../domain/filter_baker.dart';

enum CaptureStatus {
  /// Camera is being located and opened.
  initializing,

  /// Live preview is running.
  ready,

  /// A video is being recorded.
  recording,

  /// No usable camera (web, permission denied, no hardware).
  unavailable,
}

class CaptureState {
  const CaptureState({
    this.status = CaptureStatus.initializing,
    this.filterIndex = 0,
    this.flashMode = FlashMode.off,
    this.cameraIndex = 0,
    this.canFlip = false,
    this.message,
  });

  final CaptureStatus status;
  final int filterIndex;
  final FlashMode flashMode;
  final int cameraIndex;
  final bool canFlip;

  /// User-safe explanation when [status] is unavailable.
  final String? message;

  CaptureFilter get filter => CaptureFilter.all[filterIndex];

  CaptureState copyWith({
    CaptureStatus? status,
    int? filterIndex,
    FlashMode? flashMode,
    int? cameraIndex,
    bool? canFlip,
    String? message,
  }) =>
      CaptureState(
        status: status ?? this.status,
        filterIndex: filterIndex ?? this.filterIndex,
        flashMode: flashMode ?? this.flashMode,
        cameraIndex: cameraIndex ?? this.cameraIndex,
        canFlip: canFlip ?? this.canFlip,
        message: message ?? this.message,
      );
}

/// Owns the [CameraController] lifecycle behind a Riverpod notifier so the
/// capture screen stays declarative and tests can override the provider.
class CaptureController extends Notifier<CaptureState> {
  static final _log = AppLogger.get('capture');

  CameraController? _camera;
  List<CameraDescription> _cameras = const [];

  /// Live plugin controller for [CameraPreview]; null until ready.
  CameraController? get camera => _camera;

  @override
  CaptureState build() {
    ref.onDispose(() {
      _camera?.dispose();
      _camera = null;
    });
    return const CaptureState();
  }

  Future<void> initialize() async {
    state = const CaptureState();
    try {
      _cameras = await availableCameras();
    } catch (e) {
      _log.info('camera unavailable: $e');
      _cameras = const [];
    }
    if (_cameras.isEmpty) {
      state = state.copyWith(
        status: CaptureStatus.unavailable,
        message: 'No camera available on this device.',
      );
      return;
    }
    await _open(0);
  }

  Future<void> _open(int index) async {
    await _camera?.dispose();
    _camera = null;
    final controller = CameraController(
      _cameras[index],
      // High bounds the baked-photo size well under the 25 MB upload cap.
      ResolutionPreset.high,
      enableAudio: true,
    );
    try {
      await controller.initialize();
      await controller.setFlashMode(state.flashMode);
      _camera = controller;
      state = state.copyWith(
        status: CaptureStatus.ready,
        cameraIndex: index,
        canFlip: _cameras.length > 1,
      );
    } catch (e) {
      _log.warning('camera init failed: $e');
      await controller.dispose();
      state = state.copyWith(
        status: CaptureStatus.unavailable,
        message: 'Could not start the camera. '
            'Check the camera permission and try again.',
      );
    }
  }

  Future<void> flipCamera() async {
    if (_cameras.length < 2 || state.status != CaptureStatus.ready) return;
    state = state.copyWith(status: CaptureStatus.initializing);
    await _open((state.cameraIndex + 1) % _cameras.length);
  }

  Future<void> toggleFlash() async {
    final next = switch (state.flashMode) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    try {
      await _camera?.setFlashMode(next);
      state = state.copyWith(flashMode: next);
    } catch (e) {
      _log.info('flash unsupported: $e');
    }
  }

  void setFilterIndex(int index) {
    state = state.copyWith(
      filterIndex: index.clamp(0, CaptureFilter.all.length - 1),
    );
  }

  void nextFilter() => setFilterIndex(
      (state.filterIndex + 1) % CaptureFilter.all.length);

  void previousFilter() => setFilterIndex(
      (state.filterIndex - 1 + CaptureFilter.all.length) %
          CaptureFilter.all.length);

  /// Takes a photo and bakes the active filter in. Returns null on failure.
  Future<XFile?> takePhoto() async {
    final camera = _camera;
    if (camera == null || state.status != CaptureStatus.ready) return null;
    try {
      final shot = await camera.takePicture();
      final filter = state.filter;
      if (filter.isNone) return shot;
      final baked = await bakeFilter(await shot.readAsBytes(), filter);
      final name = 'allpics_${DateTime.now().millisecondsSinceEpoch}.png';
      if (kIsWeb) {
        return XFile.fromData(baked, name: name, mimeType: 'image/png');
      }
      // A real file gives the upload queue a stable name and lets the
      // offline queue persist the task across restarts.
      final path =
          '${Directory.systemTemp.path}${Platform.pathSeparator}$name';
      await File(path).writeAsBytes(baked);
      return XFile(path, mimeType: 'image/png');
    } catch (e) {
      _log.warning('photo capture failed: $e');
      return null;
    }
  }

  Future<void> startVideo() async {
    final camera = _camera;
    if (camera == null || state.status != CaptureStatus.ready) return;
    try {
      await camera.startVideoRecording();
      state = state.copyWith(status: CaptureStatus.recording);
    } catch (e) {
      _log.warning('video start failed: $e');
    }
  }

  /// Stops recording; the filter stays preview-only for video.
  Future<XFile?> stopVideo() async {
    final camera = _camera;
    if (camera == null || state.status != CaptureStatus.recording) return null;
    try {
      final file = await camera.stopVideoRecording();
      state = state.copyWith(status: CaptureStatus.ready);
      return file;
    } catch (e) {
      _log.warning('video stop failed: $e');
      state = state.copyWith(status: CaptureStatus.ready);
      return null;
    }
  }
}

final captureControllerProvider =
    NotifierProvider<CaptureController, CaptureState>(CaptureController.new);
