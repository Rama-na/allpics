import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/profile.dart';
import '../domain/profile_repository.dart';

/// Production [ProfileRepository] backed by Supabase.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final sb.SupabaseClient _client;
  static final _log = AppLogger.get('profile');

  String get _uid {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('You need to sign in first.');
    return user.id;
  }

  @override
  Future<Profile> fetchProfile() async {
    try {
      final row =
          await _client.from('profiles').select().eq('id', _uid).single();
      return Profile.fromMap(row, email: _client.auth.currentUser?.email);
    } on sb.PostgrestException catch (e) {
      throw UnexpectedException(cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<Profile> updateProfile({
    String? fullName,
    String? theme,
    bool? notifyGuestJoined,
    bool? notifyNewUploads,
    bool? notifyExpiry,
  }) async {
    final values = <String, dynamic>{
      'full_name': ?fullName?.trim(),
      'theme': ?theme,
      'notify_guest_joined': ?notifyGuestJoined,
      'notify_new_uploads': ?notifyNewUploads,
      'notify_expiry': ?notifyExpiry,
    };
    try {
      final row = await _client
          .from('profiles')
          .update(values)
          .eq('id', _uid)
          .select()
          .single();
      return Profile.fromMap(row, email: _client.auth.currentUser?.email);
    } on sb.PostgrestException catch (e) {
      _log.warning('profile update failed: ${e.code}');
      throw UnexpectedException(cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _client.rpc<void>('delete_own_account');
      // The auth row is gone; drop the local session.
      await _client.auth.signOut();
    } on sb.PostgrestException catch (e) {
      _log.warning('account deletion failed: ${e.code}');
      throw UnexpectedException(cause: e);
    } on sb.AuthException {
      // Sign-out after deletion may fail (session already invalid) — fine.
    } catch (e) {
      throw const NetworkException();
    }
  }
}
