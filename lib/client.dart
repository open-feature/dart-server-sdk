import 'dart:async';
import 'package:logging/logging.dart';
import 'evaluation_context.dart';
import 'feature_provider.dart';
import 'hooks.dart';
import 'open_feature_event.dart';
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
  int trackingEvents = 0;
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
    'trackingEvents': trackingEvents,
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
  final EvaluationContext _apiContext;
  final FeatureProvider _provider;
  final TransactionContextManager _transactionManager;
  final ClientMetrics _metrics = ClientMetrics();
  final StreamController<OpenFeatureEvent> _eventController =
      StreamController<OpenFeatureEvent>.broadcast();
  StreamSubscription<OpenFeatureEvent>? _eventSubscription;

  FeatureClient({
    required this.metadata,
    required HookManager hookManager,
    required EvaluationContext defaultContext,
    EvaluationContext? apiContext,
    FeatureProvider? provider,
    TransactionContextManager? transactionManager,
    Stream<OpenFeatureEvent>? eventStream,
  }) : _hookManager = hookManager,
       _defaultContext = defaultContext,
       _apiContext = apiContext ?? const EvaluationContext(attributes: {}),
       _provider = provider ?? InMemoryProvider({}),
       _transactionManager = transactionManager ?? TransactionContextManager() {
    if (_provider.state == ProviderState.NOT_READY) {
      _provider.initialize();
    }

    if (eventStream != null) {
      _eventSubscription = eventStream.listen(_forwardEvent);
    }
  }

  void _forwardEvent(OpenFeatureEvent event) {
    final eventProvider = event.providerMetadata?.name;
    if (eventProvider == null || eventProvider == _provider.metadata.name) {
      _eventController.add(event);
    }
  }

  Stream<OpenFeatureEvent> get events => _eventController.stream;

  StreamSubscription<OpenFeatureEvent> addHandler(
    void Function(OpenFeatureEvent event) handler,
  ) => events.listen(handler);

  Map<String, dynamic> _buildEffectiveContext(Map<String, dynamic>? context) {
    return {
      ..._apiContext.attributes,
      ..._transactionManager.currentContext?.effectiveAttributes ?? {},
      ..._defaultContext.attributes,
      ...context ?? {},
    };
  }

  FlagValueType _inferFlagValueType<T>(T defaultValue) {
    if (defaultValue is bool) return FlagValueType.BOOLEAN;
    if (defaultValue is String) return FlagValueType.STRING;
    if (defaultValue is int) return FlagValueType.INTEGER;
    if (defaultValue is double) return FlagValueType.DOUBLE;
    return FlagValueType.OBJECT;
  }

  Future<FlagEvaluationResult<T>> _evaluateFlagResult<T>(
    String flagKey,
    T defaultValue,
    Future<FlagEvaluationResult<T>> Function(Map<String, dynamic>?) evaluator, {
    Map<String, dynamic>? context,
  }) async {
    final startTime = DateTime.now();
    final effectiveContext = _buildEffectiveContext(context);
    final hookData = HookData();
    final flagValueType = _inferFlagValueType(defaultValue);
    EvaluationDetails? evaluationDetails;
    Exception? evaluationError;
    _metrics.flagEvaluations++;

    try {
      await _hookManager.executeHooks(
        HookStage.BEFORE,
        flagKey,
        effectiveContext,
        clientMetadata: metadata,
        providerMetadata: _provider.metadata,
        defaultValue: defaultValue,
        flagValueType: flagValueType,
        hookData: hookData,
      );

      final result = await evaluator(effectiveContext);
      evaluationDetails = EvaluationDetails(
        flagKey: result.flagKey,
        value: result.value,
        variant: result.variant,
        reason: result.reason,
        evaluationTime: result.evaluatedAt,
        additionalDetails: result.details,
      );

      await _hookManager.executeHooks(
        HookStage.AFTER,
        flagKey,
        effectiveContext,
        result: result.value,
        evaluationDetails: evaluationDetails,
        clientMetadata: metadata,
        providerMetadata: _provider.metadata,
        defaultValue: defaultValue,
        flagValueType: flagValueType,
        hookData: hookData,
      );

      if (result.errorCode != null) {
        _logger.warning(
          'Flag evaluation error for $flagKey: ${result.errorMessage}',
        );
        _metrics.errorCounts[result.errorCode!.name] =
            (_metrics.errorCounts[result.errorCode!.name] ?? 0) + 1;
      }

      return result;
    } catch (e) {
      evaluationError = e is Exception ? e : Exception(e.toString());
      _logger.warning('Error evaluating flag $flagKey: $e');
      _metrics.errorCounts[e.runtimeType.toString()] =
          (_metrics.errorCounts[e.runtimeType.toString()] ?? 0) + 1;

      await _hookManager.executeHooks(
        HookStage.ERROR,
        flagKey,
        effectiveContext,
        error: evaluationError,
        clientMetadata: metadata,
        providerMetadata: _provider.metadata,
        defaultValue: defaultValue,
        flagValueType: flagValueType,
        hookData: hookData,
      );

      return FlagEvaluationResult.error(
        flagKey,
        defaultValue,
        ErrorCode.GENERAL,
        evaluationError.toString(),
        evaluatorId: _provider.metadata.name,
      );
    } finally {
      _metrics.responseTimes.add(DateTime.now().difference(startTime));
      await _hookManager.executeHooks(
        HookStage.FINALLY,
        flagKey,
        effectiveContext,
        error: evaluationError,
        evaluationDetails: evaluationDetails,
        clientMetadata: metadata,
        providerMetadata: _provider.metadata,
        defaultValue: defaultValue,
        flagValueType: flagValueType,
        hookData: hookData,
      );
    }
  }

  /// Generic flag evaluation orchestrator
  Future<T> _evaluateFlag<T>(
    String flagKey,
    T defaultValue,
    Future<FlagEvaluationResult<T>> Function(Map<String, dynamic>?) evaluator, {
    Map<String, dynamic>? context,
  }) async {
    final result = await _evaluateFlagResult(
      flagKey,
      defaultValue,
      evaluator,
      context: context,
    );
    return result.value;
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

  /// Tracking API (spec Section 6) - record a tracking event
  Future<void> track(
    String trackingEventName, {
    EvaluationContext? context,
    TrackingEventDetails? trackingDetails,
  }) async {
    _metrics.trackingEvents++;
    final effectiveContext = _buildEffectiveContext(context?.attributes);

    try {
      await _provider.track(
        trackingEventName,
        evaluationContext: effectiveContext,
        trackingDetails: trackingDetails,
      );
    } catch (e) {
      _logger.warning('Error sending tracking event "$trackingEventName": $e');
    }
  }

  ClientMetrics getMetrics() => _metrics;

  /// Access to provider for management operations
  FeatureProvider get provider => _provider;

  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    await _eventController.close();
  }
}

/// Extension to add evaluation details methods
extension ClientEvaluationDetails on FeatureClient {
  /// Get boolean flag with full evaluation details
  Future<FlagEvaluationDetails<bool>> getBooleanDetails(
    String flagKey, {
    EvaluationContext? context,
    bool defaultValue = false,
  }) async {
    final result = await _evaluateFlagResult(
      flagKey,
      defaultValue,
      (ctx) => _provider.getBooleanFlag(flagKey, defaultValue, context: ctx),
      context: context?.attributes,
    );

    return FlagEvaluationDetails.fromResult(result);
  }

  /// Get string flag with full evaluation details
  Future<FlagEvaluationDetails<String>> getStringDetails(
    String flagKey, {
    EvaluationContext? context,
    String defaultValue = '',
  }) async {
    final result = await _evaluateFlagResult(
      flagKey,
      defaultValue,
      (ctx) => _provider.getStringFlag(flagKey, defaultValue, context: ctx),
      context: context?.attributes,
    );

    return FlagEvaluationDetails.fromResult(result);
  }

  /// Get integer flag with full evaluation details
  Future<FlagEvaluationDetails<int>> getIntegerDetails(
    String flagKey, {
    EvaluationContext? context,
    int defaultValue = 0,
  }) async {
    final result = await _evaluateFlagResult(
      flagKey,
      defaultValue,
      (ctx) => _provider.getIntegerFlag(flagKey, defaultValue, context: ctx),
      context: context?.attributes,
    );

    return FlagEvaluationDetails.fromResult(result);
  }

  /// Get double flag with full evaluation details
  Future<FlagEvaluationDetails<double>> getDoubleDetails(
    String flagKey, {
    EvaluationContext? context,
    double defaultValue = 0.0,
  }) async {
    final result = await _evaluateFlagResult(
      flagKey,
      defaultValue,
      (ctx) => _provider.getDoubleFlag(flagKey, defaultValue, context: ctx),
      context: context?.attributes,
    );

    return FlagEvaluationDetails.fromResult(result);
  }

  /// Get object flag with full evaluation details
  Future<FlagEvaluationDetails<Map<String, dynamic>>> getObjectDetails(
    String flagKey, {
    EvaluationContext? context,
    Map<String, dynamic> defaultValue = const {},
  }) async {
    final result = await _evaluateFlagResult(
      flagKey,
      defaultValue,
      (ctx) => _provider.getObjectFlag(flagKey, defaultValue, context: ctx),
      context: context?.attributes,
    );

    return FlagEvaluationDetails.fromResult(result);
  }
}
