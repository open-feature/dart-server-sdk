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
  MAINTENANCE,
}

/// OpenFeature error codes
enum ErrorCode {
  FLAG_NOT_FOUND,
  TYPE_MISMATCH,
  GENERAL,
  PARSE_ERROR,
  TARGETING_KEY_MISSING,
  INVALID_CONTEXT,
  PROVIDER_NOT_READY,
}

/// Provider metadata
class ProviderMetadata {
  final String name;
  final String version;
  final Map<String, String> attributes;

  const ProviderMetadata({
    required this.name,
    this.version = '1.0.0',
    this.attributes = const {},
  });
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
  final String? variant;
  final ErrorCode? errorCode;
  final String? errorMessage;
  final Map<String, dynamic>? details;
  final DateTime evaluatedAt;
  final String evaluatorId;

  const FlagEvaluationResult({
    required this.flagKey,
    required this.value,
    this.reason = 'DEFAULT',
    this.variant,
    this.errorCode,
    this.errorMessage,
    this.details,
    required this.evaluatedAt,
    this.evaluatorId = '',
  });

  /// Create an error result
  static FlagEvaluationResult<T> error<T>(
    String flagKey,
    T defaultValue,
    ErrorCode errorCode,
    String message, {
    String evaluatorId = '',
  }) {
    return FlagEvaluationResult<T>(
      flagKey: flagKey,
      value: defaultValue,
      reason: 'ERROR',
      errorCode: errorCode,
      errorMessage: message,
      evaluatedAt: DateTime.now(),
      evaluatorId: evaluatorId,
    );
  }
}

/// Provider exception
class ProviderException implements Exception {
  final String message;
  final ErrorCode code;
  final Map<String, dynamic>? details;

  const ProviderException(
    this.message, {
    this.code = ErrorCode.GENERAL,
    this.details,
  });

  @override
  String toString() => 'ProviderException: $message (code: ${code.name})';
}

/// Feature provider interface
abstract class FeatureProvider {
  String get name;
  ProviderState get state;
  ProviderConfig get config;
  ProviderMetadata get metadata;

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
  final ProviderMetadata _metadata;

  InMemoryProvider(this._flags, [ProviderConfig? config])
    : _config = config ?? const ProviderConfig(),
      _metadata = const ProviderMetadata(name: 'InMemoryProvider');

  @override
  String get name => 'InMemoryProvider';

  @override
  ProviderState get state => _state;

  @override
  ProviderConfig get config => _config;

  @override
  ProviderMetadata get metadata => _metadata;

  @override
  Future<void> initialize([Map<String, dynamic>? config]) async {
    if (_state == ProviderState.SHUTDOWN) {
      throw ProviderException(
        'Cannot initialize a shutdown provider',
        code: ErrorCode.PROVIDER_NOT_READY,
      );
    }

    _state = ProviderState.CONNECTING;

    try {
      // Simulate initialization work
      await Future.delayed(Duration(milliseconds: 10));
      _state = ProviderState.READY;
    } catch (e) {
      _state = ProviderState.ERROR;
      rethrow;
    }
  }

  @override
  Future<void> connect() async {
    if (_state == ProviderState.SHUTDOWN) {
      throw ProviderException(
        'Cannot connect a shutdown provider',
        code: ErrorCode.PROVIDER_NOT_READY,
      );
    }

    _state = ProviderState.CONNECTING;

    try {
      await Future.delayed(Duration(milliseconds: 10));
      _state = ProviderState.READY;
    } catch (e) {
      _state = ProviderState.ERROR;
      rethrow;
    }
  }

  @override
  Future<void> shutdown() async {
    _state = ProviderState.SHUTDOWN;
  }

  void _checkState() {
    if (_state != ProviderState.READY) {
      throw ProviderException(
        'Provider not in READY state: ${_state.name}',
        code: ErrorCode.PROVIDER_NOT_READY,
        details: {'currentState': _state.name},
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

    if (!_flags.containsKey(flagKey)) {
      return FlagEvaluationResult.error(
        flagKey,
        defaultValue,
        ErrorCode.FLAG_NOT_FOUND,
        'Flag "$flagKey" not found',
        evaluatorId: name,
      );
    }

    final value = _flags[flagKey];
    if (value is! bool) {
      return FlagEvaluationResult.error(
        flagKey,
        defaultValue,
        ErrorCode.TYPE_MISMATCH,
        'Flag "$flagKey" is not a boolean, got ${value.runtimeType}',
        evaluatorId: name,
      );
    }

    return FlagEvaluationResult(
      flagKey: flagKey,
      value: value,
      reason: 'STATIC',
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

    if (!_flags.containsKey(flagKey)) {
      return FlagEvaluationResult.error(
        flagKey,
        defaultValue,
        ErrorCode.FLAG_NOT_FOUND,
        'Flag "$flagKey" not found',
        evaluatorId: name,
      );
    }

    final value = _flags[flagKey];
    if (value is! String) {
      return FlagEvaluationResult.error(
        flagKey,
        defaultValue,
        ErrorCode.TYPE_MISMATCH,
        'Flag "$flagKey" is not a string, got ${value.runtimeType}',
        evaluatorId: name,
      );
    }

    return FlagEvaluationResult(
      flagKey: flagKey,
      value: value,
      reason: 'STATIC',
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

    if (!_flags.containsKey(flagKey)) {
      return FlagEvaluationResult.error(
        flagKey,
        defaultValue,
        ErrorCode.FLAG_NOT_FOUND,
        'Flag "$flagKey" not found',
        evaluatorId: name,
      );
    }

    final value = _flags[flagKey];
    if (value is! int) {
      return FlagEvaluationResult.error(
        flagKey,
        defaultValue,
        ErrorCode.TYPE_MISMATCH,
        'Flag "$flagKey" is not an integer, got ${value.runtimeType}',
        evaluatorId: name,
      );
    }

    return FlagEvaluationResult(
      flagKey: flagKey,
      value: value,
      reason: 'STATIC',
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

    if (!_flags.containsKey(flagKey)) {
      return FlagEvaluationResult.error(
        flagKey,
        defaultValue,
        ErrorCode.FLAG_NOT_FOUND,
        'Flag "$flagKey" not found',
        evaluatorId: name,
      );
    }

    final value = _flags[flagKey];
    if (value is! double) {
      return FlagEvaluationResult.error(
        flagKey,
        defaultValue,
        ErrorCode.TYPE_MISMATCH,
        'Flag "$flagKey" is not a double, got ${value.runtimeType}',
        evaluatorId: name,
      );
    }

    return FlagEvaluationResult(
      flagKey: flagKey,
      value: value,
      reason: 'STATIC',
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

    if (!_flags.containsKey(flagKey)) {
      return FlagEvaluationResult.error(
        flagKey,
        defaultValue,
        ErrorCode.FLAG_NOT_FOUND,
        'Flag "$flagKey" not found',
        evaluatorId: name,
      );
    }

    final value = _flags[flagKey];
    if (value is! Map<String, dynamic>) {
      return FlagEvaluationResult.error(
        flagKey,
        defaultValue,
        ErrorCode.TYPE_MISMATCH,
        'Flag "$flagKey" is not an object, got ${value.runtimeType}',
        evaluatorId: name,
      );
    }

    return FlagEvaluationResult(
      flagKey: flagKey,
      value: value,
      reason: 'STATIC',
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
  final ProviderMetadata _metadata;

  CommercialProvider({
    required this.providerName,
    required this.baseUrl,
    this.headers = const {},
    this.timeout = const Duration(seconds: 5),
  }) : _metadata = ProviderMetadata(name: providerName);

  @override
  String get name => providerName;

  @override
  ProviderState get state => _state;

  @override
  ProviderMetadata get metadata => _metadata;

  // Subclasses must implement proper state transitions
  void setState(ProviderState newState) {
    _state = newState;
  }

  // HTTP request implementation template
}
