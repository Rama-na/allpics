import 'package:allpics/app.dart';
import 'package:allpics/features/album/presentation/album_screen.dart';
import 'package:allpics/features/album/presentation/media_viewer_screen.dart';
import 'package:allpics/features/album/providers.dart';
import 'package:allpics/features/auth/providers.dart';
import 'package:allpics/features/events/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

Future<(FakeAlbumRepository, FakeEventsRepository)> _pumpAlbum(
  WidgetTester tester,
) async {
  SharedPreferences.setMockInitialValues({'allpics.onboarding_seen': true});
  final auth = FakeAuthRepository(initialUser: FakeAuthRepository.host);
  final events = FakeEventsRepository(
    initial: [FakeEventsRepository.buildEvent(title: 'Goa Trip')],
  );
  final album = FakeAlbumRepository(
    items: [
      FakeAlbumRepository.buildItem(
        id: 'u1',
        guestName: 'Anita',
        caption: 'Beach day',
        createdAt: DateTime(2026, 7, 1),
      ),
      FakeAlbumRepository.buildItem(
        id: 'u2',
        guestName: 'Rahul',
        createdAt: DateTime(2026, 7, 2),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        eventsRepositoryProvider.overrideWithValue(events),
        albumRepositoryProvider.overrideWithValue(album),
      ],
      child: const AllPicsApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pumpAndSettle();

  // Shell → My Events page → dashboard.
  await tester.tap(find.text('Events'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Goa Trip'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('View album'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('View album'));
  await tester.pumpAndSettle();
  expect(find.byType(AlbumScreen), findsOneWidget);
  return (album, events);
}

void main() {
  testWidgets('album grid shows items with uploader names and live count', (
    tester,
  ) async {
    final (album, _) = await _pumpAlbum(tester);

    expect(find.text('Anita'), findsOneWidget);
    expect(find.text('Rahul'), findsOneWidget);
    expect(find.text('2 items · updates live'), findsOneWidget);

    // Live update: a new upload appears without navigation.
    album.addItem(
      FakeAlbumRepository.buildItem(
        id: 'u3',
        guestName: 'Priya',
        createdAt: DateTime(2026, 7, 3),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Priya'), findsOneWidget);
    expect(find.text('3 items · updates live'), findsOneWidget);
    album.dispose();
  });

  testWidgets('search filters the grid', (tester) async {
    final (album, _) = await _pumpAlbum(tester);

    await tester.enterText(find.byType(TextField), 'anita');
    await tester.pumpAndSettle();

    expect(find.text('Anita'), findsOneWidget);
    expect(find.text('Rahul'), findsNothing);
    expect(find.text('Nothing matches'), findsNothing);
    album.dispose();
  });

  testWidgets('tapping a tile opens the full-screen viewer and swipes', (
    tester,
  ) async {
    final (album, _) = await _pumpAlbum(tester);

    await tester.tap(find.text('Rahul')); // newest first → index 0
    await tester.pumpAndSettle();

    expect(find.byType(MediaViewerScreen), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.text('Beach day'), findsOneWidget); // caption of older item
    album.dispose();
  });

  testWidgets('favorite toggle in viewer updates the favorites filter', (
    tester,
  ) async {
    final (album, _) = await _pumpAlbum(tester);

    await tester.tap(find.text('Rahul'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Favourite'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove favourite'), findsOneWidget);

    // Back to grid; favorites filter shows only the favorited item.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favourites'));
    await tester.pumpAndSettle();

    expect(find.text('Rahul'), findsOneWidget);
    expect(find.text('Anita'), findsNothing);
    album.dispose();
  });

  testWidgets('empty album shows the live empty state', (tester) async {
    SharedPreferences.setMockInitialValues({'allpics.onboarding_seen': true});
    final auth = FakeAuthRepository(initialUser: FakeAuthRepository.host);
    final events = FakeEventsRepository(
      initial: [FakeEventsRepository.buildEvent(title: 'Goa Trip')],
    );
    final album = FakeAlbumRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          eventsRepositoryProvider.overrideWithValue(events),
          albumRepositoryProvider.overrideWithValue(album),
        ],
        child: const AllPicsApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goa Trip'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View album'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View album'));
    await tester.pumpAndSettle();

    expect(find.text('No photos yet'), findsOneWidget);
    album.dispose();
  });
}
