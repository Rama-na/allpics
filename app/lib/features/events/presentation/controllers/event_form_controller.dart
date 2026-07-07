import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/event.dart';
import '../../providers.dart';

/// Drives create / edit / delete actions for events.
class EventFormController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Creates the event (and uploads the cover when provided).
  /// Returns the created event, or null on failure (error is in [state]).
  Future<Event?> create(
    EventDraft draft, {
    Uint8List? coverBytes,
    String coverExtension = 'jpg',
  }) async {
    state = const AsyncLoading();
    final repo = ref.read(eventsRepositoryProvider);
    try {
      var event = await repo.createEvent(draft);
      if (coverBytes != null) {
        event = await repo.uploadCover(
          eventId: event.id,
          bytes: coverBytes,
          fileExtension: coverExtension,
        );
      }
      state = const AsyncData(null);
      return event;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<Event?> update(
    String eventId,
    EventDraft draft, {
    Uint8List? coverBytes,
    String coverExtension = 'jpg',
  }) async {
    state = const AsyncLoading();
    final repo = ref.read(eventsRepositoryProvider);
    try {
      var event = await repo.updateEvent(eventId, draft);
      if (coverBytes != null) {
        event = await repo.uploadCover(
          eventId: event.id,
          bytes: coverBytes,
          fileExtension: coverExtension,
        );
      }
      state = const AsyncData(null);
      return event;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<bool> delete(String eventId) async {
    state = const AsyncLoading();
    try {
      await ref.read(eventsRepositoryProvider).deleteEvent(eventId);
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final eventFormControllerProvider =
    NotifierProvider<EventFormController, AsyncValue<void>>(
        EventFormController.new);
