import 'package:openfeature_dart_server_sdk/feature_provider.dart';

/// OpenFeature specification-compliant event types
enum OpenFeatureEventType {
  PROVIDER_READY,
  PROVIDER_ERROR,
  PROVIDER_CONFIGURATION_CHANGED,
  PROVIDER_STALE,
  PROVIDER_CONTEXT_CHANGED,
}

class OpenFeatureEvent {
  final OpenFeatureEventType type;
  final String message;
  final dynamic data;
  final DateTime timestamp;
  final ProviderMetadata? providerMetadata;

  OpenFeatureEvent(this.type, this.message, {this.data, this.providerMetadata})
    : timestamp = DateTime.now();
}
