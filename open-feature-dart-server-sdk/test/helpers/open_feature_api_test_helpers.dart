import '../../lib/open_feature_api.dart'; // Adjust path if necessary

/// Extension for OpenFeatureAPI to add test-specific utilities.
extension OpenFeatureAPITestHelpers on OpenFeatureAPI {
  /// Resets the singleton instance for testing purposes.
  ///
  /// This ensures a clean state for each test case, avoiding conflicts or
  /// state leakage from previous tests.
  static void reset() {
    OpenFeatureAPI.resetInstance(); // Call the public resetInstance method
  }
}
