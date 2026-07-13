import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_env.dart';
import '../../core/errors/app_exception.dart';
import '../auth/providers.dart';
import '../events/domain/event.dart';
import '../events/providers.dart';
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
  }) async => throw _error;

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

/// Rehydrates the guest event screen without in-memory join-flow state
/// (My Events navigation, app restarts). RLS lets members read the event;
/// membership confirms this device actually joined.
final guestEventHydrationProvider =
    FutureProvider.family<(Event, EventGuest?), String>((ref, eventId) async {
      final event = await ref.watch(eventsRepositoryProvider).getEvent(eventId);
      final membership = await ref
          .watch(joinRepositoryProvider)
          .existingMembership(eventId);
      return (event, membership);
    });
