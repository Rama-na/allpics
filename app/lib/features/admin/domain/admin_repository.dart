import 'admin_models.dart';

/// Admin backend contract. Every call is admin-guarded server-side.
abstract interface class AdminRepository {
  /// Whether the signed-in user has the admin role.
  Future<bool> isAdmin();

  Future<AdminStats> fetchStats();

  Future<List<AdminUser>> fetchUsers({String search = ''});

  Future<void> setUserBanned(String userId, bool banned);

  Future<List<AdminEvent>> fetchEvents({String search = ''});

  Future<void> deleteEvent(String eventId);

  Future<List<FeatureFlag>> fetchFlags();

  Future<void> setFlag(String key, bool enabled);
}
