import 'dart:io';

import 'package:allpics/app.dart';
import 'package:allpics/features/auth/providers.dart';
import 'package:allpics/features/guest/presentation/guest_event_screen.dart';
import 'package:allpics/features/guest/providers.dart';
import 'package:allpics/features/uploads/presentation/controllers/upload_queue_controller.dart';
import 'package:allpics/features/uploads/providers.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

Future<ProviderContainer> _pumpJoined(
  WidgetTester tester,
  FakeUploadsRepository uploads,
) async {
  SharedPreferences.setMockInitialValues({});
  final auth = FakeAuthRepository();
  final join = FakeJoinRepository(auth: auth);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        joinRepositoryProvider.overrideWithValue(join),
        uploadsRepositoryProvider.overrideWithValue(uploads),
      ],
      child: const AllPicsApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Skip'));
  await tester.pumpAndSettle();
  // Landing promotes joining to a first-class action.
  await tester.ensureVisible(find.text('Join an event'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Join an event'));
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
  return ProviderScope.containerOf(
    tester.element(find.byType(GuestEventScreen)),
  );
}

XFile _file(String name) {
  final dir = Directory.systemTemp.createTempSync('allpics_panel_test');
  final file = File('${dir.path}${Platform.pathSeparator}$name')
    ..writeAsBytesSync(List.filled(2048, 7));
  return XFile(file.path);
}

void main() {
  testWidgets('joined guest sees the upload panel and uploads files', (
    tester,
  ) async {
    final uploads = FakeUploadsRepository();
    final container = await _pumpJoined(tester, uploads);

    expect(find.text('Add photos & videos'), findsOneWidget);

    // Drive the queue directly (the OS picker cannot open in tests).
    // runAsync: the queue reads real temp files, which needs real async I/O.
    await tester.runAsync(() async {
      await container.read(uploadQueueControllerProvider.notifier).addFiles(
        'event-1',
        [_file('beach.jpg'), _file('sunset.jpg')],
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('2 of 2 uploaded'), findsOneWidget);
    expect(find.text('beach.jpg'), findsOneWidget);
    expect(find.text('All uploads complete. Thank you!'), findsOneWidget);
    expect(uploads.confirmed, hasLength(2));
  });

  testWidgets('failed upload shows retry and recovers', (tester) async {
    final uploads = FakeUploadsRepository()..failuresByFileName['bad.jpg'] = 1;
    final container = await _pumpJoined(tester, uploads);

    await tester.runAsync(() async {
      await container.read(uploadQueueControllerProvider.notifier).addFiles(
        'event-1',
        [_file('bad.jpg')],
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('0 of 1 uploaded'), findsOneWidget);
    expect(find.byTooltip('Retry'), findsOneWidget);

    await tester.runAsync(() async {
      container.read(uploadQueueControllerProvider.notifier).retryAllFailed();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('1 of 1 uploaded'), findsOneWidget);
  });

  testWidgets('quota exhaustion shows the album-full message', (tester) async {
    final uploads = FakeUploadsRepository()..quotaFull = true;
    final container = await _pumpJoined(tester, uploads);

    await tester.runAsync(() async {
      await container.read(uploadQueueControllerProvider.notifier).addFiles(
        'event-1',
        [_file('a.jpg')],
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(
      find.textContaining('This album has hit its upload limit'),
      findsOneWidget,
    );
  });
}
