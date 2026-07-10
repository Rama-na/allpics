import 'package:allpics/app.dart';
import 'package:allpics/features/auth/providers.dart';
import 'package:allpics/features/events/presentation/event_dashboard_screen.dart';
import 'package:allpics/features/events/providers.dart';
import 'package:allpics/features/home/presentation/home_screen.dart';
import 'package:allpics/features/payments/domain/plan_presentation.dart';
import 'package:allpics/features/payments/presentation/plans_screen.dart';
import 'package:allpics/features/payments/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required int photoCount,
}) async {
  final auth = FakeAuthRepository(initialUser: FakeAuthRepository.host);
  final events = FakeEventsRepository(
    initial: [
      FakeEventsRepository.buildEvent(
        title: 'Goa Trip',
        photoCount: photoCount,
        photoLimit: 10,
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        eventsRepositoryProvider.overrideWithValue(events),
        paymentsRepositoryProvider.overrideWithValue(FakePaymentsRepository()),
      ],
      child: const AllPicsApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Goa Trip'));
  await tester.pumpAndSettle();
}

void main() {
  group('PlanPresentation', () {
    test('marks Plus as the popular plan', () {
      final popular = FakePaymentsRepository.plans
          .where((p) => p.isPopular)
          .toList();
      expect(popular, hasLength(1));
      expect(popular.single.code, 'plus');
    });

    test('frames per-upload value from price and limit', () {
      final basic = FakePaymentsRepository.plans.firstWhere(
        (p) => p.code == 'basic',
      );
      final plus = FakePaymentsRepository.plans.firstWhere(
        (p) => p.code == 'plus',
      );
      final free = FakePaymentsRepository.plans.firstWhere(
        (p) => p.code == 'free',
      );
      expect(basic.perUploadLabel, '₹1.6/upload');
      expect(plus.perUploadLabel, '₹0.60/upload');
      expect(free.perUploadLabel, isEmpty);
    });

    test('every plan gets bullets and a tagline', () {
      for (final plan in FakePaymentsRepository.plans) {
        expect(plan.bullets, isNotEmpty, reason: plan.code);
        expect(plan.tagline, isNotEmpty, reason: plan.code);
      }
    });
  });

  testWidgets('plans screen highlights the popular plan and shows usage', (
    tester,
  ) async {
    await _pumpDashboard(tester, photoCount: 3);

    await tester.ensureVisible(find.text('Upgrade plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upgrade plan'));
    await tester.pumpAndSettle();
    expect(find.byType(PlansScreen), findsOneWidget);

    expect(find.text('3 of 10 uploads used'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('MOST POPULAR'), 300);
    expect(find.text('MOST POPULAR'), findsOneWidget);
    // Plus (and possibly Premium, once built) share the ₹0.60 framing.
    expect(find.text('₹0.60/upload'), findsWidgets);
  });

  testWidgets('dashboard nudges the upgrade sheet once when nearly full', (
    tester,
  ) async {
    await _pumpDashboard(tester, photoCount: 8);

    // Contextual sheet fires at >=80% usage.
    expect(find.text('Your album is 80% full'), findsOneWidget);
    expect(find.textContaining('Only 2 uploads left'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Your album is 80% full'), findsNothing);

    // The persistent banner stays on the dashboard.
    expect(
      find.textContaining('8 of 10 uploads used — upgrade'),
      findsOneWidget,
    );

    // Re-entering the dashboard does not re-fire the sheet this session.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.tap(find.text('Goa Trip'));
    await tester.pumpAndSettle();
    expect(find.byType(EventDashboardScreen), findsOneWidget);
    expect(find.text('Your album is 80% full'), findsNothing);
  });

  testWidgets('quiet dashboards get no nudge and no banner', (tester) async {
    await _pumpDashboard(tester, photoCount: 3);

    expect(find.textContaining('Your album is'), findsNothing);
    expect(find.textContaining('upgrade before the album fills'), findsNothing);
  });
}
