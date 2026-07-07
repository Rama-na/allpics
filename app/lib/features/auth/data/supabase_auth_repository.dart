import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

/// Production [AuthRepository] backed by Supabase Auth.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final sb.SupabaseClient _client;
  static final _log = AppLogger.get('auth');

  sb.GoTrueClient get _auth => _client.auth;

  AuthUser? _map(sb.User? user) {
    if (user == null) return null;
    return AuthUser(
      id: user.id,
      isAnonymous: user.isAnonymous,
      email: user.email,
      fullName: user.userMetadata?['full_name'] as String?,
    );
  }

  @override
  Stream<AuthUser?> authStateChanges() =>
      _auth.onAuthStateChange.map((state) => _map(state.session?.user));

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final res =
          await _auth.signInWithPassword(email: email.trim(), password: password);
      return _map(res.user)!;
    } on sb.AuthException catch (e) {
      _log.warning('signIn failed: ${e.code}');
      throw AuthException(_friendlyAuthMessage(e), cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<SignUpResult> signUpWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim()},
      );
      return SignUpResult(needsEmailConfirmation: res.session == null);
    } on sb.AuthException catch (e) {
      _log.warning('signUp failed: ${e.code}');
      throw AuthException(_friendlyAuthMessage(e), cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      await _auth.signInWithOAuth(
        sb.OAuthProvider.google,
        authScreenLaunchMode: sb.LaunchMode.externalApplication,
      );
    } on sb.AuthException catch (e) {
      throw AuthException(_friendlyAuthMessage(e), cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<AuthUser> signInAnonymously() async {
    // Reuse an existing session (guest re-scanning the QR keeps identity).
    final existing = currentUser;
    if (existing != null) return existing;
    try {
      final res = await _auth.signInAnonymously();
      return _map(res.user)!;
    } on sb.AuthException catch (e) {
      throw AuthException(_friendlyAuthMessage(e), cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on sb.AuthException catch (e) {
      throw AuthException(_friendlyAuthMessage(e), cause: e);
    }
  }

  String _friendlyAuthMessage(sb.AuthException e) => switch (e.code) {
        'invalid_credentials' => 'Incorrect email or password.',
        'email_exists' ||
        'user_already_exists' =>
          'An account with this email already exists.',
        'email_not_confirmed' => 'Please confirm your email first.',
        'weak_password' => 'Password is too weak — use at least 8 characters.',
        'over_request_rate_limit' => 'Too many attempts. Try again shortly.',
        'anonymous_provider_disabled' =>
          'Guest access is temporarily unavailable.',
        _ => 'Sign-in failed. Please try again.',
      };
}
