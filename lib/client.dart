import 'dart:async';
import 'package:logging/logging.dart';
import 'evaluation_context.dart';
import 'hooks.dart';
import 'feature_provider.dart';
import 'transaction_context.dart';

class CacheEntry<T> {
  final T value;
  final DateTime expiresAt;
  final String contextHash;

  CacheEntry({
    required this.value,
    required Duration ttl,
    required this.contextHash,
  }) : expiresAt = DateTime.now().add(ttl);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

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

class ClientMetrics {
  int flagEvaluations = 0;
  int cacheHits = 0;
  int cacheMisses = 0;
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
    'cacheHits': cacheHits,
    'cacheMisses': cacheMisses,
    'averageResponseTime': averageResponseTime.inMilliseconds,
    'errorCounts': errorCounts,
  };
}

class FeatureClient {
  final Logger _logger = Logger('FeatureClient');
  final ClientMetadata metadata;
  final HookManager _hookManager;
  final EvaluationContext _defaultContext;
  final FeatureProvider _provider;
  final TransactionContextManager _transactionManager;
  final ClientMetrics _metrics = ClientMetrics();

  final Duration _cacheTtl;
  final int _maxCacheSize;
  final Map<String, CacheEntry<dynamic>> _cache = {};

  FeatureClient({
    required this.metadata,
    required HookManager hookManager,
    required EvaluationContext defaultContext,
    FeatureProvider? provider,
    TransactionContextManager? transactionManager,
    Duration cacheTtl = const Duration(minutes: 5),
    int maxCacheSize = 1000,
  }) : _hookManager = hookManager,
       _defaultContext = defaultContext,
       _provider = provider ?? InMemoryProvider({}),
       _transactionManager = transactionManager ?? TransactionContextManager(),
       _cacheTtl = cacheTtl,
       _maxCacheSize = maxCacheSize {
    // Ensure provider is initialized
    if (_provider.state == ProviderState.NOT_READY) {
      _provider.initialize();
    }
  }

  String _generateCacheKey(String flagKey, Map<String, dynamic>? context) {
    final buffer = StringBuffer(flagKey);
    if (context != null) {
      buffer.write(context.toString());
    }
    return buffer.toString();
  }

  void _addToCache<T>(String key, T value, String contextHash) {
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = CacheEntry<T>(
      value: value,
      ttl: _cacheTtl,
      contextHash: contextHash,
    );
  }

  T? _getFromCache<T>(String key, String contextHash) {
    final entry = _cache[key];
    if (entry == null || entry.isExpired || entry.contextHash != contextHash) {
      _metrics.cacheMisses++;
      _cache.remove(key);
      return null;
    }
    _metrics.cacheHits++;
    return entry.value as T;
  }

  Future<T> _evaluateFlag<T>(
    String flagKey,
    T defaultValue,
    Future<FlagEvaluationResult<T>> Function(Map<String, dynamic>?) evaluator, {
    Map<String, dynamic>? context,
  }) async {
    final startTime = DateTime.now();
    _metrics.flagEvaluations++;

    try {
      final effectiveContext = {
        ..._defaultContext.attributes,
        ...context ?? {},
        ..._transactionManager.currentContext?.effectiveAttributes ?? {},
      };

      final cacheKey = _generateCacheKey(flagKey, effectiveContext);
      final contextHash = effectiveContext.toString();

      final cachedValue = _getFromCache<T>(cacheKey, contextHash);
      if (cachedValue != null) {
        return cachedValue;
      }

      await _hookManager.executeHooks(
        HookStage.BEFORE,
        flagKey,
        effectiveContext,
      );

      final result = await evaluator(effectiveContext);

      await _hookManager.executeHooks(
        HookStage.AFTER,
        flagKey,
        effectiveContext,
        result: result,
      );

      _addToCache(cacheKey, result.value, contextHash);

      // Handle errors from the provider
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

      await _hookManager.executeHooks(
        HookStage.ERROR,
        flagKey,
        context,
        error: e is Exception ? e : Exception(e.toString()),
      );
      return defaultValue;
    } finally {
      await _hookManager.executeHooks(HookStage.FINALLY, flagKey, context);
    }
  }

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

  void clearCache() => _cache.clear();
}
