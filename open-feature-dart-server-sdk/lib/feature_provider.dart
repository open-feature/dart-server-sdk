import 'dart:async';

/// Provider states for lifecycle management
enum ProviderState {
  READY,
  ERROR,
  NOT_READY,
  SHUTDOWN,
  CONNECTING,
  SYNCHRONIZING,
  DEGRADED,
  RECONNECTING,
  PLUGIN_ERROR,
  MAINTENANCE
}

/// Provider configuration
class ProviderConfig {
  final Duration connectionTimeout;
  final Duration operationTimeout;
  final int maxRetries;
  final Duration retryDelay;
  final bool enableCache;
  final Duration cacheTTL;
  final Map<String, dynamic> customConfig;

  const ProviderConfig({
    this.connectionTimeout = const Duration(seconds: 30),
    this.operationTimeout = const Duration(seconds: 5),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.enableCache = true,
    this.cacheTTL = const Duration(minutes: 5),
    this.customConfig = const {},
  });
}

/// Result of feature flag evaluation
class FlagEvaluationResult<T> {
  final String flagKey;
  final T value;
  final String reason;
  final Map<String, dynamic>? details;
  final DateTime evaluatedAt;
  final String evaluatorId;

  const FlagEvaluationResult({
    required this.flagKey,
    required this.value,
    this.reason = 'DEFAULT',
    this.details,
    required this.evaluatedAt,
    this.evaluatorId = '',
  });
}

/// Provider exception
class ProviderException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? details;

  const ProviderException(
    this.message, {
    this.code = 'PROVIDER_ERROR',
    this.details,
  });

  @override
  String toString() => 'ProviderException: $message (code: $code)';
}

/// Feature provider interface
abstract class FeatureProvider {
  String get name;
  ProviderState get state;
  ProviderConfig get config;

  Future<void> initialize([Map<String, dynamic>? config]);
  Future<void> connect();
  Future<void> shutdown();

  Future<FlagEvaluationResult<bool>> getBooleanFlag(
    String flagKey,
    bool defaultValue, {
    Map<String, dynamic>? context,
  });

  Future<FlagEvaluationResult<String>> getStringFlag(
    String flagKey,
    String defaultValue, {
    Map<String, dynamic>? context,
  });

  Future<FlagEvaluationResult<int>> getIntegerFlag(
    String flagKey,
    int defaultValue, {
    Map<String, dynamic>? context,
  });

  Future<FlagEvaluationResult<double>> getDoubleFlag(
    String flagKey,
    double defaultValue, {
    Map<String, dynamic>? context,
  });

  Future<FlagEvaluationResult<Map<String, dynamic>>> getObjectFlag(
    String flagKey,
    Map<String, dynamic> defaultValue, {
    Map<String, dynamic>? context,
  });
}

/// In-memory provider implementation
class InMemoryProvider implements FeatureProvider {
  final Map<String, dynamic> _flags;
  ProviderState _state = ProviderState.NOT_READY;
  final ProviderConfig _config;

  InMemoryProvider(this._flags, [ProviderConfig? config])
      : _config = config ?? const ProviderConfig();

  @override
  String get name => 'InMemoryProvider';

  @override
  ProviderState get state => _state;

  @override
  ProviderConfig get config => _config;

  @override
  Future<void> initialize([Map<String, dynamic>? config]) async {
    _state = ProviderState.READY;
  }

  @override
  Future<void> connect() async {
    _state = ProviderState.READY;
  }

  @override
  Future<void> shutdown() async {
    _state = ProviderState.SHUTDOWN;
  }

  void _checkState() {
    if (_state != ProviderState.READY) {
      throw ProviderException(
        'Provider not in READY state',
        code: 'PROVIDER_NOT_READY',
        details: {'currentState': _state.toString()},
      );
    }
  }

  @override
  Future<FlagEvaluationResult<bool>> getBooleanFlag(
    String flagKey,
    bool defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    _checkState();
    final value = _flags[flagKey] ?? defaultValue;
    return FlagEvaluationResult(
      flagKey: flagKey,
      value: value is bool ? value : defaultValue,
      evaluatedAt: DateTime.now(),
      evaluatorId: name,
    );
  }

  @override
  Future<FlagEvaluationResult<String>> getStringFlag(
    String flagKey,
    String defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    _checkState();
    final value = _flags[flagKey] ?? defaultValue;
    return FlagEvaluationResult(
      flagKey: flagKey,
      value: value is String ? value : defaultValue,
      evaluatedAt: DateTime.now(),
      evaluatorId: name,
    );
  }

  @override
  Future<FlagEvaluationResult<int>> getIntegerFlag(
    String flagKey,
    int defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    _checkState();
    final value = _flags[flagKey] ?? defaultValue;
    return FlagEvaluationResult(
      flagKey: flagKey,
      value: value is int ? value : defaultValue,
      evaluatedAt: DateTime.now(),
      evaluatorId: name,
    );
  }

  @override
  Future<FlagEvaluationResult<double>> getDoubleFlag(
    String flagKey,
    double defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    _checkState();
    final value = _flags[flagKey] ?? defaultValue;
    return FlagEvaluationResult(
      flagKey: flagKey,
      value: value is double ? value : defaultValue,
      evaluatedAt: DateTime.now(),
      evaluatorId: name,
    );
  }

  @override
  Future<FlagEvaluationResult<Map<String, dynamic>>> getObjectFlag(
    String flagKey,
    Map<String, dynamic> defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    _checkState();
    final value = _flags[flagKey] ?? defaultValue;
    return FlagEvaluationResult(
      flagKey: flagKey,
      value: value is Map<String, dynamic> ? value : defaultValue,
      evaluatedAt: DateTime.now(),
      evaluatorId: name,
    );
  }
}

/// Abstract base class for commercial provider integrations
abstract class CommercialProvider implements FeatureProvider {
  final String providerName;
  final Uri baseUrl;
  final Map<String, String> headers;
  final Duration timeout;
  ProviderState _state = ProviderState.NOT_READY;

  CommercialProvider({
    required this.providerName,
    required this.baseUrl,
    this.headers = const {},
    this.timeout = const Duration(seconds: 5),
  });

  @override
  String get name => providerName;

  @override
  ProviderState get state => _state;

  // HTTP request implementation template
  Future<dynamic> _makeRequest(String path,
      {Map<String, dynamic>? params}) async {
    throw UnimplementedError('_makeRequest must be implemented by child class');
  }
}
