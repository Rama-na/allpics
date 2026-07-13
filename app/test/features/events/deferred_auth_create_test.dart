import 'package:allpics/app.dart';
import 'package:allpics/features/auth/providers.dart';
import 'package:allpics/features/events/presentation/create_event_screen.dart';
import 'package:allpics/features/events/presentation/event_dashboard_screen.dart';
import 'package:allpics/features/events/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

/// Try-first flow: anyone can build an event; the account is requested only
/// when they hit "Create event".
Future<(FakeAuthRepository, FakeEventsRepository)> _pumpToWizardSignedOut(
  WidgetTester tester,
) async {
  SharedPreferences.setMockInitialValues({'allpics.onboarding_seen': true});
  final auth = FakeAuthRepository();
  final events = FakeEventsRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        eventsRepositoryProvider.overrideWithValue(events),
      ],
      child: const AllPicsApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pumpAndSettle();

  await tester.ensureVisible(find.text('Create an event — free'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Create an event — free'));
  await tester.pumpAndSettle();
  expect(find.byType(CreateEventScreen), findsOneWidget);
  return (auth, events);
}

Future<void> _fillTitleAndSubmit(WidgetTester tester, String title) async {
  await tester.enterText(find.byType(TextFormField).at(0), title);
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Create event'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Create event'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signed-out create shows the auth sheet, then publishes', (
    tester,
  ) async {
    final (auth, events) = await _pumpToWizardSignedOut(tester);

    await _fillTitleAndSubmit(tester, "Anita's Birthday");

    // The deferred auth sheet appears over the intact wizard.
    expect(find.text('Save your event'), findsOneWidget);
    expect(find.textContaining('Free plan included'), findsOneWidget);

    final sheetFields = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(sheetFields.at(0), 'Priya Sharma');
    await tester.enterText(sheetFields.at(1), 'priya@example.com');
    await tester.enterText(sheetFields.at(2), 'password123');
    await tester.tap(find.text('Create account & publish'));
    await tester.pumpAndSettle();

    // Form survived under the modal: the published event kept its title.
    expect(find.byType(EventDashboardScreen), findsOneWidget);
    final created = (await events.watchMyEvents().first).single;
    expect(created.title, "Anita's Birthday");
    expect(auth.currentUser?.isHost, isTrue);
    auth.dispose();
    events.dispose();
  });

  testWidgets(
    'dismissing the auth sheet publishes nothing and keeps the form',
    (tester) async {
      final (auth, events) = await _pumpToWizardSignedOut(tester);

      await _fillTitleAndSubmit(tester, "Anita's Birthday");
      expect(find.text('Save your event'), findsOneWidget);

      // Swipe the sheet away.
      await tester.tapAt(const Offset(400, 20));
      await tester.pumpAndSettle();

      expect(find.byType(CreateEventScreen), findsOneWidget);
      expect(find.text("Anita's Birthday"), findsOneWidget); // draft intact
      expect(await events.watchMyEvents().first, isEmpty);
      auth.dispose();
      events.dispose();
    },
  );

  testWidgets('signed-in hosts never see the auth sheet', (tester) async {
    SharedPreferences.setMockInitialValues({'allpics.onboarding_seen': true});
    final auth = FakeAuthRepository(initialUser: FakeAuthRepository.host);
    final events = FakeEventsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          eventsRepositoryProvider.overrideWithValue(events),
        ],
        child: const AllPicsApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create an event — free'));
    await tester.pumpAndSettle();
    await _fillTitleAndSubmit(tester, 'Goa Trip');

    expect(find.text('Save your event'), findsNothing);
    expect(find.byType(EventDashboardScreen), findsOneWidget);
    auth.dispose();
    events.dispose();
  });
}
