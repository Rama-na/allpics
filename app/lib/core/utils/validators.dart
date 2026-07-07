/// Form validators shared across auth and join flows.
/// Return null when valid, or a user-facing error message.
abstract final class Validators {
  static final _emailRe = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
  static final _phoneRe = RegExp(r'^[+0-9][0-9 \-]{5,19}$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required.';
    if (!_emailRe.hasMatch(v)) return 'Enter a valid email address.';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required.';
    if (v.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Name is required.';
    if (v.length > 80) return 'Name is too long.';
    return null;
  }

  static String? optionalPhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!_phoneRe.hasMatch(v)) return 'Enter a valid phone number.';
    return null;
  }

  static String? eventCode(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Event code is required.';
    if (v.length < 6) return 'Codes are at least 6 characters.';
    return null;
  }
}
