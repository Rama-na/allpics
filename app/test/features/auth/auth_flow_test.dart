import 'package:allpics/app.dart';
import 'package:allpics/features/auth/presentation/sign_in_screen.dart';
import 'package:allpics/features/auth/providers.dart';
import 'package:allpics/features/shell/presentation/home_shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

Future<void> _pumpToSignIn(WidgetTester tester, FakeAuthRepository fake) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
      child: const AllPicsApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pumpAndSettle();
  // Onboarding → shell → profile menu → sign in.
  await tester.tap(find.text('Skip'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Profile'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle();
  expect(find.byType(SignInScreen), findsOneWidget);
}

void main() {
  testWidgets('host signs in and lands on the shell', (tester) async {
    final fake = FakeAuthRepository();
    await _pumpToSignIn(tester, fake);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'host@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeShellScreen), findsOneWidget);
    fake.dispose();
  });

  testWidgets('invalid form shows validation errors, no auth call', (
    tester,
  ) async {
    final fake = FakeAuthRepository();
    await _pumpToSignIn(tester, fake);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    expect(find.byType(SignInScreen), findsOneWidget);
    fake.dispose();
  });

  testWidgets('failed sign-in surfaces friendly error in a snackbar', (
    tester,
  ) async {
    final fake = FakeAuthRepository()..failSignIn = true;
    await _pumpToSignIn(tester, fake);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'host@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongpassword');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.byType(SignInScreen), findsOneWidget);
    fake.dispose();
  });

  testWidgets('returning host session lands straight on the shell', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'allpics.onboarding_seen': true});
    final fake = FakeAuthRepository(initialUser: FakeAuthRepository.host);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
        child: const AllPicsApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    expect(find.byType(HomeShellScreen), findsOneWidget);
    fake.dispose();
  });

  testWidgets('sign-up screen is reachable and validates', (tester) async {
    final fake = FakeAuthRepository();
    await _pumpToSignIn(tester, fake);

    await tester.ensureVisible(find.text('Create one'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create one'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Name is required.'), findsOneWidget);
    fake.dispose();
  });

  testWidgets('Google sign-up from the sign-up screen lands on the shell',
      (tester) async {
    final fake = FakeAuthRepository();
    await _pumpToSignIn(tester, fake);

    await tester.ensureVisible(find.text('Create one'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create one'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.tap(find.text('Continue with Google'));
    // Session arrives out-of-band via authStateChanges; router redirects.
    await tester.pumpAndSettle();

    expect(find.byType(HomeShellScreen), findsOneWidget);
    fake.dispose();
  });
}
