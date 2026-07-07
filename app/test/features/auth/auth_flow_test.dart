import 'package:allpics/app.dart';
import 'package:allpics/features/auth/presentation/sign_in_screen.dart';
import 'package:allpics/features/auth/providers.dart';
import 'package:allpics/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

Future<void> _pumpToSignIn(WidgetTester tester, FakeAuthRepository fake) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(fake)],
    child: const AllPicsApp(),
  ));
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Skip'));
  await tester.pumpAndSettle();
  expect(find.byType(SignInScreen), findsOneWidget);
}

void main() {
  testWidgets('host signs in and lands on home with their name', (tester) async {
    final fake = FakeAuthRepository();
    await _pumpToSignIn(tester, fake);

    await tester.enterText(
        find.byType(TextFormField).at(0), 'host@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Welcome, Test Host!'), findsOneWidget);
    fake.dispose();
  });

  testWidgets('invalid form shows validation errors, no auth call',
      (tester) async {
    final fake = FakeAuthRepository();
    await _pumpToSignIn(tester, fake);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    expect(find.byType(SignInScreen), findsOneWidget);
    fake.dispose();
  });

  testWidgets('failed sign-in surfaces friendly error in a snackbar',
      (tester) async {
    final fake = FakeAuthRepository()..failSignIn = true;
    await _pumpToSignIn(tester, fake);

    await tester.enterText(
        find.byType(TextFormField).at(0), 'host@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongpassword');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.byType(SignInScreen), findsOneWidget);
    fake.dispose();
  });

  testWidgets('existing host session skips onboarding entirely',
      (tester) async {
    final fake = FakeAuthRepository(initialUser: FakeAuthRepository.host);
    await tester.pumpWidget(ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
      child: const AllPicsApp(),
    ));
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
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
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Name is required.'), findsOneWidget);
    fake.dispose();
  });
}
