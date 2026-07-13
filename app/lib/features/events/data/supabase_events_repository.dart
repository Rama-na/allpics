import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/event.dart';
import '../domain/events_repository.dart';

/// Maps a failed free-plan lookup to a user-actionable exception.
/// PGRST116 = `.single()` matched no row → the plan catalog was never
/// provisioned (hosted `db push` does not run seed.sql).
@visibleForTesting
AppException mapPlanLookupError(sb.PostgrestException e) =>
    e.code == 'PGRST116'
        ? BackendNotProvisionedException(cause: e)
        : UnexpectedException(cause: e);

/// Maps a failed event insert to a user-actionable exception.
/// 42501 = RLS rejected the row — `events_insert_host` requires a `profiles`
/// row, which is missing for accounts created before migrations were pushed.
@visibleForTesting
AppException mapCreateEventError(sb.PostgrestException e) =>
    e.code == '42501'
        ? AuthException(
            'Your account profile is missing. Sign out and back in, '
            'or contact support.',
            cause: e,
          )
        : UnexpectedException(cause: e);

/// Production [EventsRepository] backed by Supabase (PostgREST + Realtime +
/// Storage). All access is RLS-guarded; hosts only ever see their own rows.
class SupabaseEventsRepository implements EventsRepository {
  SupabaseEventsRepository(this._client);

  final sb.SupabaseClient _client;
  static final _log = AppLogger.get('events');

  String get _uid {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('You need to sign in first.');
    }
    return user.id;
  }

  @override
  Stream<List<Event>> watchMyEvents() {
    return _client
        .from('events')
        .stream(primaryKey: ['id'])
        .eq('host_id', _uid)
        .order('created_at')
        .map((rows) => rows
            .map(Event.fromMap)
            .where((e) => e.status != EventStatus.deleted)
            .toList());
  }

  @override
  Future<List<Event>> fetchJoinedEvents() async {
    try {
      // Embedded select through the FK: one round trip, RLS-filtered on both
      // tables (own membership rows; member-visible events).
      final rows = await _client
          .from('event_guests')
          .select('joined_at, events!inner(*)')
          .eq('auth_user_id', _uid)
          .order('joined_at', ascending: false);
      return rows
          .map((row) => Event.fromMap(row['events'] as Map<String, dynamic>))
          .where((e) => e.status != EventStatus.deleted)
          .toList();
    } on AppException {
      rethrow;
    } on sb.PostgrestException catch (e) {
      _log.warning('joined-events fetch failed: ${e.code} ${e.message}');
      throw UnexpectedException(cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Stream<Event> watchEvent(String eventId) {
    return _client
        .from('events')
        .stream(primaryKey: ['id'])
        .eq('id', eventId)
        .map((rows) {
          if (rows.isEmpty) {
            throw const NotFoundException('This event no longer exists.');
          }
          return Event.fromMap(rows.first);
        });
  }

  @override
  Future<Event> getEvent(String eventId) async {
    try {
      final row =
          await _client.from('events').select().eq('id', eventId).single();
      return Event.fromMap(row);
    } on sb.PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw const NotFoundException('This event no longer exists.');
      }
      throw UnexpectedException(cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  Future<String> _freePlanId() async {
    try {
      final row = await _client
          .from('plans')
          .select('id')
          .eq('code', 'free')
          .single();
      return row['id'] as String;
    } on sb.PostgrestException catch (e) {
      throw mapPlanLookupError(e);
    }
  }

  @override
  Future<Event> createEvent(EventDraft draft) async {
    try {
      final planId = await _freePlanId();
      final row = await _client
          .from('events')
          .insert({
            'host_id': _uid,
            'plan_id': planId,
            'type': draft.type.dbValue,
            'title': draft.title.trim(),
            'description': draft.description.trim(),
            'event_date': draft.eventDate?.toIso8601String().substring(0, 10),
            'location': draft.location.trim(),
          })
          .select()
          .single();
      _log.info('event created ${row['id']}');
      return Event.fromMap(row);
    } on AppException {
      rethrow;
    } on sb.PostgrestException catch (e) {
      _log.warning('create failed: ${e.code} ${e.message}');
      throw mapCreateEventError(e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<Event> updateEvent(String eventId, EventDraft draft) async {
    try {
      final row = await _client
          .from('events')
          .update({
            'type': draft.type.dbValue,
            'title': draft.title.trim(),
            'description': draft.description.trim(),
            'event_date': draft.eventDate?.toIso8601String().substring(0, 10),
            'location': draft.location.trim(),
          })
          .eq('id', eventId)
          .select()
          .single();
      return Event.fromMap(row);
    } on sb.PostgrestException catch (e) {
      throw UnexpectedException(cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    try {
      await _client
          .from('events')
          .update({'status': 'deleted'}).eq('id', eventId);
    } on sb.PostgrestException catch (e) {
      throw UnexpectedException(cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<Event> uploadCover({
    required String eventId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final path = '$eventId/cover.$fileExtension';
    try {
      await _client.storage.from('covers').uploadBinary(
            path,
            bytes,
            fileOptions: const sb.FileOptions(upsert: true),
          );
      final row = await _client
          .from('events')
          .update({'cover_url': path})
          .eq('id', eventId)
          .select()
          .single();
      return Event.fromMap(row);
    } on sb.StorageException catch (e) {
      _log.warning('cover upload failed: ${e.message}');
      throw const UnexpectedException(cause: 'cover upload failed');
    } on sb.PostgrestException catch (e) {
      throw UnexpectedException(cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<String> signedCoverUrl(String coverPath) async {
    try {
      return await _client.storage
          .from('covers')
          .createSignedUrl(coverPath, 3600);
    } on sb.StorageException catch (e) {
      throw UnexpectedException(cause: e);
    }
  }
}
