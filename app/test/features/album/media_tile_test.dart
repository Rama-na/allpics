import 'package:allpics/features/album/presentation/widgets/media_tile.dart';
import 'package:allpics/features/album/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

Future<void> _pumpTile(WidgetTester tester, Widget tile) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        albumRepositoryProvider.overrideWithValue(FakeAlbumRepository()),
      ],
      child: MaterialApp(
        home: Scaffold(body: SizedBox(width: 140, height: 140, child: tile)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('video tile renders the worker thumbnail with a play badge', (
    tester,
  ) async {
    final item = FakeAlbumRepository.buildItem(
      id: 'v1',
      isVideo: true,
      thumbPath: 'thumbs/event-1/v1.jpg',
    );
    await _pumpTile(tester, MediaTile(item: item, isFavorite: false));

    // Thumbnail image is wired (network load fails in tests, but the Image
    // widget proves the thumb path is used) + play badge overlay.
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('video tile without a thumbnail falls back to a plain badge', (
    tester,
  ) async {
    final item = FakeAlbumRepository.buildItem(id: 'v2', isVideo: true);
    await _pumpTile(tester, MediaTile(item: item, isFavorite: false));

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('photo tile renders the image without a play badge', (
    tester,
  ) async {
    final item = FakeAlbumRepository.buildItem(id: 'p1');
    await _pumpTile(tester, MediaTile(item: item, isFavorite: false));

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
  });

  testWidgets('tile exposes a descriptive semantics label', (tester) async {
    final item = FakeAlbumRepository.buildItem(
      id: 'v3',
      isVideo: true,
      guestName: 'Rahul',
    );
    await _pumpTile(
      tester,
      MediaTile(item: item, isFavorite: true, onTap: () {}),
    );

    expect(
      find.bySemanticsLabel(RegExp('Video by Rahul, favourite.*')),
      findsOneWidget,
    );
  });
}
