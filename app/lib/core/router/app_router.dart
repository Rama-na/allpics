import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/auth/providers.dart';
import '../../features/admin/presentation/admin_screen.dart';
import '../../features/album/domain/album_item.dart';
import '../../features/album/presentation/album_screen.dart';
import '../../features/album/presentation/media_viewer_screen.dart';
import '../../features/events/domain/event.dart';
import '../../features/events/presentation/create_event_screen.dart';
import '../../features/events/presentation/event_dashboard_screen.dart';
import '../../features/guest/presentation/guest_event_screen.dart';
import '../../features/guest/presentation/join_event_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/payments/presentation/payment_history_screen.dart';
import '../../features/payments/presentation/plans_screen.dart';
import '../../features/settings/presentation/privacy_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../config/app_env.dart';
import 'go_router_refresh_stream.dart';

/// Route names — always navigate by name to survive path refactors.
abstract final class AppRoute {
  static const splash = 'splash';
  static const onboarding = 'onboarding';
  static const signIn = 'signIn';
  static const signUp = 'signUp';
  static const join = 'join';
  static const joinDeepLink = 'joinDeepLink';
  static const guestEvent = 'guestEvent';
  static const home = 'home';
  static const createEvent = 'createEvent';
  static const eventDashboard = 'eventDashboard';
  static const editEvent = 'editEvent';
  static const album = 'album';
  static const mediaViewer = 'mediaViewer';
  static const plans = 'plans';
  static const paymentHistory = 'paymentHistory';
  static const notifications = 'notifications';
  static const admin = 'admin';
  static const settings = 'settings';
  static const privacy = 'privacy';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);

  final refresh = GoRouterRefreshStream(authRepo.authStateChanges());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final user = authRepo.currentUser;
      final loc = state.matchedLocation;

      final isHost = user != null && user.isHost;
      final onAuthPages =
          loc == '/signin' || loc == '/signup' || loc == '/onboarding';

      // Signed-in hosts skip auth/onboarding pages.
      if (isHost && onAuthPages) return '/home';

      // Host-only areas once a backend exists. In unconfigured mode the
      // shell stays reachable so UI development and tests never block.
      final hostOnly = loc == '/home' ||
          loc.startsWith('/events') ||
          loc.startsWith('/payments') ||
          loc.startsWith('/notifications') ||
          loc.startsWith('/settings') ||
          loc.startsWith('/admin');
      if (hostOnly && AppEnv.isSupabaseConfigured && !isHost) {
        return '/signin';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: AppRoute.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: AppRoute.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/signin',
        name: AppRoute.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: AppRoute.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/join',
        name: AppRoute.join,
        builder: (context, state) => const JoinEventScreen(),
      ),
      // QR / share-link deep link: https://allpics.app/j/<code-or-slug>
      GoRoute(
        path: '/j/:code',
        name: AppRoute.joinDeepLink,
        builder: (context, state) =>
            JoinEventScreen(initialCode: state.pathParameters['code']),
      ),
      GoRoute(
        path: '/guest/event/:eventId',
        name: AppRoute.guestEvent,
        builder: (context, state) =>
            GuestEventScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/home',
        name: AppRoute.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/events/new',
        name: AppRoute.createEvent,
        builder: (context, state) => const CreateEventScreen(),
      ),
      GoRoute(
        path: '/events/:eventId',
        name: AppRoute.eventDashboard,
        builder: (context, state) => EventDashboardScreen(
          eventId: state.pathParameters['eventId']!,
        ),
      ),
      GoRoute(
        path: '/events/:eventId/edit',
        name: AppRoute.editEvent,
        builder: (context, state) =>
            CreateEventScreen(existing: state.extra as Event?),
      ),
      GoRoute(
        path: '/events/:eventId/upgrade',
        name: AppRoute.plans,
        builder: (context, state) =>
            PlansScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/payments',
        name: AppRoute.paymentHistory,
        builder: (context, state) => const PaymentHistoryScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: AppRoute.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      // Role-gated in-screen: non-admins see an access-denied view.
      GoRoute(
        path: '/admin',
        name: AppRoute.admin,
        builder: (context, state) => const AdminScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: AppRoute.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/privacy',
        name: AppRoute.privacy,
        builder: (context, state) => const PrivacyScreen(),
      ),
      // Album is member-visible (host OR guest) — not under /events guard.
      GoRoute(
        path: '/album/:eventId',
        name: AppRoute.album,
        builder: (context, state) =>
            AlbumScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/album/:eventId/view',
        name: AppRoute.mediaViewer,
        builder: (context, state) {
          final args =
              state.extra as ({List<AlbumItem> items, int initialIndex});
          return MediaViewerScreen(
            items: args.items,
            initialIndex: args.initialIndex,
          );
        },
      ),
    ],
  );
});
