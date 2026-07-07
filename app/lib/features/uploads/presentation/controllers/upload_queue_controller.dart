import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/upload_queue_store.dart';
import '../../domain/upload_task.dart';
import '../../providers.dart';

/// Upload queue state: ordered tasks + processing flag.
class UploadQueueState {
  const UploadQueueState({
    this.tasks = const [],
    this.isProcessing = false,
  });

  final List<UploadTask> tasks;
  final bool isProcessing;

  int get successCount =>
      tasks.where((t) => t.status == UploadTaskStatus.success).length;
  int get failedCount =>
      tasks.where((t) => t.status == UploadTaskStatus.failed).length;
  bool get hasBlocked =>
      tasks.any((t) => t.status == UploadTaskStatus.blocked);
  bool get allDone =>
      tasks.isNotEmpty &&
      tasks.every((t) => t.isDone || t.status == UploadTaskStatus.failed) &&
      !isProcessing;

  UploadQueueState copyWith({List<UploadTask>? tasks, bool? isProcessing}) =>
      UploadQueueState(
        tasks: tasks ?? this.tasks,
        isProcessing: isProcessing ?? this.isProcessing,
      );
}

/// Drives the guest upload queue: parallel workers, per-file progress,
/// retry, offline persistence, and quota-full handling.
class UploadQueueController extends Notifier<UploadQueueState> {
  static const maxConcurrent = 3;
  static final _log = AppLogger.get('upload-queue');

  final _store = UploadQueueStore();
  int _nextLocalId = 1;
  int _active = 0;

  @override
  UploadQueueState build() {
    // Restore unfinished tasks from a previous session (mobile only).
    Future(() async {
      final restored = await _store.restore();
      if (restored.isNotEmpty) {
        state = state.copyWith(tasks: [...restored, ...state.tasks]);
        _pump();
      }
    });
    return const UploadQueueState();
  }

  /// Adds picked files to the queue and starts uploading.
  /// Unsupported types are surfaced as failed tasks (visible, not silent).
  Future<void> addFiles(String eventId, List<XFile> files) async {
    final newTasks = <UploadTask>[];
    for (final file in files) {
      final mime = (file.mimeType?.isNotEmpty ?? false)
          ? file.mimeType!
          : mimeTypeForFileName(file.name);
      final supported = isSupportedMime(mime);
      final size = file.path.isEmpty
          ? (await file.readAsBytes()).length
          : await File(file.path).length();
      newTasks.add(UploadTask(
        id: 'task-${DateTime.now().millisecondsSinceEpoch}-${_nextLocalId++}',
        eventId: eventId,
        fileName: file.name,
        mimeType: mime,
        totalBytes: size,
        kind: mediaKindForMime(mime),
        filePath: file.path.isEmpty ? null : file.path,
        inMemoryBytes: file.path.isEmpty ? await file.readAsBytes() : null,
        status: supported ? UploadTaskStatus.queued : UploadTaskStatus.failed,
        error: supported ? null : 'This file type is not supported.',
      ));
    }
    state = state.copyWith(tasks: [...state.tasks, ...newTasks]);
    await _persist();
    _pump();
  }

  /// Re-queues one failed task.
  void retry(String taskId) {
    _update(taskId,
        (t) => t.copyWith(status: UploadTaskStatus.queued, clearError: true));
    _pump();
  }

  /// Re-queues every failed task.
  void retryAllFailed() {
    state = state.copyWith(
      tasks: [
        for (final t in state.tasks)
          t.status == UploadTaskStatus.failed
              ? t.copyWith(status: UploadTaskStatus.queued, clearError: true)
              : t,
      ],
    );
    _pump();
  }

  /// Removes finished tasks from the list.
  void clearCompleted() {
    state = state.copyWith(
      tasks: state.tasks
          .where((t) => t.status != UploadTaskStatus.success)
          .toList(),
    );
    _persist();
  }

  // ---- worker pool ----

  void _pump() {
    while (_active < maxConcurrent) {
      final next = state.tasks
          .where((t) => t.status == UploadTaskStatus.queued)
          .firstOrNull;
      if (next == null) break;
      _active++;
      _update(next.id, (t) => t.copyWith(status: UploadTaskStatus.uploading));
      _run(next.id).whenComplete(() {
        _active--;
        _pump();
      });
    }
    state = state.copyWith(isProcessing: _active > 0);
  }

  Future<void> _run(String taskId) async {
    final task = _find(taskId);
    if (task == null) return;
    final repo = ref.read(uploadsRepositoryProvider);
    try {
      final bytes = await _readBytes(task);
      final slot = await repo.requestSlot(
        eventId: task.eventId,
        fileName: task.fileName,
        mimeType: task.mimeType,
        bytes: bytes.length,
      );
      _update(taskId, (t) => t.copyWith(uploadId: slot.uploadId));

      await repo.uploadBytes(
        slot: slot,
        bytes: bytes,
        mimeType: task.mimeType,
        onProgress: (p) => _update(taskId, (t) => t.copyWith(progress: p)),
      );
      await repo.confirmUploaded(slot.uploadId);
      _update(
        taskId,
        (t) => t.copyWith(status: UploadTaskStatus.success, progress: 1),
      );
    } on QuotaExceededException catch (e) {
      // Album is full: block this task AND everything still queued.
      _log.info('quota exceeded — blocking remaining queue');
      state = state.copyWith(
        tasks: [
          for (final t in state.tasks)
            (t.id == taskId ||
                    t.status == UploadTaskStatus.queued ||
                    t.status == UploadTaskStatus.uploading && t.id == taskId)
                ? t.copyWith(status: UploadTaskStatus.blocked, error: e.message)
                : t,
        ],
      );
    } on AppException catch (e) {
      _update(
        taskId,
        (t) => t.copyWith(status: UploadTaskStatus.failed, error: e.message),
      );
    } catch (e) {
      _log.warning('unexpected upload failure: $e');
      _update(
        taskId,
        (t) => t.copyWith(
          status: UploadTaskStatus.failed,
          error: 'Something went wrong. Please try again.',
        ),
      );
    } finally {
      await _persist();
    }
  }

  Future<Uint8List> _readBytes(UploadTask task) async {
    if (task.inMemoryBytes != null) return task.inMemoryBytes!;
    final path = task.filePath;
    if (path == null) {
      throw const ValidationException(
          'This file is no longer available — pick it again.');
    }
    try {
      return await File(path).readAsBytes();
    } on FileSystemException {
      throw const ValidationException(
          'This file is no longer available — pick it again.');
    }
  }

  // ---- helpers ----

  UploadTask? _find(String id) =>
      state.tasks.where((t) => t.id == id).firstOrNull;

  void _update(String id, UploadTask Function(UploadTask) transform) {
    state = state.copyWith(
      tasks: [
        for (final t in state.tasks)
          if (t.id == id) transform(t) else t,
      ],
    );
  }

  Future<void> _persist() => _store.save(state.tasks);
}

final uploadQueueControllerProvider =
    NotifierProvider<UploadQueueController, UploadQueueState>(
        UploadQueueController.new);
