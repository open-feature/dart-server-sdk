import 'dart:async';
import 'package:logging/logging.dart';
import 'domain_manager.dart';
import 'feature_provider.dart';

enum OpenFeatureEventType {
  providerChanged,
  flagEvaluated,
  contextUpdated,
  error,
  shutdown,
  domainUpdated,
}

class OpenFeatureEvent {
  final OpenFeatureEventType type;
  final String message;
  final dynamic data;

  OpenFeatureEvent(this.type, this.message, {this.data});
}

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
    // Only configure logging once globally to prevent multiple listeners
    if (!_loggingConfigured) {
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((record) {
        print(
          '${record.time} [${record.level.name}] ${record.loggerName}: ${record.message}',
        );
      });
      _loggingConfigured = true;
    }
  }

  void _initializeDefaultProvider() {
    _provider = _ImmediateReadyProvider();
    _logger.info('Default provider initialized and ready');

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
      _emitEvent(
        OpenFeatureEventType.providerChanged,
        'Provider changed to ${provider.name}',
      );
    } catch (error) {
      _logger.severe('Failed to initialize provider: $error');

      // Per OpenFeature spec: keep provider in ERROR state
      _provider = provider;
      _providerStreamController.add(provider);
      _emitEvent(
        OpenFeatureEventType.error,
        'Provider initialization failed: ${provider.name}',
        data: error,
      );
    }

  }

  FeatureProvider get provider => _provider;

  void setGlobalContext(OpenFeatureEvaluationContext context) {
    _logger.info('Setting global context');
    _globalContext = context;
    _emitEvent(OpenFeatureEventType.contextUpdated, 'Global context updated');
  }

  OpenFeatureEvaluationContext? get globalContext => _globalContext;

  void addHooks(List<OpenFeatureHook> hooks) {
    _hooks.addAll(hooks);
  }

  List<OpenFeatureHook> get hooks => List.unmodifiable(_hooks);

  void bindClientToProvider(String clientId, String providerId) {
    _domainManager.bindClientToProvider(clientId, providerId);
    _emitEvent(
      OpenFeatureEventType.domainUpdated,
      'Client $clientId bound to provider $providerId',
    );
  }

  Future<bool> evaluateBooleanFlag(
    String flagKey,
    String clientId, {
    Map<String, dynamic>? context,
  }) async {
    final providerId = _domainManager.getProviderForClient(clientId);
    if (providerId == null) {
      _logger.warning('No provider found for client $clientId');
      return false;
    }

    // Per OpenFeature spec: short-circuit if provider not READY
    if (_provider.state != ProviderState.READY) {
      _logger.warning(
        'Provider not ready for evaluation (state: ${_provider.state})',
      );
      _emitEvent(
        OpenFeatureEventType.error,
        'Flag evaluation attempted on non-ready provider',
        data: {'flagKey': flagKey, 'providerState': _provider.state.name},
      );
      return false;
    }

    try {
      _runBeforeEvaluationHooks(flagKey, context);



      final result = await _provider.getBooleanFlag(
        flagKey,
        false,
        context: context,
      );

      _emitEvent(
        OpenFeatureEventType.flagEvaluated,
        'Flag $flagKey evaluated for client $clientId',
        data: {
          'result': result.value,
          'context': context,
          'errorCode': result.errorCode?.name,
        },
      );

      _runAfterEvaluationHooks(flagKey, result.value, context);

      if (result.errorCode != null) {
        _logger.warning('Flag evaluation error: ${result.errorMessage}');
        _emitEvent(
          OpenFeatureEventType.error,
          'Error evaluating flag $flagKey',
          data: {
            'errorCode': result.errorCode?.name,
            'errorMessage': result.errorMessage,
          },
        );
      }

      return result.value;
    } catch (error) {
      _logger.warning('Error evaluating flag $flagKey: $error');
      _emitEvent(
        OpenFeatureEventType.error,
        'Error evaluating flag $flagKey',
        data: error,
      );
      return false;
    }
  }

  void _runBeforeEvaluationHooks(
    String flagKey,
    Map<String, dynamic>? context,
  ) {
    for (var hook in _hooks) {
      try {
        hook.beforeEvaluation(flagKey, context);
      } catch (e) {
        _logger.warning('Error in before-evaluation hook: $e');
      }
    }
  }

  void _runAfterEvaluationHooks(
    String flagKey,
    dynamic result,
    Map<String, dynamic>? context,
  ) {
    for (var hook in _hooks) {
      try {
        hook.afterEvaluation(flagKey, result, context);
      } catch (e) {
        _logger.warning('Error in after-evaluation hook: $e');
      }
    }
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

  // FIXED: Proper singleton reset with complete cleanup
  static void resetInstance() {
    if (_instance != null) {
      try {
        _instance!._providerStreamController.close();
        _instance!._eventStreamController.close();
        _instance!._domainUpdatesController.close();
        _instance!._domainManager.dispose();
      } catch (e) {
        // Ignore disposal errors during reset
      }
    }
    _instance = null;
  }

  Stream<FeatureProvider> get providerUpdates =>
      _providerStreamController.stream;
  Stream<OpenFeatureEvent> get events => _eventStreamController.stream;
  Stream<Map<String, String>> get domainUpdates =>
      _domainUpdatesController.stream;
}
