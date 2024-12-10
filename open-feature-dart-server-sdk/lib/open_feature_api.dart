import 'dart:async';
import 'package:logging/logging.dart';

  
import 'domain_manager.dart'; // Required for @visibleForTesting

// Abstract OpenFeatureProvider interface for extensibility.
abstract class OpenFeatureProvider {
  

    static final Logger _logger = Logger('OpenFeatureProvider');

  String get name;

  // Generic method to get a feature flag's value.
  Future<dynamic> getFlag(String flagKey, {Map<String, dynamic>? context});
}

// Default OpenFeatureNoOpProvider implementation as a safe fallback.
class OpenFeatureNoOpProvider implements OpenFeatureProvider {
  @override
  String get name => "OpenFeatureNoOpProvider";

  @override
  Future<dynamic> getFlag(String flagKey,
      {Map<String, dynamic>? context}) async {
    // Return null or default values for flags.
    return null;
  }
}

// Global evaluation context shared across feature evaluations.
class OpenFeatureEvaluationContext {
  final Map<String, dynamic> attributes;

  OpenFeatureEvaluationContext(this.attributes);

  /// Merge this context with another context.
  OpenFeatureEvaluationContext merge(OpenFeatureEvaluationContext other) {
    return OpenFeatureEvaluationContext({...attributes, ...other.attributes});
  }
}

// Abstract OpenFeatureHook interface for pre/post evaluation logic.
abstract class OpenFeatureHook {
  void beforeEvaluation(String flagKey, Map<String, dynamic>? context);
  void afterEvaluation(
      String flagKey, dynamic result, Map<String, dynamic>? context);
}

// Singleton implementation of OpenFeatureAPI, managed through dependency injection.
class OpenFeatureAPI {
  static final Logger _logger = Logger('OpenFeatureAPI');
  static OpenFeatureAPI? _instance;

  // Default provider (OpenFeatureNoOpProvider initially)
  OpenFeatureProvider _provider = OpenFeatureNoOpProvider();

  // Domain manager to manage client-provider bindings
  final DomainManager _domainManager = DomainManager();

  // Global hooks and evaluation context
  final List<OpenFeatureHook> _hooks = [];
  OpenFeatureEvaluationContext? _globalContext;

  // StreamController for provider updates
  late final StreamController<OpenFeatureProvider> _providerStreamController;

  OpenFeatureAPI._internal() {
    _configureLogging();
    _providerStreamController =
        StreamController<OpenFeatureProvider>.broadcast();
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

  void dispose() {
    _logger.info('Disposing OpenFeatureAPI resources.');
    _providerStreamController.close();
  }

  void setProvider(OpenFeatureProvider provider) {
    _logger.info('Provider is being set to: ${provider.name}');
    _provider = provider;
    _providerStreamController.add(provider);
  }

  OpenFeatureProvider get provider => _provider;

  void setGlobalContext(OpenFeatureEvaluationContext context) {
    _logger.info('Setting global evaluation context: ${context.attributes}');
    _globalContext = context;
  }

  OpenFeatureEvaluationContext? get globalContext => _globalContext;

  void addHooks(List<OpenFeatureHook> hooks) {
    _logger.info('Adding hooks: ${hooks.length} hook(s) added.');
    _hooks.addAll(hooks);
  }

  List<OpenFeatureHook> get hooks => List.unmodifiable(_hooks);

  Stream<OpenFeatureProvider> get providerUpdates =>
      _providerStreamController.stream;

  void bindClientToProvider(String clientId, String providerName) {
    _domainManager.bindClientToProvider(clientId, providerName);
  }

  Future<bool> evaluateBooleanFlag(String flagKey, String clientId,
      {Map<String, dynamic>? context}) async {
    // Get provider for the client
    final providerName = _domainManager.getProviderForClient(clientId);
    if (providerName != null) {
      _logger.info('Using provider $providerName for client $clientId');
      // Set the active provider before evaluation
      _provider = OpenFeatureNoOpProvider(); // Placeholder for real provider lookup
      _runBeforeEvaluationHooks(flagKey, context);

      final result = await _provider.getFlag(flagKey, context: context);
      _runAfterEvaluationHooks(flagKey, result, context);
      return result ?? false;
    } else {
      _logger.warning('No provider found for client $clientId');
      return false;
    }
  }

  void _runBeforeEvaluationHooks(String flagKey, Map<String, dynamic>? context) {
    _logger.info('Running before-evaluation hooks for flag: $flagKey');
    for (var hook in _hooks) {
      try {
        hook.beforeEvaluation(flagKey, context);
      } catch (e, stack) {
        _logger.warning(
            'Error in before-evaluation hook for flag: $flagKey', e, stack);
      }
    }
  }

  void _runAfterEvaluationHooks(
      String flagKey, dynamic result, Map<String, dynamic>? context) {
    _logger.info('Running after-evaluation hooks for flag: $flagKey');
    for (var hook in _hooks) {
      try {
        hook.afterEvaluation(flagKey, result, context);
      } catch (e, stack) {
        _logger.warning(
            'Error in after-evaluation hook for flag: $flagKey', e, stack);
      }
    }
  }
}

// Dependency Injection for managing the singleton lifecycle
class OpenFeatureAPILocator {
  // This allows replacing the instance during tests.
  static OpenFeatureAPI instance = OpenFeatureAPI();
}
