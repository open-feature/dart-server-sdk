import 'dart:async';
import 'package:logging/logging.dart';
import 'client.dart';
import 'domain.dart';
import 'domain_manager.dart';
import 'evaluation_context.dart';
import 'feature_provider.dart';
import 'hooks.dart';
import 'open_feature_event.dart';

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

/// Default provider that's immediately ready - completely independent
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
  Future<void> track(
    String trackingEventName, {
    Map<String, dynamic>? evaluationContext,
    TrackingEventDetails? trackingDetails,
  }) async {}

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

  late FeatureProvider _provider;
  final Map<String, FeatureProvider> _providerRegistry = {};
  final DomainManager _domainManager = DomainManager();
  final List<OpenFeatureHook> _hooks = [];
  OpenFeatureEvaluationContext? _globalContext;
  StreamSubscription<Domain>? _domainSubscription;

  final StreamController<FeatureProvider> _providerStreamController;
  final StreamController<OpenFeatureEvent> _eventStreamController;
  final StreamController<Map<String, String>> _domainUpdatesController;

  OpenFeatureAPI._internal()
    : _providerStreamController = StreamController<FeatureProvider>.broadcast(),
      _eventStreamController = StreamController<OpenFeatureEvent>.broadcast(),
      _domainUpdatesController =
          StreamController<Map<String, String>>.broadcast() {
    _configureLogging();
    _domainSubscription = _domainManager.domainUpdates.listen((domain) {
      _domainUpdatesController.add({
        'clientId': domain.clientId,
        'providerName': domain.providerName,
      });
    });
    _initializeDefaultProvider();
  }

  factory OpenFeatureAPI() {
    _instance ??= OpenFeatureAPI._internal();
    return _instance!;
  }

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
    _providerRegistry[_provider.metadata.name] = _provider;
    _logger.info('Default provider initialized and ready');
    _emitEvent(
      OpenFeatureEventType.PROVIDER_READY,
      'Default provider ready',
      providerMetadata: _provider.metadata,
    );
  }

  Future<void> setProvider(FeatureProvider provider) async {
    _logger.info('Setting provider: ${provider.name}');

    try {
      if (provider.state == ProviderState.NOT_READY) {
        await provider.initialize();
      }

      _provider = provider;
      _providerRegistry[provider.metadata.name] = provider;
      _providerStreamController.add(provider);

      if (provider.state == ProviderState.READY) {
        _emitEvent(
          OpenFeatureEventType.PROVIDER_READY,
          'Provider ready: ${provider.name}',
          providerMetadata: provider.metadata,
        );
      } else {
        _emitEvent(
          OpenFeatureEventType.PROVIDER_ERROR,
          'Provider not ready: ${provider.name}',
          data: {'state': provider.state.name},
          providerMetadata: provider.metadata,
        );
      }
    } catch (error) {
      _logger.severe('Failed to initialize provider: $error');
      _provider = provider;
      _providerRegistry[provider.metadata.name] = provider;
      _providerStreamController.add(provider);
      _emitEvent(
        OpenFeatureEventType.PROVIDER_ERROR,
        'Provider initialization failed: ${provider.name}',
        data: error,
        providerMetadata: provider.metadata,
      );
    }
  }

  /// Set provider and wait for it to be ready
  Future<void> setProviderAndWait(FeatureProvider provider) async {
    _logger.info('Setting provider and waiting: ${provider.name}');

    try {
      if (provider.state == ProviderState.NOT_READY) {
        await provider.initialize();
      }

      if (provider.state != ProviderState.READY) {
        throw ProviderException(
          'Provider failed to reach READY state: ${provider.state}',
          code: ErrorCode.PROVIDER_NOT_READY,
        );
      }

      _provider = provider;
      _providerRegistry[provider.metadata.name] = provider;
      _providerStreamController.add(provider);
      _emitEvent(
        OpenFeatureEventType.PROVIDER_READY,
        'Provider ready: ${provider.name}',
        providerMetadata: provider.metadata,
      );
    } catch (error) {
      _logger.severe('Failed to initialize provider: $error');
      _provider = provider;
      _providerRegistry[provider.metadata.name] = provider;
      _providerStreamController.add(provider);
      _emitEvent(
        OpenFeatureEventType.PROVIDER_ERROR,
        'Provider initialization failed: ${provider.name}',
        data: error,
        providerMetadata: provider.metadata,
      );
      rethrow;
    }
  }

  void registerProvider(FeatureProvider provider) {
    _providerRegistry[provider.metadata.name] = provider;
  }

  /// Shutdown the current provider (spec v0.8.0: status MUST indicate NOT_READY after shutdown)
  Future<void> shutdownProvider() async {
    _logger.info('Shutting down provider: ${_provider.name}');

    try {
      await _provider.shutdown();
      _emitEvent(
        OpenFeatureEventType.PROVIDER_STALE,
        'Provider shutdown: ${_provider.name}',
        providerMetadata: _provider.metadata,
      );
    } catch (e) {
      _logger.severe('Error during provider shutdown: $e');
      _emitEvent(
        OpenFeatureEventType.PROVIDER_ERROR,
        'Provider shutdown failed: ${_provider.name}',
        data: e,
        providerMetadata: _provider.metadata,
      );
    }

    _initializeDefaultProvider();
  }

  FeatureProvider _resolveProviderForClient(String clientId, String? domain) {
    final bindingKey = domain ?? clientId;
    final boundProviderName = _domainManager.getProviderForClient(bindingKey);
    if (boundProviderName == null) {
      return _provider;
    }

    return _providerRegistry[boundProviderName] ?? _provider;
  }

  /// Get or create a client
  FeatureClient getClient(String name, {String? domain}) {
    final selectedProvider = _resolveProviderForClient(name, domain);

    final hookManager = HookManager();
    for (final hook in _hooks) {
      hookManager.addHook(_wrapHook(hook));
    }

    return FeatureClient(
      metadata: ClientMetadata(name: name),
      hookManager: hookManager,
      apiContext: _globalContext != null
          ? EvaluationContext(attributes: _globalContext!.attributes)
          : const EvaluationContext(attributes: {}),
      defaultContext: const EvaluationContext(attributes: {}),
      provider: selectedProvider,
      eventStream: events,
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
      providerMetadata: _provider.metadata,
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
      providerMetadata: _providerRegistry[providerId]?.metadata,
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

  void _emitEvent(
    OpenFeatureEventType type,
    String message, {
    dynamic data,
    ProviderMetadata? providerMetadata,
    ErrorCode? errorCode,
  }) {
    final event = OpenFeatureEvent(
      type,
      message,
      data: data,
      providerMetadata: providerMetadata,
      errorCode: errorCode,
    );
    _eventStreamController.add(event);
  }

  Future<void> dispose() async {
    await _domainSubscription?.cancel();
    _domainManager.dispose();
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
    dynamic resultValue = context.result;
    if (resultValue is FlagEvaluationResult) {
      resultValue = resultValue.value;
    }
    _hook.afterEvaluation(
      context.flagKey,
      resultValue,
      context.evaluationContext,
    );
  }
}
