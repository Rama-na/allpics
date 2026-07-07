import 'joinable_event.dart';

/// Guest join flow contract.
abstract interface class JoinRepository {
  /// Looks up an active event by 6-char code or share slug.
  /// Throws [NotFoundException] when no joinable event matches.
  Future<JoinableEvent> lookupEvent(String code);

  /// Ensures an anonymous session, then registers the guest for [eventId].
  /// Idempotent: re-joining returns the existing membership.
  Future<EventGuest> joinEvent({
    required String eventId,
    required String name,
    String? phone,
  });

  /// Existing membership for the current session, if any.
  Future<EventGuest?> existingMembership(String eventId);
}
