// Core client interacting with the API.
// Implementation of the feature flag client interface
// Provides the main interaction point for users of the SDK

import 'evaluation_context.dart';
import 'hooks.dart';
import 'feature_provider.dart';

/// Metadata about the client instance
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
class FeatureClient {
  /// Client metadata for identification
  final ClientMetadata metadata;

  /// Hook manager for handling lifecycle events
  final HookManager _hookManager;

  /// Default context used when none is provided
  final EvaluationContext _defaultContext;

  /// Provider for feature flag evaluations
  final FeatureProvider _provider;

  FeatureClient({
    required this.metadata,
    required HookManager hookManager,
    required EvaluationContext defaultContext,
    FeatureProvider? provider,
  })  : _hookManager = hookManager,
        _defaultContext = defaultContext,
        _provider = provider ?? NoOpProvider();

  /// Create hook context for execution
  HookContext _createHookContext(
    String flagKey,
    Map<String, dynamic> context, {
    dynamic result,
    Exception? error,
  }) {
    return HookContext(
      flagKey: flagKey,
      evaluationContext: context,
      result: result,
      error: error,
      metadata: {
        'clientName': metadata.name,
        'clientVersion': metadata.version,
      },
    );
  }

  /// Evaluate a boolean feature flag with hook lifecycle
  Future<bool> getBooleanFlag(
    String flagKey, {
    EvaluationContext? context,
    bool defaultValue = false,
  }) async {
    final evaluationContext = context ?? _defaultContext;
    final currentContext = evaluationContext.attributes;

    try {
      await _hookManager.executeHooks(
        HookStage.BEFORE,
        flagKey,
        currentContext,
      );

      final result = await _provider.getBooleanFlag(
        flagKey,
        defaultValue,
        context: currentContext,
      );

      await _hookManager.executeHooks(
        HookStage.AFTER,
        flagKey,
        currentContext,
        result: result,
      );

      return result.value;
    } catch (e) {
      final error = e is Exception ? e : Exception(e.toString());
      await _hookManager.executeHooks(
        HookStage.ERROR,
        flagKey,
        currentContext,
        error: error, 
      );
      return defaultValue;
    } finally {
      await _hookManager.executeHooks(
        HookStage.FINALLY,
        flagKey,
        currentContext,
      );
    }
  }

  /// Evaluate a string feature flag
  Future<String> getStringFlag(
    String flagKey, {
    EvaluationContext? context,
    String defaultValue = '',
  }) async {
    final evaluationContext = context ?? _defaultContext;
    final currentContext = evaluationContext.attributes;

    try {
      await _hookManager.executeHooks(
        HookStage.BEFORE,
        flagKey,
        currentContext,
      );

      final result = await _provider.getStringFlag(
        flagKey,
        defaultValue,
        context: currentContext,
      );

      await _hookManager.executeHooks(
        HookStage.AFTER,
        flagKey,
        currentContext,
        result: result,
      );

      return result.value;
    } catch (e) {
      final error = e is Exception ? e : Exception(e.toString());
      await _hookManager.executeHooks(
        HookStage.ERROR,
        flagKey,
        currentContext,
        error: error,
      );
      return defaultValue;
    } finally {
      await _hookManager.executeHooks(
        HookStage.FINALLY,
        flagKey,
        currentContext,
      );
    }
  }

  /// Evaluate an integer feature flag
  Future<int> getIntegerFlag(
    String flagKey, {
    EvaluationContext? context,
    int defaultValue = 0,
  }) async {
    final evaluationContext = context ?? _defaultContext;
    final currentContext = evaluationContext.attributes;

    try {
      await _hookManager.executeHooks(
        HookStage.BEFORE,
        flagKey,
        currentContext,
      );

      final result = await _provider.getIntegerFlag(
        flagKey,
        defaultValue,
        context: currentContext,
      );

      await _hookManager.executeHooks(
        HookStage.AFTER,
        flagKey,
        currentContext,
        result: result,
      );

      return result.value;
    } catch (e) {
      final error = e is Exception ? e : Exception(e.toString());
      await _hookManager.executeHooks(
        HookStage.ERROR,
        flagKey,
        currentContext,
        error: error,
      );
      return defaultValue;
    } finally {
      await _hookManager.executeHooks(
        HookStage.FINALLY,
        flagKey,
        currentContext,
      );
    }
  }

  /// Evaluate a double feature flag
  Future<double> getDoubleFlag(
    String flagKey, {
    EvaluationContext? context,
    double defaultValue = 0.0,
  }) async {
    final evaluationContext = context ?? _defaultContext;
    final currentContext = evaluationContext.attributes;

    try {
      await _hookManager.executeHooks(
        HookStage.BEFORE,
        flagKey,
        currentContext,
      );

      final result = await _provider.getDoubleFlag(
        flagKey,
        defaultValue,
        context: currentContext,
      );

      await _hookManager.executeHooks(
        HookStage.AFTER,
        flagKey,
        currentContext,
        result: result,
      );

      return result.value;
    } catch (e) {
      final error = e is Exception ? e : Exception(e.toString());
      await _hookManager.executeHooks(
        HookStage.ERROR,
        flagKey,
        currentContext,
        error: error,
      );
      return defaultValue;
    } finally {
      await _hookManager.executeHooks(
        HookStage.FINALLY,
        flagKey,
        currentContext,
      );
    }
  }

  /// Evaluate an object feature flag
  Future<Map<String, dynamic>> getObjectFlag(
    String flagKey, {
    EvaluationContext? context,
    Map<String, dynamic> defaultValue = const {},
  }) async {
    final evaluationContext = context ?? _defaultContext;
    final currentContext = evaluationContext.attributes;

    try {
      await _hookManager.executeHooks(
        HookStage.BEFORE,
        flagKey,
        currentContext,
      );

      final result = await _provider.getObjectFlag(
        flagKey,
        defaultValue,
        context: currentContext,
      );

      await _hookManager.executeHooks(
        HookStage.AFTER,
        flagKey,
        currentContext,
        result: result,
      );

      return result.value;
    } catch (e) {
      final error = e is Exception ? e : Exception(e.toString());
      await _hookManager.executeHooks(
        HookStage.ERROR,
        flagKey,
        currentContext,
        error: error,
      );
      return defaultValue;
    } finally {
      await _hookManager.executeHooks(
        HookStage.FINALLY,
        flagKey,
        currentContext,
      );
    }
  }
}
