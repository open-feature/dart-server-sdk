///provider states for lifecycle management

enum ProviderState {
  READY,
  ERROR,
  NOT_READY,
}

///basic provider exception

class providerException implements Exception {
  final String message;
  final String code;

  providerException(this.message, {this.code = 'PROVIDER_ERROR'});

  @override
  String toString() => 'ProviderException: $message (code: $code)';
}

// Interface/Contract for feature providers and OpenFeatureNoOpProvider.
// Metadata describing the provider.
class OpenFeatureProviderMetadata {
  final String name;

  OpenFeatureProviderMetadata(this.name);
}

// Abstract interface for feature providers.
abstract class OpenFeatureProvider {
  // Returns metadata about the provider. (Provider metadata)
  OpenFeatureProviderMetadata get metadata;

  //current Provider State
  ProviderState get state;

  //initialize the Provider
  Future<void> initialize();

  //clean up the provider resources(shutdown)
  Future<void> shutdown();

  // Type-safe flag evaluation methods.

  // get boolean flag value
  Future<bool> getBooleanFlag(String flagKey, {Map<String, dynamic>? context});

  // get string flag value
  Future<String> getStringFlag(String flagKey, {Map<String, dynamic>? context});

  //get integer flag value
  Future<int> getIntegerFlag(String flagKey, {Map<String, dynamic>? context});

  // get double flag value
  Future<double> getDoubleFlag(String flagKey, {Map<String, dynamic>? context});

  // get object flag value
  Future<dynamic> getObjectFlag(String flagKey,
      {Map<String, dynamic>? context});
}

//Default Provider Implementation
// Default OpenFeatureNoOpProvider implementation as a safe fallback.
class OpenFeatureNoOpProvider implements OpenFeatureProvider {
  ProviderState _state = ProviderState.NOT_READY;

  @override
  OpenFeatureProviderMetadata get metadata =>
      OpenFeatureProviderMetadata("NoOpProvider");

  @override
  ProviderState get state => _state;

  @override
  Future<void> initialize() async {
    _state = ProviderState.READY;
  }

  @override
  Future<void> shutdown() async {
    _state = ProviderState.NOT_READY;
  }

  ///verify state is initialized
  void _checkState() {
    if (_state != ProviderState.READY) {
      throw StateError('Provider not initialized');
    }
  }

  @override
  Future<bool> getBooleanFlag(String flagKey,
      {Map<String, dynamic>? context}) async {
    _checkState();
    return false; // Default boolean value.
  }

  @override
  Future<String> getStringFlag(String flagKey,
      {Map<String, dynamic>? context}) async {
    _checkState();
    return ""; // Default string value.
  }

  @override
  Future<int> getIntegerFlag(String flagKey,
      {Map<String, dynamic>? context}) async {
    _checkState();
    return 0; // Default integer value.
  }

  @override
  Future<double> getDoubleFlag(String flagKey,
      {Map<String, dynamic>? context}) async {
    _checkState();
    return 0.0; // Default double value.
  }

  @override
  Future<dynamic> getObjectFlag(String flagKey,
      {Map<String, dynamic>? context}) async {
    _checkState();
    return null; // Default object value.
  }
}
