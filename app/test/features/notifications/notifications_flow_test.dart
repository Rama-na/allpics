import 'package:allpics/app.dart';
import 'package:allpics/features/auth/providers.dart';
import 'package:allpics/features/events/presentation/event_dashboard_screen.dart';
import 'package:allpics/features/events/providers.dart';
import 'package:allpics/features/notifications/domain/app_notification.dart';
import 'package:allpics/features/notifications/presentation/notifications_screen.dart';
import 'package:allpics/features/notifications/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

Future<FakeNotificationsRepository> _pumpHome(
  WidgetTester tester, {
  FakeNotificationsRepository? notifications,
  FakePushGateway? push,
}) async {
  final auth = FakeAuthRepository(initialUser: FakeAuthRepository.host);
  final events = FakeEventsRepository(initial: [
    FakeEventsRepository.buildEvent(title: 'Goa Trip'),
  ]);
  final repo = notifications ?? FakeNotificationsRepository();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      eventsRepositoryProvider.overrideWithValue(events),
      notificationsRepositoryProvider.overrideWithValue(repo),
      if (push != null) pushGatewayProvider.overrideWithValue(push),
    ],
    child: const AllPicsApp(),
  ));
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('unread badge shows on home and clears after mark-all-read',
      (tester) async {
    final repo = FakeNotificationsRepository(initial: [
      FakeNotificationsRepository.build(id: 'n1'),
      FakeNotificationsRepository.build(
          id: 'n2',
          type: AppNotificationType.newUploads,
          title: 'First photo is in! 📸'),
      FakeNotificationsRepository.build(id: 'n3', read: true),
    ]);
    await _pumpHome(tester, notifications: repo);

    expect(find.text('2'), findsOneWidget); // badge

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.text('Anita joined Goa Trip'), findsWidgets);
    expect(find.text('First photo is in! 📸'), findsOneWidget);

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();
    expect(find.text('Mark all read'), findsNothing);
  });

  testWidgets('tapping a notification marks it read and opens the event',
      (tester) async {
    final repo = FakeNotificationsRepository(initial: [
      FakeNotificationsRepository.build(id: 'n1'),
    ]);
    await _pumpHome(tester, notifications: repo);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Anita joined Goa Trip'));
    await tester.pumpAndSettle();

    expect(find.byType(EventDashboardScreen), findsOneWidget);
  });

  testWidgets('empty state renders', (tester) async {
    await _pumpHome(tester);
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('All caught up'), findsOneWidget);
  });

  testWidgets('swipe-to-dismiss deletes a notification', (tester) async {
    final repo = FakeNotificationsRepository(initial: [
      FakeNotificationsRepository.build(id: 'n1'),
    ]);
    await _pumpHome(tester, notifications: repo);
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    await tester.drag(
        find.text('Anita joined Goa Trip'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('All caught up'), findsOneWidget);
  });

  testWidgets('push token is registered for signed-in hosts', (tester) async {
    final push = FakePushGateway(token: 'device-token-1');
    final repo = await _pumpHome(tester, push: push);
    await tester.pumpAndSettle();

    expect(repo.registeredTokens, contains('device-token-1'));

    // Token refresh re-registers.
    push.refresh('device-token-2');
    await tester.pumpAndSettle();
    expect(repo.registeredTokens, contains('device-token-2'));
    push.dispose();
  });

  test('AppNotification parses rows and exposes event deep link', () {
    final n = AppNotification.fromMap({
      'id': 'n1',
      'type': 'payment_success',
      'title': 'Payment successful 🎉',
      'body': 'Upgrade live.',
      'data': {'event_id': 'e9', 'invoice_number': 'AP-2026-X'},
      'created_at': '2026-07-01T10:00:00Z',
      'read_at': null,
    });
    expect(n.type, AppNotificationType.paymentSuccess);
    expect(n.eventId, 'e9');
    expect(n.isRead, isFalse);
    expect(AppNotificationType.fromDb('bogus'), AppNotificationType.system);
  });
}
