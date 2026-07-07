import 'auth_user.dart';

/// Result of a sign-up attempt. When email confirmation is enabled in
/// Supabase, no session is issued until the user confirms.
class SignUpResult {
  const SignUpResult({required this.needsEmailConfirmation});

  final bool needsEmailConfirmation;
}

/// Authentication contract. Implementations:
/// - [SupabaseAuthRepository] — production
/// - `UnconfiguredAuthRepository` — pre-provisioning fallback
/// - test fakes
abstract interface class AuthRepository {
  /// Emits the current user on every auth state change (null = signed out).
  Stream<AuthUser?> authStateChanges();

  AuthUser? get currentUser;

  /// Throws [AuthException] with a user-safe message on failure.
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<SignUpResult> signUpWithEmail({
    required String fullName,
    required String email,
    required String password,
  });

  /// Launches the Google OAuth flow. The session lands via deep link and is
  /// observed through [authStateChanges].
  Future<void> signInWithGoogle();

  /// Creates (or reuses) an anonymous session for a guest.
  Future<AuthUser> signInAnonymously();

  Future<void> signOut();
}
