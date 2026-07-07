import 'package:allpics/features/album/domain/album_item.dart';
import 'package:allpics/features/album/presentation/controllers/album_view_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  final items = [
    FakeAlbumRepository.buildItem(
      id: 'u1',
      guestName: 'Anita',
      caption: 'Beach day',
      createdAt: DateTime(2026, 7, 1),
    ),
    FakeAlbumRepository.buildItem(
      id: 'u2',
      guestName: 'Rahul',
      createdAt: DateTime(2026, 7, 3),
    ),
    FakeAlbumRepository.buildItem(
      id: 'u3',
      guestName: 'Priya',
      isVideo: true,
      createdAt: DateTime(2026, 7, 2),
    ),
  ];

  test('newest sort is default', () {
    const view = AlbumViewState();
    final result = view.apply(items, const {});
    expect(result.map((i) => i.id).toList(), ['u2', 'u3', 'u1']);
  });

  test('oldest sort reverses order', () {
    const view = AlbumViewState(sort: AlbumSort.oldest);
    final result = view.apply(items, const {});
    expect(result.map((i) => i.id).toList(), ['u1', 'u3', 'u2']);
  });

  test('by-guest sorts alphabetically', () {
    const view = AlbumViewState(sort: AlbumSort.byGuest);
    final result = view.apply(items, const {});
    expect(result.map((i) => i.guestName).toList(), ['Anita', 'Priya', 'Rahul']);
  });

  test('photo and video filters', () {
    expect(
      const AlbumViewState(filter: AlbumFilter.photos)
          .apply(items, const {})
          .every((i) => !i.isVideo),
      isTrue,
    );
    final videos = const AlbumViewState(filter: AlbumFilter.videos)
        .apply(items, const {});
    expect(videos.single.id, 'u3');
  });

  test('favorites filter uses the provided id set', () {
    const view = AlbumViewState(filter: AlbumFilter.favorites);
    final result = view.apply(items, {'u1'});
    expect(result.single.id, 'u1');
  });

  test('search matches guest name and caption, case-insensitive', () {
    expect(
      const AlbumViewState(query: 'rahul').apply(items, const {}).single.id,
      'u2',
    );
    expect(
      const AlbumViewState(query: 'beach').apply(items, const {}).single.id,
      'u1',
    );
    expect(const AlbumViewState(query: 'zzz').apply(items, const {}), isEmpty);
  });
}
