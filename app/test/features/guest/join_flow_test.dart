import 'package:allpics/app.dart';
import 'package:allpics/features/auth/providers.dart';
import 'package:allpics/features/guest/presentation/guest_event_screen.dart';
import 'package:allpics/features/guest/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

Future<(FakeAuthRepository, FakeJoinRepository)> _pumpToJoin(
  WidgetTester tester,
) async {
  SharedPreferences.setMockInitialValues({});
  final auth = FakeAuthRepository();
  final join = FakeJoinRepository(auth: auth);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        joinRepositoryProvider.overrideWithValue(join),
      ],
      child: const AllPicsApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Skip'));
  await tester.pumpAndSettle();
  // Camera home → slide to the in-shell Join page.
  await tester.tap(find.text('Join an event'));
  await tester.pumpAndSettle();
  expect(find.text('Enter the event code'), findsOneWidget);
  return (auth, join);
}

void main() {
  testWidgets('guest joins with code → preview → name → joined screen', (
    tester,
  ) async {
    final (auth, _) = await _pumpToJoin(tester);

    await tester.enterText(find.byType(TextFormField), 'K3XR7P');
    await tester.tap(find.text('Find event'));
    await tester.pumpAndSettle();

    // Event preview visible with quota info.
    expect(find.text("Priya & Rahul's Wedding"), findsOneWidget);
    expect(find.text('15 / 500 uploads used'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Anita');
    await tester.ensureVisible(find.text('Join event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join event'));
    await tester.pumpAndSettle();

    expect(find.byType(GuestEventScreen), findsOneWidget);
    expect(find.textContaining("You're in, Anita!"), findsOneWidget);
    // Anonymous session was created for the guest.
    expect(auth.currentUser?.isAnonymous, isTrue);
    // Guest→host growth loop CTA is present.
    await tester.scrollUntilVisible(
      find.text('Create your own event — free'),
      300,
    );
    expect(find.text('Create your own event — free'), findsOneWidget);
    auth.dispose();
  });

  testWidgets('unknown code shows a friendly error', (tester) async {
    final (auth, _) = await _pumpToJoin(tester);

    await tester.enterText(find.byType(TextFormField), 'WRONG1');
    await tester.tap(find.text('Find event'));
    await tester.pumpAndSettle();

    expect(
      find.text('No active event found for that code. Check with your host.'),
      findsOneWidget,
    );
    auth.dispose();
  });

  testWidgets('joining requires a name', (tester) async {
    final (auth, _) = await _pumpToJoin(tester);

    await tester.enterText(find.byType(TextFormField), 'K3XR7P');
    await tester.tap(find.text('Find event'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Join event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join event'));
    await tester.pumpAndSettle();
    expect(find.text('Name is required.'), findsOneWidget);
    auth.dispose();
  });
}
