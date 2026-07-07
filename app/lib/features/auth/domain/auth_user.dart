/// Minimal identity entity used across the app.
///
/// Wraps the backend auth user so features never depend on Supabase types.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.isAnonymous,
    this.email,
    this.fullName,
  });

  final String id;
  final bool isAnonymous;
  final String? email;
  final String? fullName;

  /// Hosts are fully-registered users; guests are anonymous sessions.
  bool get isHost => !isAnonymous;
}
