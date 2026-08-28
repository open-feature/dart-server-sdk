/// OpenFeature error codes reported during flag resolution.
enum ErrorCode {
  providerNotReady,
  flagNotFound,
  parseError,
  typeMismatch,
  targetingKeyMissing,
  invalidContext,
  providerFatal,
  general,
}

/// An error from client SDK configuration or provider lifecycle work.
final class OpenFeatureException implements Exception {
  const OpenFeatureException(
    this.message, {
    this.errorCode = ErrorCode.general,
  });

  final String message;
  final ErrorCode errorCode;

  @override
  String toString() => 'OpenFeatureException: $message (${errorCode.name})';
}
