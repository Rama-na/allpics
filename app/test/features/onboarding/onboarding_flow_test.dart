import 'package:allpics/app.dart';
import 'package:allpics/core/router/app_router.dart';
import 'package:allpics/features/auth/presentation/sign_in_screen.dart';
import 'package:allpics/features/events/presentation/create_event_screen.dart';
import 'package:allpics/features/guest/presentation/join_event_screen.dart';
import 'package:allpics/features/onboarding/data/first_run_store.dart';
import 'package:allpics/features/onboarding/presentation/landing_screen.dart';
import 'package:allpics/features/onboarding/presentation/onboarding_screen.dart';
import 'package:allpics/features/onboarding/presentation/splash_screen.dart';
import 'package:allpics/features/onboarding/providers.dart';
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

  testWidgets('onboarding pages advance and land on the landing screen', (
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
    expect(find.byType(LandingScreen), findsOneWidget);
  });

  testWidgets('skip jumps straight to landing and persists the flag', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(LandingScreen), findsOneWidget);

    expect(await const FirstRunStore().hasSeenOnboarding(), isTrue);
  });

  testWidgets('returning visitor skips onboarding and lands on the landing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'allpics.onboarding_seen': true});
    await _pumpApp(tester);

    expect(find.byType(LandingScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('landing advertises the free tier and offers all three paths', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'allpics.onboarding_seen': true});
    await _pumpApp(tester);

    expect(
      find.text('Free to start — 10 uploads, 30 days. No card needed.'),
      findsOneWidget,
    );

    // Join an event → guest code entry, no account needed.
    await tester.ensureVisible(find.text('Join an event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join an event'));
    await tester.pumpAndSettle();
    expect(find.byType(JoinEventScreen), findsOneWidget);
  });

  testWidgets('landing create CTA opens the event wizard without sign-in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'allpics.onboarding_seen': true});
    await _pumpApp(tester);

    await tester.ensureVisible(find.text('Create an event — free'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create an event — free'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateEventScreen), findsOneWidget);
  });

  testWidgets('landing sign-in link reaches the sign-in screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'allpics.onboarding_seen': true});
    await _pumpApp(tester);

    await tester.ensureVisible(find.text('Sign in'));
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
      AppRoute.landing,
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
