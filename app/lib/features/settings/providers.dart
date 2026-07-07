import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_env.dart';
import '../../core/errors/app_exception.dart';
import '../auth/providers.dart';
import 'data/supabase_profile_repository.dart';
import 'domain/profile.dart';
import 'domain/profile_repository.dart';

/// Pre-provisioning fallback: profile derives from the (fake/absent) session;
/// server writes fail with a clear message. Theme still works — it is
/// local-first (see ThemeModeNotifier).
class _UnconfiguredProfileRepository implements ProfileRepository {
  const _UnconfiguredProfileRepository();

  static const _error = UnexpectedException(
    cause: 'Backend not configured — see docs/DEPLOYMENT.md',
  );

  @override
  Future<Profile> fetchProfile() async => const Profile(
        id: 'local',
        fullName: '',
        theme: 'system',
        notifyGuestJoined: true,
        notifyNewUploads: true,
        notifyExpiry: true,
      );

  @override
  Future<Profile> updateProfile({
    String? fullName,
    String? theme,
    bool? notifyGuestJoined,
    bool? notifyNewUploads,
    bool? notifyExpiry,
  }) async =>
      throw _error;

  @override
  Future<void> deleteAccount() async => throw _error;
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (!AppEnv.isSupabaseConfigured) {
    return const _UnconfiguredProfileRepository();
  }
  return SupabaseProfileRepository(ref.watch(supabaseClientProvider));
});

final profileProvider = FutureProvider<Profile>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(profileRepositoryProvider).fetchProfile();
});
