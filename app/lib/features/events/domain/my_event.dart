import 'event.dart';

/// The current user's relationship to an event they can see in the shell.
enum MyEventRole { host, guest }

/// One row in the unified "My Events" list: an event plus how the current
/// user relates to it (hosting vs joined as a guest).
class MyEvent {
  const MyEvent({required this.event, required this.role});

  final Event event;
  final MyEventRole role;

  bool get isHost => role == MyEventRole.host;

  /// Live = active and not yet expired; everything else reads as "ended".
  bool get isLive =>
      event.isActive && event.expiresAt.isAfter(DateTime.now());

  /// Whether the camera can post into this event right now.
  bool get isPostable => isLive && !event.isFull;
}
