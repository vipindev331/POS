/// Typed failures used across the app. Dart 3 sealed classes give exhaustive
/// switch handling without code generation.
library;

sealed class Failure {
  final String message;
  const Failure(this.message);
  @override
  String toString() => '$runtimeType($message)';
}

/// No network / server unreachable — offline path should take over.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network unavailable']);
}

/// Server returned 4xx/5xx.
class ServerFailure extends Failure {
  final int? statusCode;
  final String? code;
  const ServerFailure(super.message, {this.statusCode, this.code});
}

/// 401 / token invalid.
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication required']);
}

/// Local database / persistence error.
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Local storage error']);
}

/// Business-rule / validation failure (e.g. insufficient stock).
class ValidationFailure extends Failure {
  final Object? details;
  const ValidationFailure(super.message, {this.details});
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong']);
}
