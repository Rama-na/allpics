import 'package:allpics/app.dart';
import 'package:allpics/core/router/app_router.dart';
import 'package:allpics/features/auth/presentation/sign_in_screen.dart';
import 'package:allpics/features/events/presentation/create_event_screen.dart';
import 'package:allpics/features/onboarding/data/first_run_store.dart';
import 'package:allpics/features/onboarding/presentation/onboarding_screen.dart';
import 'package:allpics/features/onboarding/presentation/splash_screen.dart';
import 'package:allpics/features/onboarding/providers.dart';
import 'package:allpics/features/shell/presentation/home_shell_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: AllPicsApp()));
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('splash shows brand then routes to onboarding on first run', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: AllPicsApp()));

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('AllPics'), findsOneWidget);
    expect(find.text('Every Photo. One Album.'), findsOneWidget);

    // Let the splash timer + transition complete.
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('onboarding pages advance and land on the camera shell', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text('One QR for every guest'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('No app, no account'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Free to try, upgrade anytime'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeShellScreen), findsOneWidget);
  });

  testWidgets('skip jumps straight to the shell and persists the flag', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeShellScreen), findsOneWidget);

    expect(await const FirstRunStore().hasSeenOnboarding(), isTrue);
  });

  testWidgets('returning visitor skips onboarding and lands on the shell', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'allpics.onboarding_seen': true});
    await _pumpApp(tester);

    expect(find.byType(HomeShellScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('camera home advertises the free tier and offers join/create', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'allpics.onboarding_seen': true});
    await _pumpApp(tester);

    // No events yet → the camera page invites join/create with free copy.
    expect(find.text('Snap into an event'), findsOneWidget);
    expect(
      find.text('Free to start — 100 uploads, 7 days. No card needed.'),
      findsOneWidget,
    );

    // Join an event → slides to the in-shell join page.
    await tester.tap(find.text('Join an event'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the event code'), findsOneWidget);
  });

  testWidgets('create CTA opens the event wizard without sign-in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'allpics.onboarding_seen': true});
    await _pumpApp(tester);

    await tester.tap(find.text('Create an event — free'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateEventScreen), findsOneWidget);
  });

  testWidgets('profile menu reaches the sign-in screen when signed out', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'allpics.onboarding_seen': true});
    await _pumpApp(tester);

    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  test('first-run store round-trips', () async {
    SharedPreferences.setMockInitialValues({});
    const store = FirstRunStore();
    expect(await store.hasSeenOnboarding(), isFalse);
    await store.markOnboardingSeen();
    expect(await store.hasSeenOnboarding(), isTrue);
  });

  test('firstRunStoreProvider exposes a store', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(firstRunStoreProvider), isA<FirstRunStore>());
  });

  test('route names are unique', () {
    const names = [
      AppRoute.splash,
      AppRoute.onboarding,
      AppRoute.capture,
      AppRoute.signIn,
      AppRoute.signUp,
      AppRoute.join,
      AppRoute.joinDeepLink,
      AppRoute.guestEvent,
      AppRoute.home,
    ];
    expect(names.toSet().length, names.length);
  });
}
