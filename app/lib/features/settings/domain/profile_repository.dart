import 'profile.dart';

/// Profile + account management contract.
abstract interface class ProfileRepository {
  Future<Profile> fetchProfile();

  /// Partial update: only non-null fields are written.
  Future<Profile> updateProfile({
    String? fullName,
    String? theme,
    bool? notifyGuestJoined,
    bool? notifyNewUploads,
    bool? notifyExpiry,
  });

  /// Permanently deletes the account and all owned data.
  Future<void> deleteAccount();
}
