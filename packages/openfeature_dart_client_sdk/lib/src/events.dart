import 'error.dart';
import 'immutable.dart';

/// Provider lifecycle and configuration events.
enum ProviderEventType {
  ready,
  error,
  configurationChanged,
  stale,
  reconciling,
  contextChanged,
}

/// Event data emitted by a feature provider.
final class ProviderEvent {
  ProviderEvent({
    required this.type,
    Iterable<String> flagsChanged = const [],
    this.message,
    this.errorCode,
    Map<String, Object> metadata = const {},
  }) : flagsChanged = List<String>.unmodifiable(flagsChanged),
       metadata = immutableMetadata(metadata, path: 'eventMetadata');

  final ProviderEventType type;
  final List<String> flagsChanged;
  final String? message;
  final ErrorCode? errorCode;
  final Map<String, Object> metadata;
}
