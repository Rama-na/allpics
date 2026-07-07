import 'package:allpics/app.dart';
import 'package:allpics/core/router/app_router.dart';
import 'package:allpics/features/auth/presentation/sign_in_screen.dart';
import 'package:allpics/features/onboarding/presentation/onboarding_screen.dart';
import 'package:allpics/features/onboarding/presentation/splash_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('splash shows brand then routes to onboarding', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AllPicsApp()));

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('AllPics'), findsOneWidget);
    expect(find.text('Every Photo. One Album.'), findsOneWidget);

    // Let the splash timer + transition complete.
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('onboarding pages advance and land on sign-in', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AllPicsApp()));
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    expect(find.text('One QR for every guest'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('No app, no account'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('A beautiful shared album'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('skip jumps straight to sign-in', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AllPicsApp()));
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  test('route names are unique', () {
    const names = [
      AppRoute.splash,
      AppRoute.onboarding,
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
