import 'package:allpics/app.dart';
import 'package:allpics/features/auth/providers.dart';
import 'package:allpics/features/events/presentation/event_dashboard_screen.dart';
import 'package:allpics/features/events/providers.dart';
import 'package:allpics/features/payments/domain/payment_models.dart';
import 'package:allpics/features/payments/domain/payments_repository.dart';
import 'package:allpics/features/payments/presentation/plans_screen.dart';
import 'package:allpics/features/payments/providers.dart';
import 'package:allpics/features/settings/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

Future<(FakePaymentsRepository, FakeCheckoutGateway)> _pumpPlans(
  WidgetTester tester, {
  FakePaymentsRepository? payments,
}) async {
  SharedPreferences.setMockInitialValues({'allpics.onboarding_seen': true});
  final auth = FakeAuthRepository(initialUser: FakeAuthRepository.host);
  final events = FakeEventsRepository(
    initial: [
      FakeEventsRepository.buildEvent(title: 'Goa Trip', photoLimit: 10),
    ],
  );
  final repo = payments ?? FakePaymentsRepository();
  final gateway = FakeCheckoutGateway();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        eventsRepositoryProvider.overrideWithValue(events),
        paymentsRepositoryProvider.overrideWithValue(repo),
        checkoutGatewayProvider.overrideWithValue(gateway),
      ],
      child: const AllPicsApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pumpAndSettle();
  // Shell → My Events page → dashboard.
  await tester.tap(find.text('Events'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Goa Trip'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Upgrade plan'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Upgrade plan'));
  await tester.pumpAndSettle();
  expect(find.byType(PlansScreen), findsOneWidget);
  return (repo, gateway);
}

void main() {
  testWidgets('plans screen lists the catalog and marks the current plan', (
    tester,
  ) async {
    await _pumpPlans(tester);

    expect(find.text('Basic'), findsOneWidget);
    expect(find.text('₹199'), findsOneWidget);
    // Event carries the free plan id (p0) → marked current.
    expect(find.text('Current plan'), findsOneWidget);
    expect(find.text('Get Basic'), findsOneWidget);

    // Lower plans render after scrolling.
    await tester.scrollUntilVisible(find.text('Premium'), 300);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('₹799'), findsOneWidget);
  });

  testWidgets('successful checkout shows the success state and returns', (
    tester,
  ) async {
    final (repo, gateway) = await _pumpPlans(tester);

    await tester.scrollUntilVisible(find.text('Get Plus'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Plus'));
    await tester.pumpAndSettle();

    // Order created for the right plan and checkout opened with server key.
    expect(repo.orders.single.$2, 'plus');
    expect(gateway.opened.single.keyId, 'rzp_test_key');

    expect(find.text('Payment received!'), findsOneWidget);

    await tester.tap(find.text('Back to dashboard'));
    await tester.pumpAndSettle();
    expect(find.byType(EventDashboardScreen), findsOneWidget);
  });

  testWidgets('cancelled checkout surfaces a message and recovers', (
    tester,
  ) async {
    final (_, gateway) = await _pumpPlans(tester);
    gateway.next = const CheckoutResult.cancelled();

    await tester.ensureVisible(find.text('Get Basic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Basic'));
    await tester.pumpAndSettle();

    expect(find.text('Payment cancelled.'), findsOneWidget); // snackbar
    expect(find.byType(PlansScreen), findsOneWidget); // still purchasable
  });

  testWidgets('order failure surfaces the server message', (tester) async {
    final repo = FakePaymentsRepository()..failOrders = true;
    await _pumpPlans(tester, payments: repo);

    await tester.ensureVisible(find.text('Get Basic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Basic'));
    await tester.pumpAndSettle();

    expect(find.text('Could not start the payment.'), findsOneWidget);
  });

  testWidgets('payment history lists payments with invoice numbers', (
    tester,
  ) async {
    final repo = FakePaymentsRepository()
      ..history = [
        Payment(
          id: 'pay-1',
          eventId: 'event-1',
          eventTitle: 'Goa Trip',
          planName: 'Plus',
          amountInr: 29900,
          status: PaymentStatus.captured,
          createdAt: DateTime(2026, 7, 1, 10, 30),
          invoiceNumber: 'AP-2026-ABCD1234',
        ),
      ];
    final auth = FakeAuthRepository(initialUser: FakeAuthRepository.host);
    final events = FakeEventsRepository(
      initial: [FakeEventsRepository.buildEvent(title: 'Goa Trip')],
    );
    SharedPreferences.setMockInitialValues({'allpics.onboarding_seen': true});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          eventsRepositoryProvider.overrideWithValue(events),
          paymentsRepositoryProvider.overrideWithValue(repo),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        ],
        child: const AllPicsApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    // Payment history lives under Settings (via the profile menu).
    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Payment history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payment history'));
    await tester.pumpAndSettle();

    expect(find.text('Plus — Goa Trip'), findsOneWidget);
    expect(find.text('₹299'), findsOneWidget);
    expect(find.textContaining('AP-2026-ABCD1234'), findsOneWidget);

    // Detail dialog opens with full information.
    await tester.tap(find.text('Plus — Goa Trip'));
    await tester.pumpAndSettle();
    expect(find.text('Payment details'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
  });
}
