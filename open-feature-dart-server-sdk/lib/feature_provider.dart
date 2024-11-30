// Interface/Contract for feature providers and NoOpProvider.
// Metadata describing the provider.
class ProviderMetadata {
  final String name;

  ProviderMetadata(this.name);
}

// Abstract interface for feature providers.
abstract class FeatureProvider {
  // Returns metadata about the provider.
  ProviderMetadata get metadata;

  // Type-safe flag evaluation methods.
  Future<bool> getBooleanFlag(String flagKey, {Map<String, dynamic>? context});
  Future<String> getStringFlag(String flagKey, {Map<String, dynamic>? context});
  Future<int> getIntegerFlag(String flagKey, {Map<String, dynamic>? context});
  Future<double> getDoubleFlag(String flagKey, {Map<String, dynamic>? context});
  Future<dynamic> getObjectFlag(String flagKey,
      {Map<String, dynamic>? context});
}

// Default NoOpProvider implementation as a safe fallback.
class NoOpProvider implements FeatureProvider {
  @override
  ProviderMetadata get metadata => ProviderMetadata("NoOpProvider");

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
