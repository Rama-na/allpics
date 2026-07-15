import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../uploads/presentation/controllers/upload_queue_controller.dart';
import '../controllers/capture_controller.dart';

/// The full capture experience — viewfinder (tap photo / hold video / swipe
/// filters) → review with caption → feed the upload queue.
///
/// Embedded by both the standalone [CaptureScreen] route and the home
/// shell's camera page, which differ only via the slots below.
class CaptureFlow extends ConsumerStatefulWidget {
  const CaptureFlow({
    super.key,
    required this.eventId,
    this.autoInitialize = true,
    this.showClose = true,
    this.topOverlay,
    this.unavailableView,
    this.onSubmitted,
    this.onClose,
  });

  /// The event captures post into.
  final String eventId;

  /// Initialize the camera on mount (the shell manages lifecycle itself).
  final bool autoInitialize;

  /// Show the close button in the viewfinder's top bar.
  final bool showClose;

  /// Extra widget centered under the top bar (the shell's event chip).
  final Widget? topOverlay;

  /// Replacement for the default camera-unavailable view.
  final Widget? unavailableView;

  /// Called after a capture is queued for upload.
  final VoidCallback? onSubmitted;

  /// Called by the close button (required when [showClose] is true).
  final VoidCallback? onClose;

  @override
  ConsumerState<CaptureFlow> createState() => _CaptureFlowState();
}

class _Captured {
  const _Captured({required this.file, required this.isVideo, this.bytes});

  final XFile file;
  final bool isVideo;

  /// Photo bytes for the review preview (null for videos).
  final Uint8List? bytes;
}

class _CaptureFlowState extends ConsumerState<CaptureFlow> {
  final _caption = TextEditingController();
  _Captured? _captured;
  Timer? _recordTicker;
  Duration _recordElapsed = Duration.zero;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoInitialize) {
      // Post-frame: provider mutation is not allowed during widget build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(captureControllerProvider.notifier).initialize();
      });
    }
  }

  @override
  void dispose() {
    _recordTicker?.cancel();
    _caption.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    if (_busy) return;
    setState(() => _busy = true);
    final file =
        await ref.read(captureControllerProvider.notifier).takePhoto();
    if (!mounted) return;
    if (file == null) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not take the photo. Please try again.'),
      ));
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _captured = _Captured(file: file, isVideo: false, bytes: bytes);
      _busy = false;
    });
  }

  Future<void> _startVideo() async {
    if (_busy || _captured != null) return;
    await ref.read(captureControllerProvider.notifier).startVideo();
    if (!mounted) return;
    _recordElapsed = Duration.zero;
    _recordTicker?.cancel();
    _recordTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordElapsed += const Duration(seconds: 1));
    });
    setState(() {});
  }

  Future<void> _stopVideo() async {
    _recordTicker?.cancel();
    _recordTicker = null;
    final file =
        await ref.read(captureControllerProvider.notifier).stopVideo();
    if (!mounted) return;
    setState(() {
      if (file != null) {
        _captured = _Captured(file: file, isVideo: true);
      }
    });
  }

  Future<void> _addToAlbum() async {
    final captured = _captured;
    if (captured == null) return;
    final caption = _caption.text.trim();
    await ref.read(uploadQueueControllerProvider.notifier).addFiles(
      widget.eventId,
      [captured.file],
      captionsByName: {
        if (caption.isNotEmpty) captured.file.name: caption,
      },
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(captured.isVideo
          ? 'Video added — uploading in the background.'
          : 'Photo added — uploading in the background.'),
    ));
    _retake();
    widget.onSubmitted?.call();
  }

  void _retake() {
    _caption.clear();
    setState(() => _captured = null);
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(captureControllerProvider);

    if (_captured != null) {
      return _ReviewView(
        captured: _captured!,
        caption: _caption,
        elapsedLabel: _formatElapsed(_recordElapsed),
        onRetake: _retake,
        onConfirm: _addToAlbum,
      );
    }
    return switch (state.status) {
      CaptureStatus.initializing => const LoadingView(),
      CaptureStatus.unavailable => widget.unavailableView ??
          CameraUnavailableView(
            message: state.message ?? 'No camera available on this device.',
            onClose: widget.showClose ? widget.onClose : null,
          ),
      _ => _CameraView(
          state: state,
          busy: _busy,
          recordElapsed: _recordElapsed,
          formatElapsed: _formatElapsed,
          onTakePhoto: _takePhoto,
          onStartVideo: _startVideo,
          onStopVideo: _stopVideo,
          showClose: widget.showClose,
          onClose: widget.onClose,
          topOverlay: widget.topOverlay,
        ),
    };
  }
}

/// Default fallback when no camera exists (web, permissions, no hardware).
class CameraUnavailableView extends StatelessWidget {
  const CameraUnavailableView({
    super.key,
    required this.message,
    this.onClose,
    this.action,
  });

  final String message;
  final VoidCallback? onClose;

  /// Optional action below the message (e.g. a gallery-picker button).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (onClose != null)
          Align(
            alignment: Alignment.centerLeft,
            child: RoundIconButton(
              icon: Icons.close_rounded,
              label: 'Close camera',
              onPressed: onClose,
            ),
          ),
        Expanded(
          child: Theme(
            data: ThemeData.dark(useMaterial3: true),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ErrorView(
                  icon: Icons.no_photography_outlined,
                  message:
                      '$message\nYou can still add photos from your gallery.',
                ),
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CameraView extends ConsumerWidget {
  const _CameraView({
    required this.state,
    required this.busy,
    required this.recordElapsed,
    required this.formatElapsed,
    required this.onTakePhoto,
    required this.onStartVideo,
    required this.onStopVideo,
    required this.showClose,
    this.onClose,
    this.topOverlay,
  });

  final CaptureState state;
  final bool busy;
  final Duration recordElapsed;
  final String Function(Duration) formatElapsed;
  final VoidCallback onTakePhoto;
  final VoidCallback onStartVideo;
  final VoidCallback onStopVideo;
  final bool showClose;
  final VoidCallback? onClose;
  final Widget? topOverlay;

  IconData get _flashIcon => switch (state.flashMode) {
        FlashMode.auto => Icons.flash_auto_rounded,
        FlashMode.always => Icons.flash_on_rounded,
        _ => Icons.flash_off_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(captureControllerProvider.notifier);
    final camera = controller.camera;
    final isRecording = state.status == CaptureStatus.recording;
    final filter = state.filter;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (camera != null && camera.value.isInitialized)
          GestureDetector(
            onHorizontalDragEnd: isRecording
                ? null
                : (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity < -100) {
                      controller.nextFilter();
                    } else if (velocity > 100) {
                      controller.previousFilter();
                    }
                  },
            child: filter.colorFilter == null
                ? CameraPreview(camera)
                : ColorFiltered(
                    colorFilter: filter.colorFilter!,
                    child: CameraPreview(camera),
                  ),
          ),
        // Brief white flash while the photo is captured.
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: busy ? 0.55 : 0,
            duration: const Duration(milliseconds: 90),
            child: const ColoredBox(color: Colors.white),
          ),
        ),
        // Top bar: close, filter name, flash, flip.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Row(
                children: [
                  if (showClose)
                    RoundIconButton(
                      icon: Icons.close_rounded,
                      label: 'Close camera',
                      onPressed: isRecording ? null : onClose,
                    )
                  else
                    const SizedBox(width: 56),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      key: ValueKey(filter.name),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Text(
                        filter.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const Spacer(),
                  RoundIconButton(
                    icon: _flashIcon,
                    label: 'Toggle flash',
                    onPressed: isRecording ? null : controller.toggleFlash,
                  ),
                  RoundIconButton(
                    icon: Icons.cameraswitch_rounded,
                    label: 'Flip camera',
                    onPressed: state.canFlip && !isRecording
                        ? controller.flipCamera
                        : null,
                  ),
                ],
              ),
              ?topOverlay,
            ],
          ),
        ),
        if (isRecording)
          Positioned(
            top: 96,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fiber_manual_record_rounded,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      formatElapsed(recordElapsed),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Bottom: hint + shutter.
        Positioned(
          bottom: AppSpacing.lg,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                isRecording
                    ? 'Release to stop — filters apply to photos only'
                    : 'Tap for photo · hold for video · swipe for filters',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.md),
              CaptureShutterButton(
                busy: busy,
                isRecording: isRecording,
                onTakePhoto: onTakePhoto,
                onStartVideo: onStartVideo,
                onStopVideo: onStopVideo,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The 76px Snapchat-style shutter: tap = photo, hold = video.
/// Scales down while pressed for tactile feedback.
class CaptureShutterButton extends StatefulWidget {
  const CaptureShutterButton({
    super.key,
    required this.busy,
    required this.isRecording,
    required this.onTakePhoto,
    required this.onStartVideo,
    required this.onStopVideo,
  });

  final bool busy;
  final bool isRecording;
  final VoidCallback onTakePhoto;
  final VoidCallback onStartVideo;
  final VoidCallback onStopVideo;

  @override
  State<CaptureShutterButton> createState() => _CaptureShutterButtonState();
}

class _CaptureShutterButtonState extends State<CaptureShutterButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Shutter — tap for photo, hold for video',
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.busy ? null : widget.onTakePhoto,
        onLongPressStart: (_) => widget.onStartVideo(),
        onLongPressEnd: (_) {
          _setPressed(false);
          widget.onStopVideo();
        },
        child: AnimatedScale(
          scale: _pressed || widget.isRecording ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isRecording ? Colors.redAccent : Colors.white,
              border: Border.all(
                color: widget.isRecording ? Colors.red : Colors.white38,
                width: 5,
              ),
            ),
            child: widget.busy
                ? const Padding(
                    padding: EdgeInsets.all(22),
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _ReviewView extends StatelessWidget {
  const _ReviewView({
    required this.captured,
    required this.caption,
    required this.elapsedLabel,
    required this.onRetake,
    required this.onConfirm,
  });

  final _Captured captured;
  final TextEditingController caption;
  final String elapsedLabel;
  final VoidCallback onRetake;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: captured.bytes != null
              ? InteractiveViewer(
                  child: Center(child: Image.memory(captured.bytes!)),
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_rounded,
                          size: 72, color: Colors.white70),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Video recorded · $elapsedLabel',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Theme(
            data: ThemeData.dark(useMaterial3: true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: caption,
                  maxLength: 500,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Add a caption (optional)',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Retake',
                        icon: Icons.replay_rounded,
                        variant: AppButtonVariant.secondary,
                        onPressed: onRetake,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton(
                        label: 'Add to album',
                        icon: Icons.check_rounded,
                        onPressed: onConfirm,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Scrim-friendly round icon button used across the viewfinder overlays.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: IconButton.filled(
        style: IconButton.styleFrom(
          backgroundColor: Colors.black45,
          foregroundColor: Colors.white,
        ),
        tooltip: label,
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }
}
