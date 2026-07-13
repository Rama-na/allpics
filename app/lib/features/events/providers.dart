import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_env.dart';
import '../../core/errors/app_exception.dart';
import '../auth/providers.dart';
import 'data/supabase_events_repository.dart';
import 'domain/event.dart';
import 'domain/events_repository.dart';

/// Pre-provisioning fallback: empty lists, clear errors on writes.
class _UnconfiguredEventsRepository implements EventsRepository {
  const _UnconfiguredEventsRepository();

  static const _error = UnexpectedException(
    cause: 'Backend not configured — see docs/DEPLOYMENT.md',
  );

  @override
  Stream<List<Event>> watchMyEvents() => Stream.value(const []);

  @override
  Future<List<Event>> fetchJoinedEvents() async => const [];

  @override
  Stream<Event> watchEvent(String eventId) =>
      Stream.error(const NotFoundException('Backend not configured.'));

  @override
  Future<Event> getEvent(String eventId) async => throw _error;

  @override
  Future<Event> createEvent(EventDraft draft) async => throw _error;

  @override
  Future<Event> updateEvent(String eventId, EventDraft draft) async =>
      throw _error;

  @override
  Future<void> deleteEvent(String eventId) async => throw _error;

  @override
  Future<Event> uploadCover({
    required String eventId,
    required Uint8List bytes,
    required String fileExtension,
  }) async => throw _error;

  @override
  Future<String> signedCoverUrl(String coverPath) async => throw _error;

  @override
  Future<void> enqueueKeepsakeJob(String eventId, String jobType) async =>
      throw _error;
}

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  if (!AppEnv.isSupabaseConfigured) {
    return const _UnconfiguredEventsRepository();
  }
  return SupabaseEventsRepository(ref.watch(supabaseClientProvider));
});

/// Live list of the host's events for the home screen.
final myEventsProvider = StreamProvider<List<Event>>((ref) {
  // Recompute when the signed-in user changes.
  ref.watch(currentUserProvider);
  return ref.watch(eventsRepositoryProvider).watchMyEvents();
});

/// Live single event for the dashboard.
final eventProvider = StreamProvider.family<Event, String>((ref, eventId) {
  return ref.watch(eventsRepositoryProvider).watchEvent(eventId);
});

/// Signed URL for a private cover path (1h TTL, cached by provider).
final coverUrlProvider = FutureProvider.family<String, String>((ref, path) {
  return ref.watch(eventsRepositoryProvider).signedCoverUrl(path);
});
