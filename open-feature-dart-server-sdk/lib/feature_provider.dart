// Interface/Contract for feature providers and OpenFeatureNoOpProvider.
// Metadata describing the provider.
class OpenFeatureProviderMetadata {
  final String name;

  OpenFeatureProviderMetadata(this.name);
}

// Abstract interface for feature providers.
abstract class OpenFeatureProvider {
  // Returns metadata about the provider.
  OpenFeatureProviderMetadata get metadata;

  // Type-safe flag evaluation methods.
  Future<bool> getBooleanFlag(String flagKey, {Map<String, dynamic>? context});
  Future<String> getStringFlag(String flagKey, {Map<String, dynamic>? context});
  Future<int> getIntegerFlag(String flagKey, {Map<String, dynamic>? context});
  Future<double> getDoubleFlag(String flagKey, {Map<String, dynamic>? context});
  Future<dynamic> getObjectFlag(String flagKey,
      {Map<String, dynamic>? context});
}

// Default OpenFeatureNoOpProvider implementation as a safe fallback.
class OpenFeatureNoOpProvider implements OpenFeatureProvider {
  @override
  OpenFeatureProviderMetadata get metadata =>
      OpenFeatureProviderMetadata("OpenFeatureNoOpProvider");

  @override
  Future<bool> getBooleanFlag(String flagKey,
      {Map<String, dynamic>? context}) async {
    return false; // Default boolean value.
  }

  @override
  Future<String> getStringFlag(String flagKey,
      {Map<String, dynamic>? context}) async {
    return ""; // Default string value.
  }

  @override
  Future<int> getIntegerFlag(String flagKey,
      {Map<String, dynamic>? context}) async {
    return 0; // Default integer value.
  }

  @override
  Future<double> getDoubleFlag(String flagKey,
      {Map<String, dynamic>? context}) async {
    return 0.0; // Default double value.
  }

  @override
  Future<dynamic> getObjectFlag(String flagKey,
      {Map<String, dynamic>? context}) async {
    return null; // Default object value.
  }
}
