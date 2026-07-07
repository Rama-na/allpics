/// Application-level exceptions with user-presentable messages.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  /// Safe, human-readable message for the UI.
  final String message;

  /// Underlying error, for logs only — never shown to users.
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message${cause == null ? '' : ' ($cause)'}';
}

class NetworkException extends AppException {
  const NetworkException({Object? cause})
      : super('No connection. Check your internet and try again.', cause: cause);
}

class AuthException extends AppException {
  const AuthException(super.message, {super.cause});
}

class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.cause});
}

class QuotaExceededException extends AppException {
  const QuotaExceededException({Object? cause})
      : super('This event has reached its photo limit.', cause: cause);
}

class EventExpiredException extends AppException {
  const EventExpiredException({Object? cause})
      : super('This event has expired.', cause: cause);
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}

class UnexpectedException extends AppException {
  const UnexpectedException({Object? cause})
      : super('Something went wrong. Please try again.', cause: cause);
}
