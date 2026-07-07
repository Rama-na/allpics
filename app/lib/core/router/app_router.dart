import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/auth/providers.dart';
import '../../features/guest/presentation/guest_event_screen.dart';
import '../../features/guest/presentation/join_event_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
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

      // Home is host-only once a backend exists. In unconfigured mode the
      // shell stays reachable so UI development and tests never block.
      if (loc == '/home' && AppEnv.isSupabaseConfigured && !isHost) {
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
    ],
  );
});
