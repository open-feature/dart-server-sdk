// Implementation of the OpenFeatureAPI singleton.

import 'dart:async';
import 'package:meta/meta.dart'; // Required for @visibleForTesting

// Abstract FeatureProvider interface for extensibility.
abstract class FeatureProvider {
  String get name;

  // Generic method to get a feature flag's value.
  Future<dynamic> getFlag(String flagKey, {Map<String, dynamic>? context});
}

// Default NoOpProvider implementation as a safe fallback.
class NoOpProvider implements FeatureProvider {
  @override
  String get name => "NoOpProvider";

  @override
  Future<dynamic> getFlag(String flagKey,
      {Map<String, dynamic>? context}) async {
    // Return null or default values for flags.
    return null;
  }
}

// Global evaluation context shared across feature evaluations.
class EvaluationContext {
  final Map<String, dynamic> attributes;

  EvaluationContext(this.attributes);

  /// Merge this context with another context.
  EvaluationContext merge(EvaluationContext other) {
    return EvaluationContext({...attributes, ...other.attributes});
  }
}

// Abstract Hook interface for pre/post evaluation logic.
abstract class Hook {
  void beforeEvaluation(String flagKey, Map<String, dynamic>? context);
  void afterEvaluation(
      String flagKey, dynamic result, Map<String, dynamic>? context);
}

// Singleton implementation of OpenFeatureAPI.
class OpenFeatureAPI {
  // Singleton instance
  static OpenFeatureAPI? _instance; // Nullable to allow reinitialization

  // Default provider (NoOpProvider initially)
  FeatureProvider _provider = NoOpProvider();

  // Global hooks and evaluation context
  final List<Hook> _hooks = [];
  EvaluationContext? _globalContext;

  // StreamController for provider updates
  late final StreamController<FeatureProvider> _providerStreamController;

  // Private constructor
  OpenFeatureAPI._internal() {
    _providerStreamController = StreamController<FeatureProvider>.broadcast();
  }

  // Factory constructor for singleton instance
  factory OpenFeatureAPI() {
    _instance ??= OpenFeatureAPI._internal();
    return _instance!;
  }

  /// Dispose resources, particularly the StreamController.
  void dispose() {
    _providerStreamController.close();
  }

  /// Set the active feature provider and notify listeners.
  void setProvider(FeatureProvider provider) {
    _provider = provider;
    _providerStreamController
        .add(provider); // Notify listeners about the change.
  }

  /// Get the active feature provider.
  FeatureProvider get provider => _provider;

  /// Set the global evaluation context for the API.
  void setGlobalContext(EvaluationContext context) {
    _globalContext = context;
  }

  /// Get the current global evaluation context.
  EvaluationContext? get globalContext => _globalContext;

  /// Add global hooks to the API.
  void addHooks(List<Hook> hooks) {
    _hooks.addAll(hooks);
  }

  /// Retrieve the global hooks.
  List<Hook> get hooks => List.unmodifiable(_hooks);

  /// Stream to listen for provider updates.
  Stream<FeatureProvider> get providerUpdates =>
      _providerStreamController.stream;

  /// Reset the singleton instance for testing purposes.
  ///
  /// This ensures a clean state for each test case.
  @visibleForTesting
  static void resetInstance() {
    _instance
        ?.dispose(); // Call the public dispose() method to clean up resources.
    _instance = null; // Reset the singleton.
  }

  /// Evaluate a boolean flag with the hook lifecycle.
  Future<bool> evaluateBooleanFlag(String flagKey,
      {Map<String, dynamic>? context}) async {
    _runBeforeEvaluationHooks(flagKey, context);

    // Perform evaluation using the provider
    final result = await _provider.getFlag(flagKey, context: context);

    _runAfterEvaluationHooks(flagKey, result, context);

    return result ?? false; // Default to false if no result
  }

  /// Run hooks before evaluation.
  void _runBeforeEvaluationHooks(
      String flagKey, Map<String, dynamic>? context) {
    for (var hook in _hooks) {
      hook.beforeEvaluation(flagKey, context);
    }
  }

  /// Run hooks after evaluation.
  void _runAfterEvaluationHooks(
      String flagKey, dynamic result, Map<String, dynamic>? context) {
    for (var hook in _hooks) {
      hook.afterEvaluation(flagKey, result, context);
    }
  }
}
