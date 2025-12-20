/// Exception thrown by SCS SDK operations.
class ScsException implements Exception {
  /// The error message.
  final String message;

  /// The HTTP status code, if applicable.
  final int? statusCode;

  /// The error code from the server.
  final String? code;

  /// Additional details about the error.
  final Map<String, dynamic>? details;

  const ScsException(
    this.message, {
    this.statusCode,
    this.code,
    this.details,
  });

  @override
  String toString() {
    final buffer = StringBuffer('ScsException: $message');
    if (statusCode != null) {
      buffer.write(' (status: $statusCode)');
    }
    if (code != null) {
      buffer.write(' [code: $code]');
    }
    return buffer.toString();
  }

  /// Creates an exception for network errors.
  factory ScsException.network(String message) {
    return ScsException(message, code: 'network_error');
  }

  /// Creates an exception for authentication errors.
  factory ScsException.auth(String message, {int? statusCode}) {
    return ScsException(message, statusCode: statusCode, code: 'auth_error');
  }

  /// Creates an exception for not found errors.
  factory ScsException.notFound(String message) {
    return ScsException(message, statusCode: 404, code: 'not_found');
  }

  /// Creates an exception for permission denied errors.
  factory ScsException.permissionDenied(String message) {
    return ScsException(message, statusCode: 403, code: 'permission_denied');
  }

  /// Creates an exception for validation errors.
  factory ScsException.validation(String message, {Map<String, dynamic>? details}) {
    return ScsException(message, statusCode: 400, code: 'validation_error', details: details);
  }

  /// Creates an exception from an HTTP response.
  factory ScsException.fromResponse(int statusCode, Map<String, dynamic> body) {
    final message = body['error'] as String? ?? body['message'] as String? ?? 'Unknown error';
    final code = body['code'] as String?;
    return ScsException(message, statusCode: statusCode, code: code);
  }
}
