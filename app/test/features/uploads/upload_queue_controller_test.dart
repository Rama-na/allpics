import 'dart:io';

import 'package:allpics/features/uploads/domain/upload_task.dart';
import 'package:allpics/features/uploads/presentation/controllers/upload_queue_controller.dart';
import 'package:allpics/features/uploads/providers.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

late Directory _tempDir;

/// XFile.fromData ignores `name` on dart:io, so tests use real temp files.
XFile _file(String name, {int size = 1024}) {
  final file = File('${_tempDir.path}${Platform.pathSeparator}$name')
    ..writeAsBytesSync(List.filled(size, 7));
  return XFile(file.path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeUploadsRepository repo;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _tempDir = Directory.systemTemp.createTempSync('allpics_upload_test');
    repo = FakeUploadsRepository();
    container = ProviderContainer(
      overrides: [uploadsRepositoryProvider.overrideWithValue(repo)],
    );
  });

  tearDown(() {
    container.dispose();
    _tempDir.deleteSync(recursive: true);
  });

  UploadQueueController controller() =>
      container.read(uploadQueueControllerProvider.notifier);

  Future<void> settle() async {
    // Let the async worker pool drain.
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(Duration.zero);
      final state = container.read(uploadQueueControllerProvider);
      if (state.tasks.isNotEmpty && !state.isProcessing) break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  test('uploads all picked files and confirms them', () async {
    await controller().addFiles('event-1', [
      _file('a.jpg'),
      _file('b.png'),
      _file('c.mp4'),
    ]);
    await settle();

    final state = container.read(uploadQueueControllerProvider);
    expect(state.tasks, hasLength(3));
    expect(
      state.tasks.every((t) => t.status == UploadTaskStatus.success),
      isTrue,
    );
    expect(state.tasks.every((t) => t.progress == 1), isTrue);
    expect(repo.confirmed, hasLength(3));
    // Media kinds inferred correctly.
    expect(
      state.tasks.map((t) => t.kind),
      containsAll([MediaKind.photo, MediaKind.video]),
    );
  });

  test('failed upload is retryable and then succeeds', () async {
    repo.failuresByFileName['a.jpg'] = 1;
    await controller().addFiles('event-1', [_file('a.jpg')]);
    await settle();

    var state = container.read(uploadQueueControllerProvider);
    expect(state.tasks.single.status, UploadTaskStatus.failed);
    expect(state.tasks.single.error, isNotNull);

    controller().retry(state.tasks.single.id);
    await settle();

    state = container.read(uploadQueueControllerProvider);
    expect(state.tasks.single.status, UploadTaskStatus.success);
    expect(repo.confirmed, hasLength(1));
  });

  test('quota exceeded blocks the task and everything queued', () async {
    repo.quotaFull = true;
    await controller().addFiles('event-1', [
      _file('a.jpg'),
      _file('b.jpg'),
      _file('c.jpg'),
      _file('d.jpg'),
    ]);
    await settle();

    final state = container.read(uploadQueueControllerProvider);
    expect(
      state.tasks.every((t) => t.status == UploadTaskStatus.blocked),
      isTrue,
    );
    expect(state.hasBlocked, isTrue);
    expect(repo.confirmed, isEmpty);
  });

  test('unsupported file types are surfaced as failed, others proceed',
      () async {
    await controller().addFiles('event-1', [
      _file('notes.txt'),
      _file('a.jpg'),
    ]);
    await settle();

    final state = container.read(uploadQueueControllerProvider);
    final txt = state.tasks.firstWhere((t) => t.fileName == 'notes.txt');
    final jpg = state.tasks.firstWhere((t) => t.fileName == 'a.jpg');
    expect(txt.status, UploadTaskStatus.failed);
    expect(txt.error, 'This file type is not supported.');
    expect(jpg.status, UploadTaskStatus.success);
  });

  test('retryAllFailed re-queues every failed task', () async {
    repo.failuresByFileName['a.jpg'] = 1;
    repo.failuresByFileName['b.jpg'] = 1;
    await controller().addFiles('event-1', [_file('a.jpg'), _file('b.jpg')]);
    await settle();

    expect(
      container.read(uploadQueueControllerProvider).failedCount,
      2,
    );
    controller().retryAllFailed();
    await settle();

    final state = container.read(uploadQueueControllerProvider);
    expect(state.successCount, 2);
    expect(state.failedCount, 0);
  });

  test('clearCompleted removes only successful tasks', () async {
    repo.failuresByFileName['bad.jpg'] = 99;
    await controller().addFiles('event-1', [_file('ok.jpg'), _file('bad.jpg')]);
    await settle();

    controller().clearCompleted();
    final state = container.read(uploadQueueControllerProvider);
    expect(state.tasks, hasLength(1));
    expect(state.tasks.single.fileName, 'bad.jpg');
  });
}
