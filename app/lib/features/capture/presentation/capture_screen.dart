import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'controllers/capture_controller.dart';
import 'widgets/capture_flow.dart';

/// Standalone in-app camera route (`/capture/:eventId`), reached from the
/// guest upload panel. The home shell embeds the same [CaptureFlow].
class CaptureScreen extends ConsumerWidget {
  const CaptureScreen({super.key, required this.eventId});

  final String eventId;

  void _close(BuildContext context, WidgetRef ref) {
    // Release the camera when leaving the standalone route.
    ref.read(captureControllerProvider.notifier).shutdown();
    context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: CaptureFlow(
          eventId: eventId,
          onClose: () => _close(context, ref),
          onSubmitted: () => _close(context, ref),
        ),
      ),
    );
  }
}
