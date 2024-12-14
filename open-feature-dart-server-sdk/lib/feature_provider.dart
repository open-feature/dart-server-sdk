// Feature provider core implementation and interfaces
// Defines the provider abstraction layer and base implementations
// Manages provider states, configurations, and interactions

/// Provider states for lifecycle management
enum ProviderState {
  READY, // Provider is initialized and ready
  ERROR, // Provider encountered an error
  NOT_READY, // Provider is not initialized
  SHUTDOWN, // Provider has been gracefully shutdown
  CONNECTING, // Provider is attempting to connect
  SYNCHRONIZING, // Provider is synchronizing flag data
  DEGRADED, // Provider is operating with reduced functionality
  RECONNECTING, // Provider is attempting to reconnect
  PLUGIN_ERROR, // New state for plugin-specific errors
  MAINTENANCE // Provider is under maintenance
}

/// Enhanced provider exception with detailed information
class ProviderException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? details;
  final Exception? cause;
  final StackTrace? stackTrace;

  const ProviderException(
    this.message, {
    this.code = 'PROVIDER_ERROR',
    this.details,
    this.cause,
    this.stackTrace,
  });

  @override
  String toString() => 'ProviderException: $message (code: $code)';
}

/// Plugin configuration for provider extensions
class PluginConfig {
  final String pluginId;
  final String version;
  final Map<String, dynamic> settings;
  final List<String> dependencies;
  final bool autoStart;
  final Duration? timeout;
  final int retryAttempts;
  final bool enableMetrics;

  const PluginConfig({
    required this.pluginId,
    required this.version,
    this.settings = const {},
    this.dependencies = const [],
    this.autoStart = true,
    this.timeout,
    this.retryAttempts = 3,
    this.enableMetrics = true,
  });
}

/// Authentication configuration for providers
class ProviderAuth {
  final String type;
  final Map<String, dynamic> credentials;
  final Map<String, String>? headers;
  final Duration? tokenExpiry;
  final Function? refreshCallback;
  final bool validateOnStartup;
  final bool cacheCredentials;

  const ProviderAuth({
    required this.type,
    required this.credentials,
    this.headers,
    this.tokenExpiry,
    this.refreshCallback,
    this.validateOnStartup = true,
    this.cacheCredentials = false,
  });
}

/// Configuration for provider behavior
class ProviderConfig {
  final Duration connectionTimeout;
  final Duration operationTimeout;
  final int maxRetries;
  final Duration retryDelay;
  final bool enableCache;
  final Duration cacheTTL;
  final int maxCacheSize;
  final Map<String, dynamic> customConfig;
  final bool enablePlugins;
  final List<String> allowedPlugins;
  final Map<String, PluginConfig> pluginConfigs;
  final bool enableMetrics;
  final Duration metricsInterval;
  final int maxConcurrentRequests;

  const ProviderConfig({
    this.connectionTimeout = const Duration(seconds: 30),
    this.operationTimeout = const Duration(seconds: 5),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.enableCache = true,
    this.cacheTTL = const Duration(minutes: 5),
    this.maxCacheSize = 1000,
    this.customConfig = const {},
    this.enablePlugins = true,
    this.allowedPlugins = const [],
    this.pluginConfigs = const {},
    this.enableMetrics = true,
    this.metricsInterval = const Duration(minutes: 1),
    this.maxConcurrentRequests = 100,
  });
}

/// Enhanced metadata for providers with additional capabilities
class ProviderMetadata {
  final String name;
  final String version;
  final Map<String, dynamic> capabilities;
  final List<String> supportedFeatures;
  final Map<String, String> providerInfo;

  const ProviderMetadata({
    required this.name,
    this.version = '1.0.0',
    this.capabilities = const {},
    this.supportedFeatures = const [],
    this.providerInfo = const {},
  });
}

/// Result of a feature flag evaluation with enhanced metadata
class FlagEvaluationResult<T> {
  final String flagKey;
  final T value;
  final String reason;
  final Map<String, dynamic>? details;
  final DateTime evaluatedAt;
  final String? version;
  final Map<String, dynamic>? metadata;
  final Duration? evaluationDuration;
  final String? evaluatorId;

  const FlagEvaluationResult({
    required this.flagKey,
    required this.value,
    this.reason = 'DEFAULT',
    this.details,
    required this.evaluatedAt,
    this.version,
    this.metadata,
    this.evaluationDuration,
    this.evaluatorId,
  });
}

/// Cache entry for flag values
class CacheEntry<T> {
  final T value;
  final DateTime expiration;
  final String version;
  final DateTime createdAt;
  final int accessCount;

  CacheEntry({
    required this.value,
    required this.expiration,
    required this.version,
    DateTime? createdAt,
    this.accessCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isExpired => DateTime.now().isAfter(expiration);

  CacheEntry<T> incrementAccess() {
    return CacheEntry<T>(
      value: value,
      expiration: expiration,
      version: version,
      createdAt: createdAt,
      accessCount: accessCount + 1,
    );
  }
}

/// Provider metrics for monitoring
class ProviderMetrics {
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final Duration averageResponseTime;
  final int cacheHits;
  final int cacheMisses;
  final Map<String, int> errorCounts;
  final DateTime lastUpdated;

  ProviderMetrics({
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.averageResponseTime,
    required this.cacheHits,
    required this.cacheMisses,
    required this.errorCounts,
    required this.lastUpdated,
  });
}

/// Enhanced provider interface
abstract class FeatureProvider {
  /// Provider metadata
  ProviderMetadata get metadata;

  /// Current provider state
  ProviderState get state;

  /// Provider configuration
  ProviderConfig get config;

  /// Initialize the provider
  Future<void> initialize([Map<String, dynamic>? config]);

  /// Authenticate with the provider
  Future<void> authenticate(ProviderAuth auth);

  /// Connect to the provider
  Future<void> connect();

  /// Shutdown the provider
  Future<void> shutdown();

  /// Get current metrics
  ProviderMetrics getMetrics();

  /// Clear provider cache
  Future<void> clearCache();

  /// Sync with remote provider
  Future<void> synchronize();

  /// Health check
  Future<bool> healthCheck();

  /// Get boolean flag value
  Future<FlagEvaluationResult<bool>> getBooleanFlag(
    String flagKey,
    bool defaultValue, {
    Map<String, dynamic>? context,
  });

  /// Get string flag value
  Future<FlagEvaluationResult<String>> getStringFlag(
    String flagKey,
    String defaultValue, {
    Map<String, dynamic>? context,
  });

  /// Get integer flag value
  Future<FlagEvaluationResult<int>> getIntegerFlag(
    String flagKey,
    int defaultValue, {
    Map<String, dynamic>? context,
  });

  /// Get double flag value
  Future<FlagEvaluationResult<double>> getDoubleFlag(
    String flagKey,
    double defaultValue, {
    Map<String, dynamic>? context,
  });

  /// Get object flag value
  Future<FlagEvaluationResult<Map<String, dynamic>>> getObjectFlag(
    String flagKey,
    Map<String, dynamic> defaultValue, {
    Map<String, dynamic>? context,
  });

  /// Plugin management
  Future<void> registerPlugin(String pluginId, PluginConfig config);
  Future<void> unregisterPlugin(String pluginId);
  Future<void> startPlugin(String pluginId);
  Future<void> stopPlugin(String pluginId);
  List<String> getRegisteredPlugins();
  PluginConfig? getPluginConfig(String pluginId);
}

/// Enhanced NoOp provider implementation
class NoOpProvider implements FeatureProvider {
  ProviderState _state = ProviderState.NOT_READY;
  final ProviderConfig _config;
  final Map<String, CacheEntry<dynamic>> _cache = {};
  final Map<String, PluginConfig> _plugins = {};
  int _totalRequests = 0;
  int _successfulRequests = 0;
  int _failedRequests = 0;
  int _cacheHits = 0;
  int _cacheMisses = 0;
  final Map<String, int> _errorCounts = {};

  NoOpProvider([ProviderConfig? config])
      : _config = config ?? const ProviderConfig();

  @override
  ProviderMetadata get metadata => const ProviderMetadata(
        name: 'NoOpProvider',
        version: '1.0.0',
        capabilities: {'supportsTargeting': false},
      );

  @override
  ProviderState get state => _state;

  @override
  ProviderConfig get config => _config;

  @override
  Future<void> initialize([Map<String, dynamic>? config]) async {
    _state = ProviderState.READY;
  }

  @override
  Future<void> authenticate(ProviderAuth auth) async {
    // NoOp provider doesn't require authentication
  }

  @override
  Future<void> connect() async {
    _state = ProviderState.READY;
  }

  @override
  Future<void> shutdown() async {
    _state = ProviderState.SHUTDOWN;
    _cache.clear();
  }

  @override
  ProviderMetrics getMetrics() {
    final now = DateTime.now();
    return ProviderMetrics(
      totalRequests: _totalRequests,
      successfulRequests: _successfulRequests,
      failedRequests: _failedRequests,
      averageResponseTime: Duration(milliseconds: 0),
      cacheHits: _cacheHits,
      cacheMisses: _cacheMisses,
      errorCounts: Map.from(_errorCounts),
      lastUpdated: now,
    );
  }

  @override
  Future<void> clearCache() async {
    _cache.clear();
  }

  @override
  Future<void> synchronize() async {
    // NoOp provider doesn't need synchronization
  }

  @override
  Future<bool> healthCheck() async {
    return _state == ProviderState.READY;
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
    _totalRequests++;
    _successfulRequests++;

    return FlagEvaluationResult(
      flagKey: flagKey,
      value: defaultValue,
      evaluatedAt: DateTime.now(),
      evaluatorId: 'NoOpProvider',
    );
  }

  @override
  Future<FlagEvaluationResult<String>> getStringFlag(
    String flagKey,
    String defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    _checkState();
    _totalRequests++;
    _successfulRequests++;

    return FlagEvaluationResult(
      flagKey: flagKey,
      value: defaultValue,
      evaluatedAt: DateTime.now(),
      evaluatorId: 'NoOpProvider',
    );
  }

  @override
  Future<FlagEvaluationResult<int>> getIntegerFlag(
    String flagKey,
    int defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    _checkState();
    _totalRequests++;
    _successfulRequests++;

    return FlagEvaluationResult(
      flagKey: flagKey,
      value: defaultValue,
      evaluatedAt: DateTime.now(),
      evaluatorId: 'NoOpProvider',
    );
  }

  @override
  Future<FlagEvaluationResult<double>> getDoubleFlag(
    String flagKey,
    double defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    _checkState();
    _totalRequests++;
    _successfulRequests++;

    return FlagEvaluationResult(
      flagKey: flagKey,
      value: defaultValue,
      evaluatedAt: DateTime.now(),
      evaluatorId: 'NoOpProvider',
    );
  }

  @override
  Future<FlagEvaluationResult<Map<String, dynamic>>> getObjectFlag(
    String flagKey,
    Map<String, dynamic> defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    _checkState();
    _totalRequests++;
    _successfulRequests++;

    return FlagEvaluationResult(
      flagKey: flagKey,
      value: defaultValue,
      evaluatedAt: DateTime.now(),
      evaluatorId: 'NoOpProvider',
    );
  }

  @override
  Future<void> registerPlugin(String pluginId, PluginConfig config) async {
    if (!_config.enablePlugins) {
      throw ProviderException('Plugins are not enabled for this provider');
    }
    _plugins[pluginId] = config;
  }

  @override
  Future<void> unregisterPlugin(String pluginId) async {
    _plugins.remove(pluginId);
  }

  @override
  Future<void> startPlugin(String pluginId) async {
    final config = _plugins[pluginId];
    if (config == null) {
      throw ProviderException('Plugin $pluginId not found');
    }
    // Plugin start logic would go here
  }

  @override
  Future<void> stopPlugin(String pluginId) async {
    final config = _plugins[pluginId];
    if (config == null) {
      throw ProviderException('Plugin $pluginId not found');
    }
    // Plugin stop logic would go here
  }

  @override
  List<String> getRegisteredPlugins() {
    return _plugins.keys.toList();
  }

  @override
  PluginConfig? getPluginConfig(String pluginId) {
    return _plugins[pluginId];
  }
}
