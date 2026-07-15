import 'package:allpics/core/errors/app_exception.dart';
import 'package:allpics/features/auth/presentation/controllers/auth_controller.dart';
import 'package:allpics/features/auth/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeAuthRepository fake;
  late ProviderContainer container;

  setUp(() {
    fake = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
    );
  });

  tearDown(() {
    container.dispose();
    fake.dispose();
  });

  test('signIn success updates session and returns true', () async {
    final ok = await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'host@example.com', password: 'password123');

    expect(ok, isTrue);
    expect(container.read(authControllerProvider).hasError, isFalse);
    expect(fake.currentUser?.isHost, isTrue);
  });

  test('signIn failure exposes AppException in state', () async {
    fake.failSignIn = true;
    final ok = await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'host@example.com', password: 'wrong');

    expect(ok, isFalse);
    final state = container.read(authControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<AuthException>());
    expect(fake.currentUser, isNull);
  });

  test('signUp reports email confirmation requirement', () async {
    fake.needsEmailConfirmation = true;
    final result = await container.read(authControllerProvider.notifier).signUp(
          fullName: 'Test Host',
          email: 'host@example.com',
          password: 'password123',
        );

    expect(result, isNotNull);
    expect(result!.needsEmailConfirmation, isTrue);
    expect(fake.currentUser, isNull);
  });

  test('signInWithGoogle success clears error state and returns true',
      () async {
    final ok =
        await container.read(authControllerProvider.notifier).signInWithGoogle();

    expect(ok, isTrue);
    expect(container.read(authControllerProvider).hasError, isFalse);
    expect(fake.currentUser?.isHost, isTrue);
  });

  test('signInWithGoogle failure exposes AppException in state', () async {
    fake.failGoogle = true;
    final ok =
        await container.read(authControllerProvider.notifier).signInWithGoogle();

    expect(ok, isFalse);
    final state = container.read(authControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<AuthException>());
    expect(fake.currentUser, isNull);
  });

  test('signOut clears the session', () async {
    await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'host@example.com', password: 'password123');
    await container.read(authControllerProvider.notifier).signOut();
    expect(fake.currentUser, isNull);
  });
}
