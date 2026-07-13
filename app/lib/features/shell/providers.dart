import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../auth/providers.dart';
import '../events/domain/event.dart';
import '../events/domain/my_event.dart';
import '../events/providers.dart';
import 'presentation/controllers/active_event_controller.dart';

/// Merges hosted and joined events into the unified shell list.
/// Host role wins on duplicates (a host who also joined their own event).
/// Live events sort first, then newest created.
List<MyEvent> mergeMyEvents({
  required List<Event> hosted,
  required List<Event> joined,
}) {
  final byId = <String, MyEvent>{
    for (final e in joined) e.id: MyEvent(event: e, role: MyEventRole.guest),
    for (final e in hosted) e.id: MyEvent(event: e, role: MyEventRole.host),
  };
  final merged = byId.values.toList()
    ..sort((a, b) {
      if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
      return b.event.createdAt.compareTo(a.event.createdAt);
    });
  return merged;
}

/// Every event the current user is part of — hosting or joined as guest.
/// Signed-out users get an empty list (the shell still renders).
/// Pull-to-refresh = `ref.invalidate(myEventsShellProvider)`.
final myEventsShellProvider = StreamProvider<List<MyEvent>>((ref) async* {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    yield const [];
    return;
  }
  final repo = ref.watch(eventsRepositoryProvider);
  List<Event> joined;
  try {
    joined = await repo.fetchJoinedEvents();
  } on AppException {
    // Joined list is best-effort; the hosted stream still renders.
    joined = const [];
  }
  await for (final hosted in repo.watchMyEvents()) {
    yield mergeMyEvents(hosted: hosted, joined: joined);
  }
});

/// Events the camera can currently post into.
final postableEventsProvider = Provider<List<MyEvent>>((ref) {
  final events = ref.watch(myEventsShellProvider).value ?? const <MyEvent>[];
  return events.where((e) => e.isPostable).toList();
});

/// The camera's posting target: the explicit selection when still postable,
/// otherwise the most recent postable event.
final activeEventProvider = Provider<MyEvent?>((ref) {
  final postable = ref.watch(postableEventsProvider);
  if (postable.isEmpty) return null;
  final selectedId = ref.watch(activeEventControllerProvider);
  for (final candidate in postable) {
    if (candidate.event.id == selectedId) return candidate;
  }
  return postable.first;
});
