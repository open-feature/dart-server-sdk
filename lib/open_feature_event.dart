import 'feature_provider.dart';

/// OpenFeature specification-compliant event types
enum OpenFeatureEventType {
  PROVIDER_READY,
  PROVIDER_ERROR,
  PROVIDER_CONFIGURATION_CHANGED,
  PROVIDER_STALE,
  PROVIDER_CONTEXT_CHANGED,
  PROVIDER_RECONCILING,
}

class OpenFeatureEvent {
  final OpenFeatureEventType type;
  final String message;
  final dynamic data;
  final DateTime timestamp;
  final ProviderMetadata? providerMetadata;
  final FeatureProvider? provider;
  final String? domain;
  final ErrorCode? errorCode;

  OpenFeatureEvent(
    this.type,
    this.message, {
    this.data,
    this.providerMetadata,
    this.provider,
    this.domain,
    this.errorCode,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
