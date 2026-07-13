import 'package:allpics/app.dart';
import 'package:allpics/features/album/presentation/album_screen.dart';
import 'package:allpics/features/album/providers.dart';
import 'package:allpics/features/auth/providers.dart';
import 'package:allpics/features/events/providers.dart';
import 'package:allpics/features/shell/presentation/home_shell_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

/// The camera plugin is absent in tests: enumeration times out → the shell
/// renders the branded unavailable view instead of a live preview.
Future<void> _pumpShell(
  WidgetTester tester, {
  FakeAuthRepository? auth,
  FakeEventsRepository? events,
  FakeAlbumRepository? album,
}) async {
  SharedPreferences.setMockInitialValues({'allpics.onboarding_seen': true});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
        eventsRepositoryProvider.overrideWithValue(
          events ?? FakeEventsRepository(),
        ),
        if (album != null) albumRepositoryProvider.overrideWithValue(album),
      ],
      child: const AllPicsApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pumpAndSettle();
  expect(find.byType(HomeShellScreen), findsOneWidget);
}

void main() {
  testWidgets('signed-out shell opens on the camera page with join/create', (
    tester,
  ) async {
    await _pumpShell(tester);

    // No events → invite view with both entry actions and free-tier copy.
    expect(find.text('Snap into an event'), findsOneWidget);
    expect(find.text('Join an event'), findsOneWidget);
    expect(find.text('Create an event — free'), findsOneWidget);
  });

  testWidgets('signed-out events page shows empty state and sign-in', (
    tester,
  ) async {
    await _pumpShell(tester);

    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    expect(find.text('No events yet'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);

    // Center camera button returns to the viewfinder page.
    await tester.tap(find.bySemanticsLabel('Open camera'));
    await tester.pumpAndSettle();
    expect(find.text('Snap into an event'), findsOneWidget);
  });

  testWidgets('host with a live event gets the viewfinder page (unavailable '
      'placeholder in tests) and the Album shortcut', (tester) async {
    final auth = FakeAuthRepository(initialUser: FakeAuthRepository.host);
    final events = FakeEventsRepository(
      initial: [FakeEventsRepository.buildEvent(title: 'Goa Trip')],
    );
    await _pumpShell(tester, auth: auth, events: events);

    // Camera enumeration fails in tests → branded unavailable view.
    expect(
      find.textContaining('No camera available on this device.'),
      findsOneWidget,
    );
    expect(find.text('Album'), findsOneWidget);
    auth.dispose();
    events.dispose();
  });

  testWidgets('unified events list shows hosted and joined with chips', (
    tester,
  ) async {
    final auth = FakeAuthRepository(initialUser: FakeAuthRepository.host);
    final events = FakeEventsRepository(
      initial: [FakeEventsRepository.buildEvent(title: 'My Wedding')],
    )..joinedEvents = [
        FakeEventsRepository.buildEvent(
          id: 'event-9',
          title: "Rahul's Farewell",
          expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];
    await _pumpShell(tester, auth: auth, events: events);

    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();

    expect(find.text('My Wedding'), findsOneWidget);
    expect(find.text("Rahul's Farewell"), findsOneWidget);
    expect(find.text('Host'), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Ended'), findsOneWidget);
    auth.dispose();
    events.dispose();
  });

  testWidgets('join pill slides to the code entry page', (tester) async {
    await _pumpShell(tester);

    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the event code'), findsOneWidget);
  });

  testWidgets('album shortcut opens the active event album', (tester) async {
    final auth = FakeAuthRepository(initialUser: FakeAuthRepository.host);
    final events = FakeEventsRepository(
      initial: [FakeEventsRepository.buildEvent(title: 'Goa Trip')],
    );
    final album = FakeAlbumRepository();
    await _pumpShell(tester, auth: auth, events: events, album: album);

    await tester.tap(find.text('Album'));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumScreen), findsOneWidget);
    auth.dispose();
    events.dispose();
    album.dispose();
  });
}
