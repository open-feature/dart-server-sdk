import 'dart:async';
import 'package:logging/logging.dart';
import 'evaluation_context.dart';
import 'hooks.dart';
import 'feature_provider.dart';
import 'transaction_context.dart';

/// Client metadata for identification
class ClientMetadata {
  final String name;
  final String version;
  final Map<String, String> attributes;

  ClientMetadata({
    required this.name,
    this.version = '1.0.0',
    this.attributes = const {},
  });
}

/// Client metrics for monitoring
class ClientMetrics {
  int flagEvaluations = 0;
  List<Duration> responseTimes = [];
  Map<String, int> errorCounts = {};

  Duration get averageResponseTime {
    if (responseTimes.isEmpty) return Duration.zero;
    final total = responseTimes.fold<int>(
      0,
      (sum, duration) => sum + duration.inMilliseconds,
    );
    return Duration(milliseconds: total ~/ responseTimes.length);
  }

  Map<String, dynamic> toJson() => {
    'flagEvaluations': flagEvaluations,
    'averageResponseTime': averageResponseTime.inMilliseconds,
    'errorCounts': errorCounts,
  };
}

/// Feature client - orchestrates evaluation without caching
class FeatureClient {
  final Logger _logger = Logger('FeatureClient');
  final ClientMetadata metadata;
  final HookManager _hookManager;
  final EvaluationContext _defaultContext;
  final FeatureProvider _provider;
  final TransactionContextManager _transactionManager;
  final ClientMetrics _metrics = ClientMetrics();

  FeatureClient({
    required this.metadata,
    required HookManager hookManager,
    required EvaluationContext defaultContext,
    FeatureProvider? provider,
    TransactionContextManager? transactionManager,
  }) : _hookManager = hookManager,
       _defaultContext = defaultContext,
       _provider = provider ?? InMemoryProvider({}),
       _transactionManager = transactionManager ?? TransactionContextManager() {
    // Ensure provider is initialized
    if (_provider.state == ProviderState.NOT_READY) {
      _provider.initialize();
    }
  }

  /// Generic flag evaluation orchestrator
  Future<T> _evaluateFlag<T>(
    String flagKey,
    T defaultValue,
    Future<FlagEvaluationResult<T>> Function(Map<String, dynamic>?) evaluator, {
    Map<String, dynamic>? context,
  }) async {
    final startTime = DateTime.now();
    _metrics.flagEvaluations++;

    try {
      // Build effective context from default, provided, and transaction contexts
      final effectiveContext = {
        ..._defaultContext.attributes,
        ...context ?? {},
        ..._transactionManager.currentContext?.effectiveAttributes ?? {},
      };

      // Execute before hooks
      await _hookManager.executeHooks(
        HookStage.BEFORE,
        flagKey,
        effectiveContext,
        clientMetadata: metadata,
        providerMetadata: _provider.metadata,
      );

      // Delegate to provider (which handles caching)
      final result = await evaluator(effectiveContext);

      // Execute after hooks
      await _hookManager.executeHooks(
        HookStage.AFTER,
        flagKey,
        effectiveContext,
        result: result,
        clientMetadata: metadata,
        providerMetadata: _provider.metadata,
      );

      // Track errors from provider
      if (result.errorCode != null) {
        _logger.warning(
          'Flag evaluation error for $flagKey: ${result.errorMessage}',
        );
        _metrics.errorCounts[result.errorCode!.name] =
            (_metrics.errorCounts[result.errorCode!.name] ?? 0) + 1;
      }

      _metrics.responseTimes.add(DateTime.now().difference(startTime));
      return result.value;
    } catch (e) {
      _logger.warning('Error evaluating flag $flagKey: $e');
      _metrics.errorCounts[e.runtimeType.toString()] =
          (_metrics.errorCounts[e.runtimeType.toString()] ?? 0) + 1;

      // Execute error hooks
      await _hookManager.executeHooks(
        HookStage.ERROR,
        flagKey,
        context,
        error: e is Exception ? e : Exception(e.toString()),
        clientMetadata: metadata,
        providerMetadata: _provider.metadata,
      );
      return defaultValue;
    } finally {
      // Execute finally hooks
      await _hookManager.executeHooks(
        HookStage.FINALLY,
        flagKey,
        context,
        clientMetadata: metadata,
        providerMetadata: _provider.metadata,
      );
    }
  }

  /// Evaluate boolean flag
  Future<bool> getBooleanFlag(
    String flagKey, {
    EvaluationContext? context,
    bool defaultValue = false,
  }) => _evaluateFlag(
    flagKey,
    defaultValue,
    (ctx) => _provider.getBooleanFlag(flagKey, defaultValue, context: ctx),
    context: context?.attributes,
  );

  /// Evaluate string flag
  Future<String> getStringFlag(
    String flagKey, {
    EvaluationContext? context,
    String defaultValue = '',
  }) => _evaluateFlag(
    flagKey,
    defaultValue,
    (ctx) => _provider.getStringFlag(flagKey, defaultValue, context: ctx),
    context: context?.attributes,
  );

  /// Evaluate integer flag
  Future<int> getIntegerFlag(
    String flagKey, {
    EvaluationContext? context,
    int defaultValue = 0,
  }) => _evaluateFlag(
    flagKey,
    defaultValue,
    (ctx) => _provider.getIntegerFlag(flagKey, defaultValue, context: ctx),
    context: context?.attributes,
  );

  /// Evaluate double flag
  Future<double> getDoubleFlag(
    String flagKey, {
    EvaluationContext? context,
    double defaultValue = 0.0,
  }) => _evaluateFlag(
    flagKey,
    defaultValue,
    (ctx) => _provider.getDoubleFlag(flagKey, defaultValue, context: ctx),
    context: context?.attributes,
  );

  Future<Map<String, dynamic>> getObjectFlag(
    String flagKey, {
    EvaluationContext? context,
    Map<String, dynamic> defaultValue = const {},
  }) => _evaluateFlag(
    flagKey,
    defaultValue,
    (ctx) => _provider.getObjectFlag(flagKey, defaultValue, context: ctx),
    context: context?.attributes,
  );

  ClientMetrics getMetrics() => _metrics;

  /// Access to provider for management operations
  FeatureProvider get provider => _provider;
}

/// Extension to add evaluation details methods
extension ClientEvaluationDetails on FeatureClient {
  /// Get boolean flag with full evaluation details
  Future<FlagEvaluationDetails<bool>> getBooleanDetails(
    String flagKey, {
    EvaluationContext? context,
    bool defaultValue = false,
  }) async {
    final value = await getBooleanFlag(
      flagKey,
      context: context,
      defaultValue: defaultValue,
    );

    // Get the result from provider for details
    final effectiveContext = {
      ..._defaultContext.attributes,
      ...context?.attributes ?? {},
      ..._transactionManager.currentContext?.effectiveAttributes ?? {},
    };

    final result = await _provider.getBooleanFlag(
      flagKey,
      defaultValue,
      context: effectiveContext,
    );

    return FlagEvaluationDetails.fromResult(result);
  }

  /// Get string flag with full evaluation details
  Future<FlagEvaluationDetails<String>> getStringDetails(
    String flagKey, {
    EvaluationContext? context,
    String defaultValue = '',
  }) async {
    final value = await getStringFlag(
      flagKey,
      context: context,
      defaultValue: defaultValue,
    );

    final effectiveContext = {
      ..._defaultContext.attributes,
      ...context?.attributes ?? {},
      ..._transactionManager.currentContext?.effectiveAttributes ?? {},
    };

    final result = await _provider.getStringFlag(
      flagKey,
      defaultValue,
      context: effectiveContext,
    );

    return FlagEvaluationDetails.fromResult(result);
  }

  /// Get integer flag with full evaluation details
  Future<FlagEvaluationDetails<int>> getIntegerDetails(
    String flagKey, {
    EvaluationContext? context,
    int defaultValue = 0,
  }) async {
    final value = await getIntegerFlag(
      flagKey,
      context: context,
      defaultValue: defaultValue,
    );

    final effectiveContext = {
      ..._defaultContext.attributes,
      ...context?.attributes ?? {},
      ..._transactionManager.currentContext?.effectiveAttributes ?? {},
    };

    final result = await _provider.getIntegerFlag(
      flagKey,
      defaultValue,
      context: effectiveContext,
    );

    return FlagEvaluationDetails.fromResult(result);
  }

  /// Get double flag with full evaluation details
  Future<FlagEvaluationDetails<double>> getDoubleDetails(
    String flagKey, {
    EvaluationContext? context,
    double defaultValue = 0.0,
  }) async {
    final value = await getDoubleFlag(
      flagKey,
      context: context,
      defaultValue: defaultValue,
    );

    final effectiveContext = {
      ..._defaultContext.attributes,
      ...context?.attributes ?? {},
      ..._transactionManager.currentContext?.effectiveAttributes ?? {},
    };

    final result = await _provider.getDoubleFlag(
      flagKey,
      defaultValue,
      context: effectiveContext,
    );

    return FlagEvaluationDetails.fromResult(result);
  }

  /// Get object flag with full evaluation details
  Future<FlagEvaluationDetails<Map<String, dynamic>>> getObjectDetails(
    String flagKey, {
    EvaluationContext? context,
    Map<String, dynamic> defaultValue = const {},
  }) async {
    final value = await getObjectFlag(
      flagKey,
      context: context,
      defaultValue: defaultValue,
    );

    final effectiveContext = {
      ..._defaultContext.attributes,
      ...context?.attributes ?? {},
      ..._transactionManager.currentContext?.effectiveAttributes ?? {},
    };

    final result = await _provider.getObjectFlag(
      flagKey,
      defaultValue,
      context: effectiveContext,
    );

    return FlagEvaluationDetails.fromResult(result);
  }
}
