import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/album_item.dart';

/// View options for the album grid (sort, filter, search).
class AlbumViewState {
  const AlbumViewState({
    this.sort = AlbumSort.newest,
    this.filter = AlbumFilter.all,
    this.query = '',
  });

  final AlbumSort sort;
  final AlbumFilter filter;
  final String query;

  AlbumViewState copyWith({
    AlbumSort? sort,
    AlbumFilter? filter,
    String? query,
  }) =>
      AlbumViewState(
        sort: sort ?? this.sort,
        filter: filter ?? this.filter,
        query: query ?? this.query,
      );

  /// Applies filter → search → sort over the live item list.
  List<AlbumItem> apply(List<AlbumItem> items, Set<String> favoriteIds) {
    Iterable<AlbumItem> result = items;

    result = switch (filter) {
      AlbumFilter.all => result,
      AlbumFilter.photos => result.where((i) => !i.isVideo),
      AlbumFilter.videos => result.where((i) => i.isVideo),
      AlbumFilter.favorites => result.where((i) => favoriteIds.contains(i.id)),
    };

    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((i) =>
          i.guestName.toLowerCase().contains(q) ||
          i.caption.toLowerCase().contains(q));
    }

    final list = result.toList();
    switch (sort) {
      case AlbumSort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case AlbumSort.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case AlbumSort.byGuest:
        list.sort((a, b) {
          final byName =
              a.guestName.toLowerCase().compareTo(b.guestName.toLowerCase());
          return byName != 0 ? byName : b.createdAt.compareTo(a.createdAt);
        });
    }
    return list;
  }
}

class AlbumViewController extends Notifier<AlbumViewState> {
  @override
  AlbumViewState build() => const AlbumViewState();

  void setSort(AlbumSort sort) => state = state.copyWith(sort: sort);
  void setFilter(AlbumFilter filter) => state = state.copyWith(filter: filter);
  void setQuery(String query) => state = state.copyWith(query: query);
}

final albumViewControllerProvider =
    NotifierProvider<AlbumViewController, AlbumViewState>(
        AlbumViewController.new);
