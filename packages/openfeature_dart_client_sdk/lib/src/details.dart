import 'error.dart';
import 'immutable.dart';

/// Details returned by a provider resolver.
final class ResolutionDetails<T> {
  ResolutionDetails({
    required this.value,
    this.errorCode,
    this.errorMessage,
    this.reason,
    this.variant,
    Map<String, Object> flagMetadata = const {},
  }) : flagMetadata = immutableMetadata(flagMetadata, path: 'flagMetadata');

  final T value;
  final ErrorCode? errorCode;
  final String? errorMessage;
  final String? reason;
  final String? variant;
  final Map<String, Object> flagMetadata;
}

/// Details returned to an application after flag evaluation.
final class FlagEvaluationDetails<T> {
  FlagEvaluationDetails({
    required this.flagKey,
    required this.value,
    this.errorCode,
    this.errorMessage,
    this.reason,
    this.variant,
    Map<String, Object> flagMetadata = const {},
  }) : flagMetadata = immutableMetadata(flagMetadata, path: 'flagMetadata');

  final String flagKey;
  final T value;
  final ErrorCode? errorCode;
  final String? errorMessage;
  final String? reason;
  final String? variant;
  final Map<String, Object> flagMetadata;
}
