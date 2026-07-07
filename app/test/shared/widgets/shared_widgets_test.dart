import 'package:allpics/shared/widgets/app_button.dart';
import 'package:allpics/shared/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('AppButton', () {
    testWidgets('fires onPressed when enabled', (tester) async {
      var pressed = false;
      await tester.pumpWidget(_wrap(
        AppButton(label: 'Go', onPressed: () => pressed = true),
      ));
      await tester.tap(find.text('Go'));
      expect(pressed, isTrue);
    });

    testWidgets('shows spinner and blocks taps while loading', (tester) async {
      var pressed = false;
      await tester.pumpWidget(_wrap(
        AppButton(label: 'Go', isLoading: true, onPressed: () => pressed = true),
      ));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Go'), findsNothing);
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      expect(pressed, isFalse);
    });
  });

  group('State views', () {
    testWidgets('ErrorView shows message and retry', (tester) async {
      var retried = false;
      await tester.pumpWidget(_wrap(
        ErrorView(message: 'Boom', onRetry: () => retried = true),
      ));
      expect(find.text('Boom'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);
    });

    testWidgets('EmptyView shows action button when provided', (tester) async {
      var acted = false;
      await tester.pumpWidget(_wrap(
        EmptyView(
          title: 'Nothing here',
          subtitle: 'Add something',
          actionLabel: 'Add',
          onAction: () => acted = true,
        ),
      ));
      expect(find.text('Nothing here'), findsOneWidget);
      await tester.tap(find.text('Add'));
      expect(acted, isTrue);
    });

    testWidgets('LoadingView shows optional message', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingView(message: 'Loading…')));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading…'), findsOneWidget);
    });
  });
}
