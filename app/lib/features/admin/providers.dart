import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_env.dart';
import '../auth/providers.dart';
import 'data/supabase_admin_repository.dart';
import 'domain/admin_models.dart';
import 'domain/admin_repository.dart';

/// Pre-provisioning fallback: nobody is an admin.
class _UnconfiguredAdminRepository implements AdminRepository {
  const _UnconfiguredAdminRepository();

  @override
  Future<bool> isAdmin() async => false;

  @override
  Future<AdminStats> fetchStats() async => throw UnsupportedError('n/a');

  @override
  Future<List<AdminUser>> fetchUsers({String search = ''}) async => const [];

  @override
  Future<void> setUserBanned(String userId, bool banned) async {}

  @override
  Future<List<AdminEvent>> fetchEvents({String search = ''}) async => const [];

  @override
  Future<void> deleteEvent(String eventId) async {}

  @override
  Future<List<FeatureFlag>> fetchFlags() async => const [];

  @override
  Future<void> setFlag(String key, bool enabled) async {}
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  if (!AppEnv.isSupabaseConfigured) return const _UnconfiguredAdminRepository();
  return SupabaseAdminRepository(ref.watch(supabaseClientProvider));
});

/// Whether the signed-in user is an admin (drives the home entry point).
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isHost) return false;
  return ref.watch(adminRepositoryProvider).isAdmin();
});

final adminStatsProvider = FutureProvider<AdminStats>((ref) {
  return ref.watch(adminRepositoryProvider).fetchStats();
});

final adminUsersProvider =
    FutureProvider.family<List<AdminUser>, String>((ref, search) {
  return ref.watch(adminRepositoryProvider).fetchUsers(search: search);
});

final adminEventsProvider =
    FutureProvider.family<List<AdminEvent>, String>((ref, search) {
  return ref.watch(adminRepositoryProvider).fetchEvents(search: search);
});

final adminFlagsProvider = FutureProvider<List<FeatureFlag>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchFlags();
});
