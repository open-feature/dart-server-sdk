import 'dart:async';
import 'package:logging/logging.dart';
import 'domain_manager.dart';
import 'feature_provider.dart';
import 'open_feature_event.dart';
import 'client.dart';
import 'hooks.dart';
import 'evaluation_context.dart';

class OpenFeatureEvaluationContext {
  final Map<String, dynamic> attributes;

  OpenFeatureEvaluationContext(this.attributes);

  OpenFeatureEvaluationContext merge(OpenFeatureEvaluationContext other) {
    return OpenFeatureEvaluationContext({...attributes, ...other.attributes});
  }
}

abstract class OpenFeatureHook {
  void beforeEvaluation(String flagKey, Map<String, dynamic>? context);
  void afterEvaluation(
    String flagKey,
    dynamic result,
    Map<String, dynamic>? context,
  );
}

/// Default provider that is immediately ready - completely independent
class _ImmediateReadyProvider implements FeatureProvider {
  @override
  String get name => 'InMemoryProvider';

  @override
  ProviderState get state => ProviderState.READY;

  @override
  ProviderConfig get config => const ProviderConfig();

  @override
  ProviderMetadata get metadata =>
      const ProviderMetadata(name: 'InMemoryProvider');

  @override
  Future<void> initialize([Map<String, dynamic>? config]) async {}

  @override
  Future<void> connect() async {}

  @override
  Future<void> shutdown() async {}

  @override
  Future<FlagEvaluationResult<bool>> getBooleanFlag(
    String flagKey,
    bool defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    return FlagEvaluationResult.error(
      flagKey,
      defaultValue,
      ErrorCode.FLAG_NOT_FOUND,
      'Flag not found',
      evaluatorId: name,
    );
  }

  @override
  Future<FlagEvaluationResult<String>> getStringFlag(
    String flagKey,
    String defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    return FlagEvaluationResult.error(
      flagKey,
      defaultValue,
      ErrorCode.FLAG_NOT_FOUND,
      'Flag not found',
      evaluatorId: name,
    );
  }

  @override
  Future<FlagEvaluationResult<int>> getIntegerFlag(
    String flagKey,
    int defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    return FlagEvaluationResult.error(
      flagKey,
      defaultValue,
      ErrorCode.FLAG_NOT_FOUND,
      'Flag not found',
      evaluatorId: name,
    );
  }

  @override
  Future<FlagEvaluationResult<double>> getDoubleFlag(
    String flagKey,
    double defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    return FlagEvaluationResult.error(
      flagKey,
      defaultValue,
      ErrorCode.FLAG_NOT_FOUND,
      'Flag not found',
      evaluatorId: name,
    );
  }

  @override
  Future<FlagEvaluationResult<Map<String, dynamic>>> getObjectFlag(
    String flagKey,
    Map<String, dynamic> defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    return FlagEvaluationResult.error(
      flagKey,
      defaultValue,
      ErrorCode.FLAG_NOT_FOUND,
      'Flag not found',
      evaluatorId: name,
    );
  }
}

class OpenFeatureAPI {
  static final Logger _logger = Logger('OpenFeatureAPI');
  static OpenFeatureAPI? _instance;
  static bool _testMode = false; // Add test mode flag

  late FeatureProvider _provider;
  final DomainManager _domainManager = DomainManager();
  final List<OpenFeatureHook> _hooks = [];
  OpenFeatureEvaluationContext? _globalContext;

  final StreamController<FeatureProvider> _providerStreamController;
  final StreamController<OpenFeatureEvent> _eventStreamController;
  final StreamController<Map<String, String>> _domainUpdatesController;

  OpenFeatureAPI._internal()
    : _providerStreamController = StreamController<FeatureProvider>.broadcast(),
      _eventStreamController = StreamController<OpenFeatureEvent>.broadcast(),
      _domainUpdatesController =
          StreamController<Map<String, String>>.broadcast() {
    _configureLogging();
    _initializeDefaultProvider();
  }

  factory OpenFeatureAPI() {
    // In test mode, always return new instance
    if (_testMode) {
      return OpenFeatureAPI._internal();
    }

    _instance ??= OpenFeatureAPI._internal();
    return _instance!;
  }

  // Enable test mode - disables singleton
  static void enableTestMode() {
    _testMode = true;
    _instance = null;
  }

  // Disable test mode - re-enables singleton
  static void disableTestMode() {
    _testMode = false;
    _instance = null;
  }

  // Public constructor for testing - bypasses singleton
  factory OpenFeatureAPI.forTesting() {
    return OpenFeatureAPI._internal();
  }

  static bool _loggingConfigured = false;

  void _configureLogging() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      print(
        '${record.time} [${record.level.name}] ${record.loggerName}: ${record.message}',
      );
    });
  }

  void _initializeDefaultProvider() {
    _provider = _ImmediateReadyProvider();
    _logger.info('Default provider initialized and ready');
    _emitEvent(OpenFeatureEventType.PROVIDER_READY, 'Default provider ready');
  }

  Future<void> setProvider(FeatureProvider provider) async {
    _logger.info('Setting provider: ${provider.name}');

    try {
      // Only initialize if provider is NOT_READY
      if (provider.state == ProviderState.NOT_READY) {
        await provider.initialize();
      }

      _provider = provider;
      _providerStreamController.add(provider);

      // Emit appropriate event based on state
      if (provider.state == ProviderState.READY) {
        _emitEvent(
          OpenFeatureEventType.PROVIDER_READY,
          'Provider ready: ${provider.name}',
        );
      } else {
        _emitEvent(
          OpenFeatureEventType.PROVIDER_ERROR,
          'Provider not ready: ${provider.name}',
          data: {'state': provider.state.name},
        );
      }
    } catch (error) {
      _logger.severe('Failed to initialize provider: $error');

      // Per OpenFeature spec: keep provider in ERROR state
      _provider = provider;
      _providerStreamController.add(provider);
      _emitEvent(
        OpenFeatureEventType.PROVIDER_ERROR,
        'Provider initialization failed: ${provider.name}',
        data: error,
      );
    }
  }

  /// Set provider and wait for it to be ready
  Future<void> setProviderAndWait(FeatureProvider provider) async {
    _logger.info('Setting provider and waiting: ${provider.name}');

    try {
      // Initialize if needed
      if (provider.state == ProviderState.NOT_READY) {
        await provider.initialize();
      }

      // Wait for READY state
      if (provider.state != ProviderState.READY) {
        throw ProviderException(
          'Provider failed to reach READY state: ${provider.state}',
          code: ErrorCode.PROVIDER_NOT_READY,
        );
      }

      _provider = provider;
      _providerStreamController.add(provider);
      _emitEvent(
        OpenFeatureEventType.PROVIDER_READY,
        'Provider ready: ${provider.name}',
      );
    } catch (error) {
      _logger.severe('Failed to initialize provider: $error');
      _provider = provider;
      _providerStreamController.add(provider);
      _emitEvent(
        OpenFeatureEventType.PROVIDER_ERROR,
        'Provider initialization failed: ${provider.name}',
        data: error,
      );
      rethrow;
    }
  }

  /// Get or create a client
  FeatureClient getClient(String name, {String? domain}) {
    // Build hook manager with global hooks
    final hookManager = HookManager();
    for (final hook in _hooks) {
      // Convert OpenFeatureHook to Hook if needed
      hookManager.addHook(_wrapHook(hook));
    }

    return FeatureClient(
      metadata: ClientMetadata(name: name),
      hookManager: hookManager,
      defaultContext: _globalContext != null
          ? EvaluationContext(attributes: _globalContext!.attributes)
          : EvaluationContext(attributes: {}),
      provider: _provider,
    );
  }

  /// Wrap OpenFeatureHook into Hook interface
  Hook _wrapHook(OpenFeatureHook openFeatureHook) {
    return _OpenFeatureHookAdapter(openFeatureHook);
  }

  FeatureProvider get provider => _provider;

  void setGlobalContext(OpenFeatureEvaluationContext context) {
    _logger.info('Setting global context');
    _globalContext = context;
    _emitEvent(
      OpenFeatureEventType.PROVIDER_CONTEXT_CHANGED,
      'Global context updated',
    );
  }

  OpenFeatureEvaluationContext? get globalContext => _globalContext;

  void addHooks(List<OpenFeatureHook> hooks) {
    _hooks.addAll(hooks);
  }

  List<OpenFeatureHook> get hooks => List.unmodifiable(_hooks);

  void bindClientToProvider(String clientId, String providerId) {
    _domainManager.bindClientToProvider(clientId, providerId);
    _emitEvent(
      OpenFeatureEventType.PROVIDER_CONFIGURATION_CHANGED,
      'Client $clientId bound to provider $providerId',
    );
  }

  /// @deprecated Use getClient().getBooleanValue() instead
  /// This method exists for backwards compatibility only
  @Deprecated('Use getClient().getBooleanValue() instead')
  Future<bool> evaluateBooleanFlag(
    String flagKey,
    String clientId, {
    Map<String, dynamic>? context,
  }) async {
    final client = getClient(clientId);
    return await client.getBooleanFlag(
      flagKey,
      defaultValue: false,
      context: context != null ? EvaluationContext(attributes: context) : null,
    );
  }

  void _emitEvent(OpenFeatureEventType type, String message, {dynamic data}) {
    final event = OpenFeatureEvent(type, message, data: data);
    _eventStreamController.add(event);
  }

  Future<void> dispose() async {
    await _providerStreamController.close();
    await _eventStreamController.close();
    await _domainUpdatesController.close();
  }

  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  Stream<FeatureProvider> get providerUpdates =>
      _providerStreamController.stream;
  Stream<OpenFeatureEvent> get events => _eventStreamController.stream;
  Stream<Map<String, String>> get domainUpdates =>
      _domainUpdatesController.stream;
}

class _OpenFeatureHookAdapter extends BaseHook {
  final OpenFeatureHook _hook;

  _OpenFeatureHookAdapter(this._hook)
    : super(metadata: HookMetadata(name: 'OpenFeatureHookAdapter'));

  @override
  Future<void> before(HookContext context) async {
    _hook.beforeEvaluation(context.flagKey, context.evaluationContext);
  }

  @override
  Future<void> after(HookContext context) async {
    _hook.afterEvaluation(
      context.flagKey,
      context.result,
      context.evaluationContext,
    );
  }
}
