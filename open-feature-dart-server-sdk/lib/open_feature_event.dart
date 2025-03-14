enum OpenFeatureEventType
 { providerChanged, flagUpdated,
  error, flagEvaluated, contextUpdated }

class OpenFeatureEvent {
  final OpenFeatureEventType type;
  final String message;
  final dynamic data;

  OpenFeatureEvent(this.type, this.message, {this.data});
}
