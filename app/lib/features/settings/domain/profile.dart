/// The signed-in host's profile (a `profiles` row).
class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.theme,
    required this.notifyGuestJoined,
    required this.notifyNewUploads,
    required this.notifyExpiry,
    this.email,
  });

  final String id;
  final String fullName;
  final String? email;

  /// 'system' | 'light' | 'dark'
  final String theme;
  final bool notifyGuestJoined;
  final bool notifyNewUploads;
  final bool notifyExpiry;

  Profile copyWith({
    String? fullName,
    String? theme,
    bool? notifyGuestJoined,
    bool? notifyNewUploads,
    bool? notifyExpiry,
  }) =>
      Profile(
        id: id,
        fullName: fullName ?? this.fullName,
        email: email,
        theme: theme ?? this.theme,
        notifyGuestJoined: notifyGuestJoined ?? this.notifyGuestJoined,
        notifyNewUploads: notifyNewUploads ?? this.notifyNewUploads,
        notifyExpiry: notifyExpiry ?? this.notifyExpiry,
      );

  factory Profile.fromMap(Map<String, dynamic> map, {String? email}) =>
      Profile(
        id: map['id'] as String,
        fullName: (map['full_name'] as String?) ?? '',
        email: email,
        theme: (map['theme'] as String?) ?? 'system',
        notifyGuestJoined: (map['notify_guest_joined'] as bool?) ?? true,
        notifyNewUploads: (map['notify_new_uploads'] as bool?) ?? true,
        notifyExpiry: (map['notify_expiry'] as bool?) ?? true,
      );
}
