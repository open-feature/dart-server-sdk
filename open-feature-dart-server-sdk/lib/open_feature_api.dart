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
  domainUpdated
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
      String flagKey, dynamic result, Map<String, dynamic>? context);
}

class OpenFeatureAPI {
  static final Logger _logger = Logger('OpenFeatureAPI');
  static OpenFeatureAPI? _instance;

  // Core components
  FeatureProvider _provider;
  final DomainManager _domainManager = DomainManager();
  final List<OpenFeatureHook> _hooks = [];
  OpenFeatureEvaluationContext? _globalContext;

  final StreamController<FeatureProvider> _providerStreamController;
  final StreamController<OpenFeatureEvent> _eventStreamController;
  final StreamController<Map<String, String>> _domainUpdatesController;

  OpenFeatureAPI._internal()
      : _provider = InMemoryProvider({}),
        _providerStreamController =
            StreamController<FeatureProvider>.broadcast(),
        _eventStreamController = StreamController<OpenFeatureEvent>.broadcast(),
        _domainUpdatesController =
            StreamController<Map<String, String>>.broadcast() {
    _configureLogging();
  }

  factory OpenFeatureAPI() {
    _instance ??= OpenFeatureAPI._internal();
    return _instance!;
  }

  void _configureLogging() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      print(
          '${record.time} [${record.level.name}] ${record.loggerName}: ${record.message}');
    });
  }

  void setProvider(FeatureProvider provider) {
    _logger.info('Setting provider: ${provider.name}');
    _provider = provider;
    _providerStreamController.add(provider);
    _emitEvent(OpenFeatureEventType.providerChanged,
        'Provider changed to ${provider.name}');
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

  void _emitEvent(OpenFeatureEventType type, String message, {dynamic data}) {
    final event = OpenFeatureEvent(type, message, data: data);
    _eventStreamController.add(event);
  }

  Future<void> dispose() async {
    await _providerStreamController.close();
    await _eventStreamController.close();
    await _domainUpdatesController.close();
  }

  void bindClientToProvider(String clientId, String providerId) {
    _domainManager.bindClientToProvider(clientId, providerId);
    _emitEvent(OpenFeatureEventType.domainUpdated,
        'Client $clientId bound to provider $providerId');
  }

  Future<bool> evaluateBooleanFlag(String flagKey, String clientId,
      {Map<String, dynamic>? context}) async {
    final providerId = _domainManager.getProviderForClient(clientId);
    if (providerId == null) {
      _logger.warning('No provider found for client $clientId');
      return false;
    }

    try {
      _runBeforeEvaluationHooks(flagKey, context);
      final result =
          await _provider.getBooleanFlag(flagKey, false, context: context);

      _emitEvent(OpenFeatureEventType.flagEvaluated,
          'Flag $flagKey evaluated for client $clientId',
          data: {'result': result.value, 'context': context});

      _runAfterEvaluationHooks(flagKey, result.value, context);
      return result.value;
    } catch (error) {
      _logger.warning('Error evaluating flag $flagKey: $error');
      _emitEvent(OpenFeatureEventType.error, 'Error evaluating flag $flagKey',
          data: error);
      return false;
    }
  }

  void _runBeforeEvaluationHooks(
      String flagKey, Map<String, dynamic>? context) {
    for (var hook in _hooks) {
      try {
        hook.beforeEvaluation(flagKey, context);
      } catch (e) {
        _logger.warning('Error in before-evaluation hook: $e');
      }
    }
  }

  void _runAfterEvaluationHooks(
      String flagKey, dynamic result, Map<String, dynamic>? context) {
    for (var hook in _hooks) {
      try {
        hook.afterEvaluation(flagKey, result, context);
      } catch (e) {
        _logger.warning('Error in after-evaluation hook: $e');
      }
    }
  }

  static void resetInstance() {
    _instance = null;
  }

  Stream<FeatureProvider> get providerUpdates =>
      _providerStreamController.stream;
  Stream<OpenFeatureEvent> get events => _eventStreamController.stream;
  Stream<Map<String, String>> get domainUpdates =>
      _domainUpdatesController.stream;
}
