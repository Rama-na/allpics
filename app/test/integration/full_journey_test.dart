import 'dart:io';

import 'package:allpics/app.dart';
import 'package:allpics/features/album/presentation/album_screen.dart';
import 'package:allpics/features/album/presentation/media_viewer_screen.dart';
import 'package:allpics/features/album/providers.dart';
import 'package:allpics/features/auth/providers.dart';
import 'package:allpics/features/events/presentation/event_dashboard_screen.dart';
import 'package:allpics/features/events/providers.dart';
import 'package:allpics/features/guest/presentation/guest_event_screen.dart';
import 'package:allpics/features/guest/providers.dart';
import 'package:allpics/features/settings/providers.dart';
import 'package:allpics/features/uploads/presentation/controllers/upload_queue_controller.dart';
import 'package:allpics/features/uploads/providers.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

/// The complete product journey in one test, exercising every layer against
/// fakes: onboarding → landing → try-first event wizard → deferred sign-up →
/// QR dashboard → guest join → uploads (incl. retry) → live album → favorite.
void main() {
  testWidgets(
    'full journey: host creates, guest joins & uploads, album lives',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final tempDir = Directory.systemTemp.createTempSync('allpics_e2e');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final auth = FakeAuthRepository();
      final events = FakeEventsRepository();
      final join = FakeJoinRepository(auth: auth);
      final uploads = FakeUploadsRepository()
        ..failuresByFileName['flaky.jpg'] = 1;
      final album = FakeAlbumRepository();
      final profile = FakeProfileRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            eventsRepositoryProvider.overrideWithValue(events),
            joinRepositoryProvider.overrideWithValue(join),
            uploadsRepositoryProvider.overrideWithValue(uploads),
            albumRepositoryProvider.overrideWithValue(album),
            profileRepositoryProvider.overrideWithValue(profile),
          ],
          child: const AllPicsApp(),
        ),
      );

      // ---- 1. Splash → onboarding → camera shell (try-first, no account) ----
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Snap into an event'), findsOneWidget);
      expect(
        find.text('Free to start — 100 uploads, 7 days. No card needed.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Create an event — free'));
      await tester.pumpAndSettle();

      // ---- 2. Build the event first; sign-up happens only on publish ----
      await tester.tap(find.text('Trip'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Goa Trip 2026');
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Create event'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create event'));
      await tester.pumpAndSettle();

      // Deferred auth sheet appears; the wizard (and its draft) stays below.
      expect(find.text('Save your event'), findsOneWidget);
      final sheetFields = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(sheetFields.at(0), 'Priya Sharma');
      await tester.enterText(sheetFields.at(1), 'priya@example.com');
      await tester.enterText(sheetFields.at(2), 'password123');
      await tester.tap(find.text('Create account & publish'));
      await tester.pumpAndSettle();

      // Dashboard shows code + QR + share.
      expect(find.byType(EventDashboardScreen), findsOneWidget);
      expect(find.text('Guests scan to join'), findsOneWidget);
      final createdEvent = (await events.watchMyEvents().first).single;
      expect(createdEvent.title, 'Goa Trip 2026');

      // ---- 3. Guest joins with the event code ----
      // (Same app instance: the fake join repo recognizes the seeded code.)
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      // Sign out via the shell's profile menu → settings.
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Sign out'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Joining an event? Enter code'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Joining an event? Enter code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'K3XR7P');
      await tester.tap(find.text('Find event'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Anita');
      await tester.ensureVisible(find.text('Join event'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join event'));
      await tester.pumpAndSettle();
      expect(find.byType(GuestEventScreen), findsOneWidget);
      expect(auth.currentUser?.isAnonymous, isTrue);

      // ---- 4. Guest uploads (one flaky file that needs retry) ----
      XFile makeFile(String name) {
        final file = File('${tempDir.path}${Platform.pathSeparator}$name')
          ..writeAsBytesSync(List.filled(2048, 7));
        return XFile(file.path);
      }

      final container = ProviderScope.containerOf(
        tester.element(find.byType(GuestEventScreen)),
      );
      await tester.runAsync(() async {
        await container.read(uploadQueueControllerProvider.notifier).addFiles(
          'event-1',
          [makeFile('beach.jpg'), makeFile('flaky.jpg')],
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(find.text('1 of 2 uploaded'), findsOneWidget);
      await tester.runAsync(() async {
        container.read(uploadQueueControllerProvider.notifier).retryAllFailed();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('2 of 2 uploaded'), findsOneWidget);
      expect(uploads.confirmed, hasLength(2));

      // ---- 5. Album lives: uploads appear, favorite round-trips ----
      // Simulate the worker marking uploads ready → album stream emits.
      album.addItem(
        FakeAlbumRepository.buildItem(
          id: 'up1',
          eventId: 'event-1',
          guestName: 'Anita',
        ),
      );
      album.addItem(
        FakeAlbumRepository.buildItem(
          id: 'up2',
          eventId: 'event-1',
          guestName: 'Anita',
          createdAt: DateTime(2026, 7, 2),
        ),
      );

      await tester.ensureVisible(find.text('View album'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View album'));
      await tester.pumpAndSettle();
      expect(find.byType(AlbumScreen), findsOneWidget);
      expect(find.text('2 items · updates live'), findsOneWidget);

      // Live update while the album is open.
      album.addItem(
        FakeAlbumRepository.buildItem(
          id: 'up3',
          eventId: 'event-1',
          guestName: 'Rahul',
          createdAt: DateTime(2026, 7, 3),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 items · updates live'), findsOneWidget);

      // Viewer: open newest, favorite it.
      await tester.tap(find.text('Rahul'));
      await tester.pumpAndSettle();
      expect(find.byType(MediaViewerScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Favourite'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove favourite'), findsOneWidget);

      album.dispose();
    },
  );
}
