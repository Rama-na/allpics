import 'package:allpics/app.dart';
import 'package:allpics/features/auth/presentation/sign_in_screen.dart';
import 'package:allpics/features/auth/providers.dart';
import 'package:allpics/features/events/providers.dart';
import 'package:allpics/features/settings/presentation/privacy_screen.dart';
import 'package:allpics/features/settings/presentation/settings_screen.dart';
import 'package:allpics/features/settings/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

Future<(FakeProfileRepository, FakeAuthRepository)> _pumpSettings(
  WidgetTester tester,
) async {
  SharedPreferences.setMockInitialValues({'allpics.onboarding_seen': true});
  final auth = FakeAuthRepository(initialUser: FakeAuthRepository.host);
  final events = FakeEventsRepository();
  final profile = FakeProfileRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        eventsRepositoryProvider.overrideWithValue(events),
        profileRepositoryProvider.overrideWithValue(profile),
      ],
      child: const AllPicsApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Profile'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Settings'));
  await tester.pumpAndSettle();
  expect(find.byType(SettingsScreen), findsOneWidget);
  return (profile, auth);
}

void main() {
  testWidgets('settings shows profile and edits the name', (tester) async {
    final (profile, _) = await _pumpSettings(tester);

    expect(find.text('Test Host'), findsOneWidget);
    expect(find.text('host@example.com'), findsOneWidget);

    await tester.tap(find.text('Test Host'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Priya S');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(profile.profile.fullName, 'Priya S');
    expect(find.text('Priya S'), findsOneWidget);
  });

  testWidgets('theme toggle applies dark mode instantly and syncs profile', (
    tester,
  ) async {
    final (profile, _) = await _pumpSettings(tester);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(profile.profile.theme, 'dark');
  });

  testWidgets('notification switches persist to the profile', (tester) async {
    final (profile, _) = await _pumpSettings(tester);

    await tester.ensureVisible(find.text('Guest joined'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(profile.profile.notifyGuestJoined, isFalse);
  });

  testWidgets('privacy policy screen opens from settings', (tester) async {
    await _pumpSettings(tester);

    await tester.scrollUntilVisible(find.text('Privacy policy'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyScreen), findsOneWidget);
    expect(find.text('What we collect'), findsOneWidget);
  });

  testWidgets('delete account confirms, deletes, and returns to sign-in', (
    tester,
  ) async {
    final (profile, auth) = await _pumpSettings(tester);

    await tester.scrollUntilVisible(find.text('Delete account'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    expect(find.textContaining('permanently deleted'), findsOneWidget);
    await tester.tap(find.text('Delete forever'));
    await tester.pumpAndSettle();

    expect(profile.accountDeleted, isTrue);
    expect(auth.currentUser, isNull);
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('sign out from settings returns to sign-in', (tester) async {
    final (_, auth) = await _pumpSettings(tester);

    await tester.scrollUntilVisible(find.text('Sign out'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(auth.currentUser, isNull);
    expect(find.byType(SignInScreen), findsOneWidget);
  });
}
