import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../auth/providers.dart';
import '../../../capture/presentation/widgets/capture_flow.dart';
import '../../../guest/providers.dart';
import '../../providers.dart';
import '../widgets/event_context_chip.dart';

/// Shell page 1 (home): the full-bleed viewfinder, posting into the active
/// event. Without a postable event it invites the user to join or create.
class ShellCameraPage extends ConsumerStatefulWidget {
  const ShellCameraPage({super.key, required this.onJoinTap});

  /// Slides the shell to the Join page.
  final VoidCallback onJoinTap;

  @override
  ConsumerState<ShellCameraPage> createState() => _ShellCameraPageState();
}

class _ShellCameraPageState extends ConsumerState<ShellCameraPage> {
  /// Event ids whose host membership has been ensured this session.
  final _membershipEnsured = <String>{};

  /// Hosts need an event_guests row to upload (uploads.guest_id is NOT NULL
  /// and the edge function rejects non-members). Self-join lazily, once.
  Future<void> _ensureHostMembership(String eventId) async {
    if (!_membershipEnsured.add(eventId)) return;
    try {
      final join = ref.read(joinRepositoryProvider);
      final existing = await join.existingMembership(eventId);
      if (existing != null) return;
      final user = ref.read(currentUserProvider);
      final name = (user?.fullName?.trim().isNotEmpty ?? false)
          ? user!.fullName!.trim()
          : 'Host';
      await join.joinEvent(eventId: eventId, name: name);
    } catch (_) {
      // Best-effort: the upload itself will surface a clear error if this
      // genuinely failed; allow a retry on the next activation.
      _membershipEnsured.remove(eventId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeEventProvider);

    if (active == null) {
      return _NoEventView(onJoinTap: widget.onJoinTap);
    }
    if (active.isHost) {
      _ensureHostMembership(active.event.id);
    }
    return CaptureFlow(
      // Rebuild the flow when the posting target changes.
      key: ValueKey(active.event.id),
      eventId: active.event.id,
      autoInitialize: false, // the shell drives camera lifecycle
      showClose: false,
      topOverlay: EventContextChip(active: active),
    );
  }
}

/// Camera page background when there is nothing to post into yet.
class _NoEventView extends StatelessWidget {
  const _NoEventView({required this.onJoinTap});

  final VoidCallback onJoinTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B173A), Color(0xFF2A1230)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.all(Radius.circular(26)),
                      ),
                      child: const Icon(Icons.photo_camera_rounded,
                          color: Colors.white, size: 42),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Snap into an event',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Join an event with a code, or create your own — '
                    'then everything you shoot lands in the shared album.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Join an event',
                    icon: Icons.qr_code_rounded,
                    onPressed: onJoinTap,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Theme(
                    data: ThemeData.dark(useMaterial3: true),
                    child: AppButton(
                      label: 'Create an event — free',
                      icon: Icons.add_a_photo_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => context.pushNamed(AppRoute.createEvent),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Free to start — 100 uploads, 7 days. No card needed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
