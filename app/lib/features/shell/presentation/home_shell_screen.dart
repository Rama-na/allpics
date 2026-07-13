import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../admin/providers.dart';
import '../../auth/providers.dart';
import '../../capture/presentation/controllers/capture_controller.dart';
import '../../notifications/providers.dart';
import '../providers.dart';
import 'pages/join_page.dart';
import 'pages/my_events_page.dart';
import 'pages/shell_camera_page.dart';

/// Snapchat-grammar home: a horizontal PageView with the camera at the
/// center. Swipe right (or tap "Events") for every event you're part of;
/// swipe left (or tap "Join") to enter a code. Open to everyone — hosts,
/// anonymous guests, and brand-new visitors alike.
class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key});

  static const eventsPage = 0;
  static const cameraPage = 1;
  static const joinPage = 2;

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen>
    with WidgetsBindingObserver {
  final _pageController = PageController(
    initialPage: HomeShellScreen.cameraPage,
  );
  int _page = HomeShellScreen.cameraPage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Never hold the camera in the background (iOS kills apps for it).
    if (state == AppLifecycleState.paused) {
      ref.read(captureControllerProvider.notifier).shutdown();
    } else if (state == AppLifecycleState.resumed) {
      _syncCamera();
    }
  }

  /// The camera runs only while the viewfinder page is front-and-center and
  /// there is an event to post into.
  void _syncCamera() {
    if (!mounted) return;
    final controller = ref.read(captureControllerProvider.notifier);
    final hasTarget = ref.read(activeEventProvider) != null;
    if (_page == HomeShellScreen.cameraPage && hasTarget) {
      controller.initialize();
    } else {
      controller.shutdown();
    }
  }

  void _goTo(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Registers the device push token (no-op until Firebase is configured).
    ref.watch(pushRegistrationProvider);
    final user = ref.watch(currentUserProvider);
    final isHost = user != null && user.isHost;
    final isAdmin = ref.watch(isAdminProvider).value ?? false;
    final unread = isHost ? ref.watch(unreadCountProvider) : 0;
    final active = ref.watch(activeEventProvider);
    final onCamera = _page == HomeShellScreen.cameraPage;

    // The camera may become startable while sitting on the viewfinder page
    // (events load async, or the active event switches).
    ref.listen(activeEventProvider, (previous, next) {
      if ((previous == null) != (next == null) ||
          previous?.event.id != next?.event.id) {
        _syncCamera();
      }
    });

    return Scaffold(
      backgroundColor: onCamera ? Colors.black : theme.colorScheme.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (page) {
              setState(() => _page = page);
              _syncCamera();
            },
            children: [
              const MyEventsPage(),
              ShellCameraPage(onJoinTap: () => _goTo(HomeShellScreen.joinPage)),
              const JoinPage(),
            ],
          ),
          // ---- Floating top overlay ----
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    _ProfileMenuButton(
                      isHost: isHost,
                      isAdmin: isAdmin,
                      unread: unread,
                      onCamera: onCamera,
                    ),
                    const Spacer(),
                    if (_page != HomeShellScreen.joinPage)
                      _OverlayPill(
                        icon: Icons.qr_code_rounded,
                        label: 'Join',
                        emphasize: onCamera,
                        onTap: () => _goTo(HomeShellScreen.joinPage),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // ---- Floating bottom bar ----
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _OverlayPill(
                      icon: Icons.photo_library_outlined,
                      label: 'Events',
                      emphasize: onCamera,
                      onTap: () => _goTo(HomeShellScreen.eventsPage),
                    ),
                    // On other pages the center button returns to the camera;
                    // on the camera page the CaptureFlow shutter sits here.
                    if (!onCamera)
                      Semantics(
                        button: true,
                        label: 'Open camera',
                        child: FloatingActionButton(
                          heroTag: 'shell-camera',
                          onPressed: () => _goTo(HomeShellScreen.cameraPage),
                          child: const Icon(Icons.photo_camera_rounded),
                        ),
                      )
                    else
                      const SizedBox(width: 56),
                    if (active != null)
                      _OverlayPill(
                        icon: Icons.collections_rounded,
                        label: 'Album',
                        emphasize: onCamera,
                        onTap: () => context.pushNamed(
                          AppRoute.album,
                          pathParameters: {'eventId': active.event.id},
                        ),
                      )
                    else
                      const SizedBox(width: 88),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scrim pill that reads over both the viewfinder and light pages.
class _OverlayPill extends StatelessWidget {
  const _OverlayPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Stronger contrast over the live camera preview.
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = emphasize
        ? Colors.black45
        : theme.colorScheme.surfaceContainerHighest;
    final foreground = emphasize ? Colors.white : theme.colorScheme.onSurface;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: foreground)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileMenuButton extends ConsumerWidget {
  const _ProfileMenuButton({
    required this.isHost,
    required this.isAdmin,
    required this.unread,
    required this.onCamera,
  });

  final bool isHost;
  final bool isAdmin;
  final int unread;
  final bool onCamera;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      tooltip: 'Profile',
      onSelected: (action) {
        switch (action) {
          case 'notifications':
            context.pushNamed(AppRoute.notifications);
          case 'settings':
            context.pushNamed(AppRoute.settings);
          case 'admin':
            context.pushNamed(AppRoute.admin);
          case 'signin':
            context.pushNamed(AppRoute.signIn);
        }
      },
      itemBuilder: (context) => [
        if (isHost)
          const PopupMenuItem(
            value: 'notifications',
            child: ListTile(
              leading: Icon(Icons.notifications_none_rounded),
              title: Text('Notifications'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (isHost)
          const PopupMenuItem(
            value: 'settings',
            child: ListTile(
              leading: Icon(Icons.settings_outlined),
              title: Text('Settings'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (isAdmin)
          const PopupMenuItem(
            value: 'admin',
            child: ListTile(
              leading: Icon(Icons.shield_outlined),
              title: Text('Admin panel'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (!isHost)
          const PopupMenuItem(
            value: 'signin',
            child: ListTile(
              leading: Icon(Icons.login_rounded),
              title: Text('Sign in'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Badge(
          isLabelVisible: unread > 0,
          label: Text('$unread'),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: onCamera
                ? Colors.black45
                : theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.person_rounded,
              color: onCamera
                  ? Colors.white
                  : theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
