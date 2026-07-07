import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/join_repository.dart';
import '../domain/joinable_event.dart';

/// Production [JoinRepository]: RPC lookup + anonymous auth + guest insert,
/// all guarded by RLS (`event_guests_insert_self`).
class SupabaseJoinRepository implements JoinRepository {
  SupabaseJoinRepository(this._client, this._auth);

  final sb.SupabaseClient _client;
  final AuthRepository _auth;
  static final _log = AppLogger.get('join');

  @override
  Future<JoinableEvent> lookupEvent(String code) async {
    final normalized = code.trim();
    if (normalized.isEmpty) {
      throw const ValidationException('Enter an event code.');
    }
    try {
      final rows = await _client
          .rpc<List<dynamic>>('get_event_for_join', params: {'p_code': normalized});
      if (rows.isEmpty) {
        throw const NotFoundException(
          'No active event found for that code. Check with your host.',
        );
      }
      return JoinableEvent.fromMap(rows.first as Map<String, dynamic>);
    } on AppException {
      rethrow;
    } on sb.PostgrestException catch (e) {
      _log.warning('lookup failed: ${e.code}');
      throw UnexpectedException(cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<EventGuest> joinEvent({
    required String eventId,
    required String name,
    String? phone,
  }) async {
    final user = await _auth.signInAnonymously();
    try {
      // Idempotent join: return existing membership when re-scanning.
      final existing = await existingMembership(eventId);
      if (existing != null) return existing;

      final row = await _client
          .from('event_guests')
          .insert({
            'event_id': eventId,
            'auth_user_id': user.id,
            'name': name.trim(),
            if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          })
          .select()
          .single();
      return EventGuest.fromMap(row);
    } on sb.PostgrestException catch (e) {
      _log.warning('join failed: ${e.code} ${e.message}');
      if (e.code == '23505') {
        // Unique violation — joined concurrently; fetch the row.
        final existing = await existingMembership(eventId);
        if (existing != null) return existing;
      }
      if (e.code == '42501') {
        throw const EventExpiredException();
      }
      throw UnexpectedException(cause: e);
    } on AppException {
      rethrow;
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<EventGuest?> existingMembership(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final row = await _client
          .from('event_guests')
          .select()
          .eq('event_id', eventId)
          .eq('auth_user_id', user.id)
          .maybeSingle();
      return row == null ? null : EventGuest.fromMap(row);
    } on sb.PostgrestException catch (e) {
      throw UnexpectedException(cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }
}
