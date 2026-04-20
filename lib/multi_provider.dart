import 'feature_provider.dart';

/// Strategy for selecting a result from multiple providers.
abstract class MultiProviderStrategy {
  const MultiProviderStrategy();

  Future<FlagEvaluationResult<T>> evaluate<T>({
    required String flagKey,
    required T defaultValue,
    required List<FeatureProvider> providers,
    required Future<FlagEvaluationResult<T>> Function(FeatureProvider provider)
    evaluator,
  });
}

/// Default Multi-Provider strategy.
///
/// Providers are evaluated in order. `FLAG_NOT_FOUND` results are treated as a
/// miss and the next provider is consulted. The first successful result wins.
/// If every provider misses, a single `FLAG_NOT_FOUND` result is returned. If
/// no provider succeeds and at least one provider returns another error, the
/// first non-`FLAG_NOT_FOUND` error is returned.
class FirstMatchStrategy extends MultiProviderStrategy {
  const FirstMatchStrategy();

  @override
  Future<FlagEvaluationResult<T>> evaluate<T>({
    required String flagKey,
    required T defaultValue,
    required List<FeatureProvider> providers,
    required Future<FlagEvaluationResult<T>> Function(FeatureProvider provider)
    evaluator,
  }) async {
    FlagEvaluationResult<T>? firstError;

    for (final provider in providers) {
      final result = await evaluator(provider);
      if (result.errorCode == null) {
        return result;
      }

      if (result.errorCode != ErrorCode.FLAG_NOT_FOUND) {
        firstError ??= result;
      }
    }

    return firstError ??
        FlagEvaluationResult.error(
          flagKey,
          defaultValue,
          ErrorCode.FLAG_NOT_FOUND,
          'Flag "$flagKey" was not found in any configured provider.',
          evaluatorId: 'MultiProvider',
        );
  }
}

/// Experimental SDK-level utility for composing multiple providers behind one
/// spec-compliant provider interface.
class MultiProvider implements FeatureProvider {
  final List<FeatureProvider> _providers;
  final MultiProviderStrategy _strategy;
  final ProviderConfig _config;
  final ProviderMetadata _metadata;

  MultiProvider(
    List<FeatureProvider> providers, {
    MultiProviderStrategy strategy = const FirstMatchStrategy(),
    ProviderConfig config = const ProviderConfig(),
    ProviderMetadata metadata = const ProviderMetadata(
      name: 'MultiProvider',
      version: '0.1.0',
    ),
  }) : assert(
         providers.length > 0,
         'MultiProvider requires at least one provider',
       ),
       _providers = List.unmodifiable(providers),
       _strategy = strategy,
       _config = config,
       _metadata = metadata;

  List<FeatureProvider> get providers => _providers;

  @override
  String get name => _metadata.name;

  @override
  ProviderConfig get config => _config;

  @override
  ProviderMetadata get metadata => _metadata;

  @override
  ProviderState get state => _aggregateState(_providers.map((p) => p.state));

  @override
  Future<void> initialize([Map<String, dynamic>? config]) async {
    final errors = await _collectErrors(
      _providers.map(
        (provider) async {
          if (provider.state == ProviderState.NOT_READY) {
            await provider.initialize(config);
          }
        },
      ),
    );

    _throwIfNoProviderReady(errors, 'initialize');
  }

  @override
  Future<void> connect() async {
    final errors = await _collectErrors(
      _providers.map((provider) => provider.connect()),
    );

    _throwIfNoProviderReady(errors, 'connect');
  }

  @override
  Future<void> shutdown() async {
    final errors = <Object>[];
    for (final provider in _providers) {
      try {
        await provider.shutdown();
      } catch (error) {
        errors.add(error);
      }
    }

    if (errors.isNotEmpty) {
      throw ProviderException(
        'One or more providers failed to shut down.',
        code: ErrorCode.GENERAL,
        details: {'errors': errors.map((e) => e.toString()).toList()},
      );
    }
  }

  @override
  Future<void> track(
    String trackingEventName, {
    Map<String, dynamic>? evaluationContext,
    TrackingEventDetails? trackingDetails,
  }) async {
    await _collectErrors(
      _providers.map(
        (provider) => provider.track(
          trackingEventName,
          evaluationContext: evaluationContext,
          trackingDetails: trackingDetails,
        ),
      ),
    );
  }

  @override
  Future<FlagEvaluationResult<bool>> getBooleanFlag(
    String flagKey,
    bool defaultValue, {
    Map<String, dynamic>? context,
  }) => _evaluate(
    flagKey,
    defaultValue,
    (provider) =>
        provider.getBooleanFlag(flagKey, defaultValue, context: context),
  );

  @override
  Future<FlagEvaluationResult<String>> getStringFlag(
    String flagKey,
    String defaultValue, {
    Map<String, dynamic>? context,
  }) => _evaluate(
    flagKey,
    defaultValue,
    (provider) =>
        provider.getStringFlag(flagKey, defaultValue, context: context),
  );

  @override
  Future<FlagEvaluationResult<int>> getIntegerFlag(
    String flagKey,
    int defaultValue, {
    Map<String, dynamic>? context,
  }) => _evaluate(
    flagKey,
    defaultValue,
    (provider) =>
        provider.getIntegerFlag(flagKey, defaultValue, context: context),
  );

  @override
  Future<FlagEvaluationResult<double>> getDoubleFlag(
    String flagKey,
    double defaultValue, {
    Map<String, dynamic>? context,
  }) => _evaluate(
    flagKey,
    defaultValue,
    (provider) =>
        provider.getDoubleFlag(flagKey, defaultValue, context: context),
  );

  @override
  Future<FlagEvaluationResult<Map<String, dynamic>>> getObjectFlag(
    String flagKey,
    Map<String, dynamic> defaultValue, {
    Map<String, dynamic>? context,
  }) => _evaluate(
    flagKey,
    defaultValue,
    (provider) =>
        provider.getObjectFlag(flagKey, defaultValue, context: context),
  );

  Future<FlagEvaluationResult<T>> _evaluate<T>(
    String flagKey,
    T defaultValue,
    Future<FlagEvaluationResult<T>> Function(FeatureProvider provider)
    evaluator,
  ) async {
    final result = await _strategy.evaluate(
      flagKey: flagKey,
      defaultValue: defaultValue,
      providers: _providers,
      evaluator: evaluator,
    );

    if (result.evaluatorId.isNotEmpty) {
      return result;
    }

    return FlagEvaluationResult<T>(
      flagKey: result.flagKey,
      value: result.value,
      reason: result.reason,
      variant: result.variant,
      errorCode: result.errorCode,
      errorMessage: result.errorMessage,
      details: result.details,
      evaluatedAt: result.evaluatedAt,
      evaluatorId: name,
    );
  }

  Future<List<Object>> _collectErrors(
    Iterable<Future<void>> operations,
  ) async {
    final results = await Future.wait<Object?>(
      operations.map((operation) async {
        try {
          await operation;
          return null;
        } catch (error) {
          return error;
        }
      }),
    );

    return results.whereType<Object>().toList(growable: false);
  }

  void _throwIfNoProviderReady(List<Object> errors, String operation) {
    if (_providers.any((provider) => provider.state == ProviderState.READY)) {
      return;
    }

    if (errors.isEmpty) {
      throw ProviderException(
        'No provider reached READY state during $operation.',
        code: ErrorCode.PROVIDER_NOT_READY,
      );
    }

    throw ProviderException(
      'No provider reached READY state during $operation.',
      code: ErrorCode.PROVIDER_NOT_READY,
      details: {'errors': errors.map((e) => e.toString()).toList()},
    );
  }

  ProviderState _aggregateState(Iterable<ProviderState> states) {
    final normalizedStates = states.map(_normalizeState).toList();
    if (normalizedStates.contains(ProviderState.FATAL)) {
      return ProviderState.FATAL;
    }
    if (normalizedStates.contains(ProviderState.NOT_READY)) {
      return ProviderState.NOT_READY;
    }
    if (normalizedStates.contains(ProviderState.ERROR)) {
      return ProviderState.ERROR;
    }
    if (normalizedStates.contains(ProviderState.STALE)) {
      return ProviderState.STALE;
    }
    return ProviderState.READY;
  }

  ProviderState _normalizeState(ProviderState state) {
    switch (state) {
      case ProviderState.FATAL:
        return ProviderState.FATAL;
      case ProviderState.NOT_READY:
      case ProviderState.CONNECTING:
      case ProviderState.SHUTDOWN:
        return ProviderState.NOT_READY;
      case ProviderState.ERROR:
      case ProviderState.DEGRADED:
      case ProviderState.RECONNECTING:
      case ProviderState.PLUGIN_ERROR:
        return ProviderState.ERROR;
      case ProviderState.STALE:
      case ProviderState.SYNCHRONIZING:
      case ProviderState.MAINTENANCE:
        return ProviderState.STALE;
      case ProviderState.READY:
        return ProviderState.READY;
    }
  }
}
