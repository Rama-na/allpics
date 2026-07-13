import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The event id the shell camera posts into. Null = no explicit choice; the
/// shell falls back to the most recent postable event.
class ActiveEventController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String eventId) => state = eventId;

  void clear() => state = null;
}

final activeEventControllerProvider =
    NotifierProvider<ActiveEventController, String?>(ActiveEventController.new);
