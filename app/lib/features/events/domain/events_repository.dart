import 'dart:typed_data';

import 'event.dart';

/// Host event management contract.
abstract interface class EventsRepository {
  /// Live list of the signed-in host's events (newest first,
  /// deleted excluded). Emits on every counter change.
  Stream<List<Event>> watchMyEvents();

  /// Events the current user joined as a guest (newest join first).
  /// One-shot fetch — callers refresh via pull-to-refresh.
  Future<List<Event>> fetchJoinedEvents();

  /// Live single event (dashboard counters).
  Stream<Event> watchEvent(String eventId);

  Future<Event> getEvent(String eventId);

  /// Creates an event on the Free plan. Code/slug/limits are assigned by
  /// database triggers.
  Future<Event> createEvent(EventDraft draft);

  Future<Event> updateEvent(String eventId, EventDraft draft);

  /// Soft delete (status = deleted). Media cleanup happens server-side.
  Future<void> deleteEvent(String eventId);

  /// Uploads a cover image; returns the updated event.
  Future<Event> uploadCover({
    required String eventId,
    required Uint8List bytes,
    required String fileExtension,
  });

  /// Short-lived signed URL for a private cover path.
  Future<String> signedCoverUrl(String coverPath);

  /// Queues an AI keepsake job ('highlights' or 'slideshow') for an event
  /// the caller hosts. Server-side dedup: re-queuing while one is pending
  /// throws a [ValidationException].
  Future<void> enqueueKeepsakeJob(String eventId, String jobType);
}
