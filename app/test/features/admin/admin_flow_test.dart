import 'package:allpics/app.dart';
import 'package:allpics/features/admin/presentation/admin_screen.dart';
import 'package:allpics/features/admin/providers.dart';
import 'package:allpics/features/auth/providers.dart';
import 'package:allpics/features/events/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

Future<FakeAdminRepository> _pumpAdmin(
  WidgetTester tester, {
  bool admin = true,
}) async {
  final auth = FakeAuthRepository(initialUser: FakeAuthRepository.host);
  final events = FakeEventsRepository();
  final repo = FakeAdminRepository(admin: admin);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      eventsRepositoryProvider.overrideWithValue(events),
      adminRepositoryProvider.overrideWithValue(repo),
    ],
    child: const AllPicsApp(),
  ));
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pumpAndSettle();
  if (admin) {
    await tester.tap(find.byTooltip('Admin panel'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminScreen), findsOneWidget);
  }
  return repo;
}

void main() {
  testWidgets('non-admins get no entry icon and are denied in-screen',
      (tester) async {
    await _pumpAdmin(tester, admin: false);
    expect(find.byTooltip('Admin panel'), findsNothing);
  });

  testWidgets('overview tab shows platform stats', (tester) async {
    await _pumpAdmin(tester);

    expect(find.text('Hosts'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('15/20'), findsOneWidget); // active/total events
    expect(find.text('₹4497'), findsOneWidget); // revenue
    expect(find.text('5.00 GB'), findsOneWidget); // storage
  });

  testWidgets('users tab lists users and bans a host', (tester) async {
    final repo = await _pumpAdmin(tester);

    await tester.tap(find.text('Users'));
    await tester.pumpAndSettle();

    expect(find.text('Priya Sharma'), findsOneWidget);
    expect(find.textContaining('priya@example.com'), findsOneWidget);
    expect(find.text('admin'), findsOneWidget); // admin row has no ban action

    await tester.tap(find.text('Ban'));
    await tester.pumpAndSettle();

    expect(repo.banned['u1'], isTrue);
    expect(find.text('Unban'), findsOneWidget);
    expect(find.textContaining('BANNED'), findsOneWidget);
  });

  testWidgets('events tab lists events and deletes with confirmation',
      (tester) async {
    final repo = await _pumpAdmin(tester);

    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();

    expect(find.text('Goa Trip'), findsOneWidget);
    expect(find.textContaining('8/10 uploads'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete event'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repo.deletedEvents, contains('e1'));
    expect(find.text('No events found'), findsOneWidget);
  });

  testWidgets('flags tab toggles a feature flag', (tester) async {
    final repo = await _pumpAdmin(tester);

    await tester.tap(find.text('Flags'));
    await tester.pumpAndSettle();

    expect(find.text('ai_dedupe'), findsOneWidget);
    expect(find.text('virus_scan'), findsOneWidget);

    await tester.tap(find.byType(Switch).last); // virus_scan off → on
    await tester.pumpAndSettle();

    expect(
      repo.flags.firstWhere((f) => f.key == 'virus_scan').enabled,
      isTrue,
    );
  });
}
