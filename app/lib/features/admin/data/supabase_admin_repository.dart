import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/admin_models.dart';
import '../domain/admin_repository.dart';

/// Production [AdminRepository] over guarded RPCs.
class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository(this._client);

  final sb.SupabaseClient _client;
  static final _log = AppLogger.get('admin');

  Never _mapError(sb.PostgrestException e) {
    _log.warning('admin call failed: ${e.code} ${e.message}');
    if (e.message.contains('ADMIN_ONLY')) {
      throw const AuthException('Admin access required.');
    }
    if (e.message.contains('CANNOT_BAN_SELF') ||
        e.message.contains('CANNOT_BAN_ADMIN')) {
      throw const ValidationException('This account cannot be banned.');
    }
    throw UnexpectedException(cause: e);
  }

  @override
  Future<bool> isAdmin() async {
    try {
      final result = await _client.rpc<bool>('is_admin');
      return result;
    } on sb.PostgrestException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AdminStats> fetchStats() async {
    try {
      final result =
          await _client.rpc<Map<String, dynamic>>('admin_stats');
      return AdminStats.fromMap(result);
    } on sb.PostgrestException catch (e) {
      _mapError(e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<List<AdminUser>> fetchUsers({String search = ''}) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'admin_list_users',
        params: {'p_search': search},
      );
      return rows
          .map((r) => AdminUser.fromMap(r as Map<String, dynamic>))
          .toList();
    } on sb.PostgrestException catch (e) {
      _mapError(e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<void> setUserBanned(String userId, bool banned) async {
    try {
      await _client.rpc<void>(
        'admin_set_user_banned',
        params: {'p_user_id': userId, 'p_banned': banned},
      );
    } on sb.PostgrestException catch (e) {
      _mapError(e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<List<AdminEvent>> fetchEvents({String search = ''}) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'admin_list_events',
        params: {'p_search': search},
      );
      return rows
          .map((r) => AdminEvent.fromMap(r as Map<String, dynamic>))
          .toList();
    } on sb.PostgrestException catch (e) {
      _mapError(e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    try {
      await _client
          .rpc<void>('admin_delete_event', params: {'p_event_id': eventId});
    } on sb.PostgrestException catch (e) {
      _mapError(e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<List<FeatureFlag>> fetchFlags() async {
    try {
      final rows =
          await _client.from('feature_flags').select().order('key');
      return rows.map(FeatureFlag.fromMap).toList();
    } on sb.PostgrestException catch (e) {
      _mapError(e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<void> setFlag(String key, bool enabled) async {
    try {
      await _client
          .from('feature_flags')
          .update({'enabled': enabled}).eq('key', key);
    } on sb.PostgrestException catch (e) {
      _mapError(e);
    } catch (e) {
      throw const NetworkException();
    }
  }
}
