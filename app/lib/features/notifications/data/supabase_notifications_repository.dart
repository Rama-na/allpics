import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/app_notification.dart';
import '../domain/notifications_repository.dart';

/// Production [NotificationsRepository] backed by Supabase Realtime.
class SupabaseNotificationsRepository implements NotificationsRepository {
  SupabaseNotificationsRepository(this._client);

  final sb.SupabaseClient _client;
  static final _log = AppLogger.get('notifications');

  String get _uid {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('You need to sign in first.');
    return user.id;
  }

  @override
  Stream<List<AppNotification>> watchNotifications() {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', _uid)
        .order('created_at')
        .map((rows) => rows.map(AppNotification.fromMap).toList());
  }

  @override
  Future<void> markRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', notificationId)
          .filter('read_at', 'is', null);
    } on sb.PostgrestException catch (e) {
      throw UnexpectedException(cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<void> markAllRead() async {
    try {
      await _client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', _uid)
          .filter('read_at', 'is', null);
    } on sb.PostgrestException catch (e) {
      throw UnexpectedException(cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<void> delete(String notificationId) async {
    try {
      await _client.from('notifications').delete().eq('id', notificationId);
    } on sb.PostgrestException catch (e) {
      throw UnexpectedException(cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<void> registerPushToken(String token) async {
    try {
      await _client
          .from('profiles')
          .update({'fcm_token': token}).eq('id', _uid);
      _log.info('push token registered');
    } on sb.PostgrestException catch (e) {
      throw UnexpectedException(cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }
}
