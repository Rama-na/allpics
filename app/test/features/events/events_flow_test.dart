import 'package:allpics/app.dart';
import 'package:allpics/features/auth/providers.dart';
import 'package:allpics/features/events/presentation/create_event_screen.dart';
import 'package:allpics/features/events/presentation/event_dashboard_screen.dart';
import 'package:allpics/features/events/providers.dart';
import 'package:allpics/features/shell/presentation/home_shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

Future<(FakeAuthRepository, FakeEventsRepository)> _pumpSignedIn(
  WidgetTester tester, {
  FakeEventsRepository? events,
}) async {
  SharedPreferences.setMockInitialValues({'allpics.onboarding_seen': true});
  final auth = FakeAuthRepository(initialUser: FakeAuthRepository.host);
  final repo = events ?? FakeEventsRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        eventsRepositoryProvider.overrideWithValue(repo),
      ],
      child: const AllPicsApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pumpAndSettle();
  expect(find.byType(HomeShellScreen), findsOneWidget);
  return (auth, repo);
}

/// Slides the shell from the camera home to the My Events page.
Future<void> _openEventsPage(WidgetTester tester) async {
  await tester.tap(find.text('Events'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('events page shows event cards with counters and chips', (
    tester,
  ) async {
    final repo = FakeEventsRepository(
      initial: [
        FakeEventsRepository.buildEvent(
          title: 'Goa Trip',
          guestCount: 4,
          photoCount: 7,
          videoCount: 1,
        ),
      ],
    );
    final (auth, _) = await _pumpSignedIn(tester, events: repo);

    await _openEventsPage(tester);
    expect(find.text('Goa Trip'), findsOneWidget);
    expect(find.text('4'), findsOneWidget); // guests chip
    expect(find.text('8/10'), findsOneWidget); // uploads chip
    expect(find.text('Host'), findsOneWidget); // role chip
    expect(find.text('Live'), findsOneWidget); // status chip
    auth.dispose();
    repo.dispose();
  });

  testWidgets('create event: validation, then wizard lands on dashboard', (
    tester,
  ) async {
    final (auth, repo) = await _pumpSignedIn(tester);

    // No events yet → the camera home offers create directly.
    await tester.tap(find.text('Create an event — free'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateEventScreen), findsOneWidget);

    // Empty title blocks submission.
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Create event'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create event'));
    await tester.pumpAndSettle();
    expect(find.text('Title is required.'), findsOneWidget);

    // Fill and submit.
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Anita\'s Birthday',
    );
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Create event'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create event'));
    await tester.pumpAndSettle();

    expect(find.byType(EventDashboardScreen), findsOneWidget);
    expect(find.text('Guests scan to join'), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
    expect(repo.failWrites, isFalse);
    auth.dispose();
    repo.dispose();
  });

  testWidgets('dashboard shows stats, code, and QR for an event', (
    tester,
  ) async {
    final repo = FakeEventsRepository(
      initial: [
        FakeEventsRepository.buildEvent(
          title: 'Goa Trip',
          guestCount: 4,
          photoCount: 7,
          videoCount: 1,
        ),
      ],
    );
    final (auth, _) = await _pumpSignedIn(tester, events: repo);

    await _openEventsPage(tester);
    await tester.tap(find.text('Goa Trip'));
    await tester.pumpAndSettle();

    expect(find.byType(EventDashboardScreen), findsOneWidget);
    expect(find.text('K3XR7P'), findsOneWidget); // event code
    expect(find.text('Guests'), findsOneWidget);
    expect(find.text('8/10'), findsOneWidget);
    expect(find.text('Days until expiry'), findsOneWidget);
    auth.dispose();
    repo.dispose();
  });

  testWidgets('delete event returns to the shell and removes it', (
    tester,
  ) async {
    final repo = FakeEventsRepository(
      initial: [FakeEventsRepository.buildEvent(title: 'Goa Trip')],
    );
    final (auth, _) = await _pumpSignedIn(tester, events: repo);

    await _openEventsPage(tester);
    await tester.tap(find.text('Goa Trip'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete event'));
    await tester.pumpAndSettle();

    // Confirm dialog.
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeShellScreen), findsOneWidget);
    await _openEventsPage(tester);
    expect(find.text('Goa Trip'), findsNothing);
    expect(find.text('No events yet'), findsOneWidget);
    auth.dispose();
    repo.dispose();
  });

  testWidgets('edit event pre-fills and saves changes', (tester) async {
    final repo = FakeEventsRepository(
      initial: [FakeEventsRepository.buildEvent(title: 'Goa Trip')],
    );
    final (auth, _) = await _pumpSignedIn(tester, events: repo);

    await _openEventsPage(tester);
    await tester.tap(find.text('Goa Trip'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit event'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateEventScreen), findsOneWidget);
    expect(find.text('Goa Trip'), findsOneWidget); // pre-filled

    await tester.enterText(find.byType(TextFormField).at(0), 'Goa Trip 2026');
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Save changes'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(find.byType(EventDashboardScreen), findsOneWidget);
    expect(find.text('Goa Trip 2026'), findsOneWidget);
    auth.dispose();
    repo.dispose();
  });
}
