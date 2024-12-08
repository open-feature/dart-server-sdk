// Core client interacting with the API.
// Implementation of the feature flag client interface
// Provides the main interaction point for users of the SDK

import 'evaluation_context.dart';
import 'hooks.dart';
import 'feature_provider.dart';

/// Metadata about the client instance
/// Used to identify and configure the client
class ClientMetadata {
  /// Name of the client instance
  final String name;

  /// Version of the client
  final String version;

  /// Additional attributes for the client
  final Map<String, String> attributes;

  ClientMetadata({
    required this.name,
    this.version = '1.0.0',
    this.attributes = const {},
  });
}

/// Main client interface for interacting with feature flags
/// Handles flag evaluation with context and hooks support
class FeatureClient {
  /// Client metadata for identification
  final ClientMetadata metadata;

  /// Hook manager for handling lifecycle events
  final HookManager _hookManager;

  /// Default context used when none is provided
  final EvaluationContext _defaultContext;

  /// Provider for feature flag evaluations
  final OpenFeatureProvider _provider;

  FeatureClient({
    required this.metadata,
    required HookManager hookManager,
    required EvaluationContext defaultContext,
    OpenFeatureProvider? provider,
  })  : _hookManager = hookManager,
        _defaultContext = defaultContext,
        _provider = provider ?? OpenFeatureNoOpProvider();

  /// Evaluate a boolean feature flag with hook lifecycle
  Future<bool> getBooleanFlag(
    String flagKey, {
    EvaluationContext? context,
    bool defaultValue = false,
  }) async {
    final evaluationContext = context ?? _defaultContext;

    try {
      // Execute before hooks
      await _hookManager.executeHooks(
        HookStage.before,
        flagKey,
        evaluationContext.attributes,
      );

      // Evaluate flag using provider
      final result = await _provider.getBooleanFlag(
        flagKey,
        context: evaluationContext.attributes,
      );

      // Execute after hooks
      await _hookManager.executeHooks(
        HookStage.after,
        flagKey,
        evaluationContext.attributes,
        result: result,
      );

      return result;
    } catch (e) {
      // Execute error hooks and handle exception
      await _hookManager.executeHooks(
        HookStage.error,
        flagKey,
        evaluationContext.attributes,
        error: e is Exception ? e : Exception(e.toString()),
      );
      return defaultValue;
    } finally {
      // Always execute finally hooks
      await _hookManager.executeHooks(
        HookStage.finally_,
        flagKey,
        evaluationContext.attributes,
      );
    }
  }

  // TODO: Implement other flag type methods (string, number, object)
  // Following the same pattern as getBooleanFlag
}
