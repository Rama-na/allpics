import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/album_item.dart';
import '../providers.dart';

/// Full-screen media viewer: swipe between items, pinch-to-zoom photos,
/// play videos, favorite, and download/share.
class MediaViewerScreen extends ConsumerStatefulWidget {
  const MediaViewerScreen({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  final List<AlbumItem> items;
  final int initialIndex;

  @override
  ConsumerState<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends ConsumerState<MediaViewerScreen> {
  late final PageController _pageController;
  late int _index;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  AlbumItem get _current => widget.items[_index];

  Future<void> _toggleFavorite() async {
    final favorites = ref.read(favoriteIdsProvider).value ?? const <String>{};
    final isFavorite = favorites.contains(_current.id);
    try {
      await ref
          .read(albumRepositoryProvider)
          .setFavorite(_current.id, !isFavorite);
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes =
          await ref.read(albumRepositoryProvider).downloadBytes(_current.storagePath);
      await SharePlus.instance.share(ShareParams(files: [
        XFile.fromData(
          bytes,
          name: _current.storagePath.split('/').last,
          mimeType: _current.isVideo ? 'video/mp4' : 'image/jpeg',
        ),
      ]));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoriteIdsProvider).value ?? const <String>{};
    final isFavorite = favorites.contains(_current.id);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_index + 1} of ${widget.items.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: isFavorite ? 'Remove favourite' : 'Favourite',
            onPressed: _toggleFavorite,
            icon: Icon(
              isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFavorite ? Colors.redAccent : Colors.white,
            ),
          ),
          IconButton(
            tooltip: 'Download',
            onPressed: _downloading ? null : _download,
            icon: _downloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return item.isVideo
                    ? _VideoView(item: item)
                    : _PhotoView(item: item);
              },
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _current.guestName,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                Text(
                  DateFormat.yMMMd().add_jm().format(_current.createdAt),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                ),
                if (_current.caption.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _current.caption,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoView extends ConsumerWidget {
  const _PhotoView({required this.item});

  final AlbumItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(mediaUrlProvider(item.storagePath));
    return urlAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (_, _) => const Center(
        child: Icon(Icons.broken_image_outlined,
            color: Colors.white54, size: 48),
      ),
      data: (url) => InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
            errorBuilder: (_, _, _) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 48),
          ),
        ),
      ),
    );
  }
}

class _VideoView extends ConsumerStatefulWidget {
  const _VideoView({required this.item});

  final AlbumItem item;

  @override
  ConsumerState<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends ConsumerState<_VideoView> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final url = await ref
          .read(albumRepositoryProvider)
          .signedMediaUrl(widget.item.storagePath);
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load this video.');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.white70)),
      );
    }
    final controller = _controller;
    if (controller == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    return GestureDetector(
      onTap: () => setState(() {
        controller.value.isPlaying ? controller.pause() : controller.play();
      }),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          if (!controller.value.isPlaying)
            const Icon(Icons.play_circle_fill_rounded,
                size: 72, color: Colors.white70),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(controller, allowScrubbing: true),
          ),
        ],
      ),
    );
  }
}
