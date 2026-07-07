import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_env.dart';
import '../../core/errors/app_exception.dart';
import '../auth/providers.dart';
import 'data/supabase_join_repository.dart';
import 'domain/join_repository.dart';
import 'domain/joinable_event.dart';

/// Pre-provisioning fallback: fails with a clear message, never crashes.
class _UnconfiguredJoinRepository implements JoinRepository {
  const _UnconfiguredJoinRepository();

  static const _error = UnexpectedException(
    cause: 'Backend not configured — see docs/DEPLOYMENT.md',
  );

  @override
  Future<JoinableEvent> lookupEvent(String code) async => throw _error;

  @override
  Future<EventGuest> joinEvent({
    required String eventId,
    required String name,
    String? phone,
  }) async =>
      throw _error;

  @override
  Future<EventGuest?> existingMembership(String eventId) async => null;
}

final joinRepositoryProvider = Provider<JoinRepository>((ref) {
  if (!AppEnv.isSupabaseConfigured) return const _UnconfiguredJoinRepository();
  return SupabaseJoinRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(authRepositoryProvider),
  );
});
