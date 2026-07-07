import '../../../core/errors/app_exception.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

/// Fallback used before Supabase is provisioned (Phase 0). The app boots and
/// all UI renders; auth actions fail with a clear message instead of crashing.
class UnconfiguredAuthRepository implements AuthRepository {
  const UnconfiguredAuthRepository();

  static const _error = AuthException(
    'Backend not configured yet. See docs/DEPLOYMENT.md to provision Supabase.',
  );

  @override
  Stream<AuthUser?> authStateChanges() => const Stream.empty();

  @override
  AuthUser? get currentUser => null;

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      throw _error;

  @override
  Future<SignUpResult> signUpWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async =>
      throw _error;

  @override
  Future<void> signInWithGoogle() async => throw _error;

  @override
  Future<AuthUser> signInAnonymously() async => throw _error;

  @override
  Future<void> signOut() async {
    // No session exists; signing out is a safe no-op.
  }
}
