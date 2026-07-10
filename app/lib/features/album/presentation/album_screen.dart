import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/shimmer.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/album_item.dart';
import '../providers.dart';
import 'controllers/album_view_controller.dart';
import 'widgets/media_tile.dart';

/// Shared event album: live grid, sort/filter/search, downloads.
/// Visible to hosts and guests (RLS enforces membership).
class AlbumScreen extends ConsumerStatefulWidget {
  const AlbumScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  final _search = TextEditingController();
  bool _downloadingAll = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _downloadAll(List<AlbumItem> items) async {
    if (_downloadingAll || items.isEmpty) return;
    setState(() => _downloadingAll = true);
    final repo = ref.read(albumRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Cap the batch to keep the share sheet responsive.
      final batch = items.take(30).toList();
      final files = <XFile>[];
      for (final item in batch) {
        final bytes = await repo.downloadBytes(item.storagePath);
        files.add(
          XFile.fromData(
            bytes,
            name: item.storagePath.split('/').last,
            mimeType: item.isVideo ? 'video/mp4' : 'image/jpeg',
          ),
        );
      }
      await SharePlus.instance.share(ShareParams(files: files));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _downloadingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(albumItemsProvider(widget.eventId));
    final favorites = ref.watch(favoriteIdsProvider).value ?? const <String>{};
    final view = ref.watch(albumViewControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Album'),
        actions: [
          PopupMenuButton<AlbumSort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded),
            onSelected: (sort) =>
                ref.read(albumViewControllerProvider.notifier).setSort(sort),
            itemBuilder: (context) => AlbumSort.values
                .map(
                  (s) => PopupMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        if (s == view.sort)
                          const Icon(Icons.check_rounded, size: 18)
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text(s.label),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          IconButton(
            tooltip: 'Download all',
            onPressed: _downloadingAll
                ? null
                : () {
                    final items = itemsAsync.value ?? const <AlbumItem>[];
                    _downloadAll(view.apply(items, favorites));
                  },
            icon: _downloadingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: TextField(
              controller: _search,
              onChanged: (q) =>
                  ref.read(albumViewControllerProvider.notifier).setQuery(q),
              decoration: InputDecoration(
                hintText: 'Search by guest or caption',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: view.query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _search.clear();
                          ref
                              .read(albumViewControllerProvider.notifier)
                              .setQuery('');
                        },
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: AlbumFilter.values
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: FilterChip(
                          label: Text(f.label),
                          selected: view.filter == f,
                          onSelected: (_) => ref
                              .read(albumViewControllerProvider.notifier)
                              .setFilter(f),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          Expanded(
            child: itemsAsync.when(
              loading: () => const SkeletonAlbumGrid(),
              error: (error, _) => ErrorView(
                message: error is AppException
                    ? error.message
                    : 'Could not load the album.',
                onRetry: () =>
                    ref.invalidate(albumItemsProvider(widget.eventId)),
              ),
              data: (items) {
                final visible = view.apply(items, favorites);
                if (visible.isEmpty) {
                  return EmptyView(
                    icon: Icons.photo_library_outlined,
                    title: items.isEmpty ? 'No photos yet' : 'Nothing matches',
                    subtitle: items.isEmpty
                        ? 'Photos appear here live as guests upload them.'
                        : 'Try a different search or filter.',
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 140,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    return MediaTile(
                      item: item,
                      isFavorite: favorites.contains(item.id),
                      onTap: () => context.pushNamed(
                        AppRoute.mediaViewer,
                        pathParameters: {'eventId': widget.eventId},
                        extra: (items: visible, initialIndex: index),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: itemsAsync.when(
              data: (items) => Text(
                '${items.length} item${items.length == 1 ? '' : 's'} · updates live',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
