import 'dart:async';

import 'package:allpics/core/errors/app_exception.dart';
import 'package:allpics/features/auth/domain/auth_repository.dart';
import 'package:allpics/features/auth/domain/auth_user.dart';
import 'package:allpics/features/guest/domain/join_repository.dart';
import 'package:allpics/features/guest/domain/joinable_event.dart';

/// In-memory [AuthRepository] for widget/unit tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? initialUser}) : _current = initialUser;

  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;

  bool failSignIn = false;
  bool needsEmailConfirmation = false;

  static const host = AuthUser(
    id: 'host-1',
    isAnonymous: false,
    email: 'host@example.com',
    fullName: 'Test Host',
  );

  void _emit(AuthUser? user) {
    _current = user;
    _controller.add(user);
  }

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  AuthUser? get currentUser => _current;

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (failSignIn) {
      throw const AuthException('Incorrect email or password.');
    }
    _emit(host);
    return host;
  }

  @override
  Future<SignUpResult> signUpWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (!needsEmailConfirmation) _emit(host);
    return SignUpResult(needsEmailConfirmation: needsEmailConfirmation);
  }

  @override
  Future<void> signInWithGoogle() async => _emit(host);

  @override
  Future<AuthUser> signInAnonymously() async {
    final existing = _current;
    if (existing != null) return existing;
    const anon = AuthUser(id: 'guest-1', isAnonymous: true);
    _emit(anon);
    return anon;
  }

  @override
  Future<void> signOut() async => _emit(null);

  void dispose() => _controller.close();
}

/// In-memory [JoinRepository]. Knows one event, code `K3XR7P`.
/// Mirrors production behavior: joining creates an anonymous session first.
class FakeJoinRepository implements JoinRepository {
  FakeJoinRepository({this.auth});

  final FakeAuthRepository? auth;

  static const knownCode = 'K3XR7P';

  static const event = JoinableEvent(
    id: 'event-1',
    title: 'Priya & Rahul\'s Wedding',
    description: 'Share your favorite moments!',
    type: 'wedding',
    location: 'Bengaluru',
    photoCount: 12,
    videoCount: 3,
    photoLimit: 500,
    isFull: false,
  );

  final joined = <String, EventGuest>{};

  @override
  Future<JoinableEvent> lookupEvent(String code) async {
    if (code.trim().toUpperCase() == knownCode) return event;
    throw const NotFoundException(
      'No active event found for that code. Check with your host.',
    );
  }

  @override
  Future<EventGuest> joinEvent({
    required String eventId,
    required String name,
    String? phone,
  }) async {
    await auth?.signInAnonymously();
    final guest = EventGuest(
      id: 'guest-row-1',
      eventId: eventId,
      name: name.trim(),
      phone: phone,
    );
    joined[eventId] = guest;
    return guest;
  }

  @override
  Future<EventGuest?> existingMembership(String eventId) async =>
      joined[eventId];
}
