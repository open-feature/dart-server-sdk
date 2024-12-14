import 'dart:async';
import 'package:logging/logging.dart';
import 'domain_manager.dart'; // Required for @visibleForTesting
import 'feature_provider.dart';
import 'package:meta/meta.dart';

// Define OpenFeatureEventType to represent different event types.
enum OpenFeatureEventType {
  providerChanged,
  flagEvaluated,
  contextUpdated,
  error,
}

// Define OpenFeatureEvent to represent events in the system.
class OpenFeatureEvent {
  final OpenFeatureEventType type;
  final String message;
  final dynamic data;

  OpenFeatureEvent(this.type, this.message, {this.data});
}




/// Abstract OpenFeatureProvider interface for extensibility
abstract class OpenFeatureProvider {
  static final Logger _logger = Logger('OpenFeatureProvider');

  String get name;

  // Generic method to get a feature flag's value
  Future<dynamic> getFlag(String flagKey, {Map<String, dynamic>? context});
}

// Default OpenFeatureNoOpProvider implementation as a safe fallback
class OpenFeatureNoOpProvider implements OpenFeatureProvider {
  @override
  String get name => "OpenFeatureNoOpProvider";

  @override
  Future<dynamic> getFlag(String flagKey,
      {Map<String, dynamic>? context}) async {

    return null; // Return null or default values for flags.


  }
}

/// Global evaluation context shared across feature evaluations
class OpenFeatureEvaluationContext {
  final Map<String, dynamic> attributes;

  OpenFeatureEvaluationContext(this.attributes);

  /// Merge this context with another context
  OpenFeatureEvaluationContext merge(OpenFeatureEvaluationContext other) {
    return OpenFeatureEvaluationContext({...attributes, ...other.attributes});
  }
}

/// Abstract OpenFeatureHook interface for pre/post evaluation logic
abstract class OpenFeatureHook {
  void beforeEvaluation(String flagKey, Map<String, dynamic>? context);
  void afterEvaluation(
      String flagKey, dynamic result, Map<String, dynamic>? context);
}

// Domain manager to bind clients with providers.
class DomainManager {
  final Map<String, String> _clientProviderBindings = {};

  void bindClientToProvider(String clientId, String providerName) {
    _clientProviderBindings[clientId] = providerName;
  }

  String? getProviderForClient(String clientId) {
    return _clientProviderBindings[clientId];
  }
}

// Singleton implementation of OpenFeatureAPI, managed through dependency injection.

/// Extension configuration for plugin management
class ExtensionConfig {
  final String id;
  final bool enabled;
  final Map<String, dynamic> settings;
  final List<String> dependencies;

  const ExtensionConfig({
    required this.id,
    this.enabled = true,
    this.settings = const {},
    this.dependencies = const [],
  });
}

/// Extension event for monitoring
class ExtensionEvent {
  final String extensionId;
  final String type;
  final String status;
  final DateTime timestamp;

  ExtensionEvent({
    required this.extensionId,
    required this.type,
    required this.status,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Singleton implementation of OpenFeatureAPI

class OpenFeatureAPI {
  static final Logger _logger = Logger('OpenFeatureAPI');
  static OpenFeatureAPI? _instance;

  // Default provider (OpenFeatureNoOpProvider initially)
  OpenFeatureProvider _provider = OpenFeatureNoOpProvider();

  // Domain manager to manage client-provider bindings
  final DomainManager _domainManager = DomainManager();


  // Extension management
  final Map<String, ExtensionConfig> _extensions = {};
  final Map<String, dynamic> _extensionInstances = {};

  // Global hooks and evaluation context
  final List<OpenFeatureHook> _hooks = [];
  OpenFeatureEvaluationContext? _globalContext;


  // Stream controllers
  final StreamController<OpenFeatureProvider> _providerStreamController;
  final StreamController<ExtensionEvent> _extensionEventController;
  final StreamController<OpenFeatureEvent> _eventStreamController =
      StreamController<OpenFeatureEvent>.broadcast();
  OpenFeatureAPI._internal()
      : _providerStreamController =
            StreamController<OpenFeatureProvider>.broadcast(),
        _extensionEventController =
            StreamController<ExtensionEvent>.broadcast() {
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

  void dispose() {
    _logger.info('Disposing OpenFeatureAPI resources.');
    _providerStreamController.close();
   _eventStreamController.close();

    _extensionEventController.close();

  }

  // Original API methods
  void setProvider(OpenFeatureProvider provider) {
    _logger.info('Provider is being set to: ${provider.name}');
    _provider = provider;


    // Emit provider update
    _providerStreamController.add(provider);

    // Emit providerChanged event
    _emitEvent(OpenFeatureEvent(
      OpenFeatureEventType.providerChanged,
      'Provider changed to ${provider.name}',
      data: provider,
    ));
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


  /// Emit an event to the event stream.
  void _emitEvent(OpenFeatureEvent event) {
    _logger.info('Emitting event: ${event.type} - ${event.message}');
    _eventStreamController.add(event);
  }

  /// Bind a client to a specific provider.
  void bindClientToProvider(String clientId, String providerName) {
    _domainManager.bindClientToProvider(clientId, providerName);

    // Emit contextUpdated event
    _emitEvent(OpenFeatureEvent(
      OpenFeatureEventType.contextUpdated,
      'Client $clientId bound to provider $providerName',
    ));
  }

  /// Evaluate a boolean flag with hooks and emit events.

  List<OpenFeatureHook> get hooks => List.unmodifiable(_hooks);

  Stream<OpenFeatureProvider> get providerUpdates =>
      _providerStreamController.stream;

  

  // New extension-related methods
  Future<void> registerExtension(

    
    
    String extensionId, ExtensionConfig config) async {
    _logger.info('Registering extension: $extensionId');

    // Validate dependencies
    for (final dependency in config.dependencies) {
      if (!_extensions.containsKey(dependency)) {
        throw Exception('Extension dependency not found: $dependency');
      }
    }

    _extensions[extensionId] = config;
    _extensionEventController.add(ExtensionEvent(
      extensionId: extensionId,
      type: 'REGISTRATION',
      status: 'REGISTERED',
    ));
  }

  Future<void> unregisterExtension(String extensionId) async {
    _logger.info('Unregistering extension: $extensionId');
    _extensions.remove(extensionId);
    _extensionInstances.remove(extensionId);

    _extensionEventController.add(ExtensionEvent(
      extensionId: extensionId,
      type: 'REGISTRATION',
      status: 'UNREGISTERED',
    ));
  }

  T? getExtension<T>(String extensionId) {
    return _extensionInstances[extensionId] as T?;
  }

  List<String> getRegisteredExtensions() {
    return List.unmodifiable(_extensions.keys);
  }

  Stream<ExtensionEvent> get extensionEvents =>
      _extensionEventController.stream;


  Future<bool> evaluateBooleanFlag(String flagKey, String clientId,
      {Map<String, dynamic>? context}) async {
    // Get provider for the client
    final providerName = _domainManager.getProviderForClient(clientId);
    if (providerName != null) {
      _logger.info('Using provider $providerName for client $clientId');
      _runBeforeEvaluationHooks(flagKey, context);


      try {
        final result = await _provider.getFlag(flagKey, context: context);

        _emitEvent(OpenFeatureEvent(
          OpenFeatureEventType.flagEvaluated,
          'Flag $flagKey evaluated for client $clientId',
          data: {'result': result, 'context': context},
        ));

        _runAfterEvaluationHooks(flagKey, result, context);
        return result ?? false;
      } catch (error) {
        _logger.warning('Error evaluating flag $flagKey: $error');
        _emitEvent(OpenFeatureEvent(
          OpenFeatureEventType.error,
          'Error evaluating flag $flagKey',
          data: error,
        ));
        return false;
      }

    } else {
      _logger.warning('No provider found for client $clientId');
      return false;
    }
  }

  void _runBeforeEvaluationHooks(
      String flagKey, Map<String, dynamic>? context) {
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

  /// Streams for listening to events and provider updates.
  Stream<OpenFeatureEvent> get events => _eventStreamController.stream;
 
}

// Dependency Injection for managing the singleton lifecycle
class OpenFeatureAPILocator {

  // This allows replacing the instance during tests

  static OpenFeatureAPI instance = OpenFeatureAPI();
}
