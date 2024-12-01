import 'dart:async';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import 'domain_manager.dart';
import 'open_feature_event.dart';
import 'transaction_context.dart'; // Required for @visibleForTesting

// Abstract OpenFeatureProvider interface for extensibility.
abstract class OpenFeatureProvider {
  static final Logger _logger = Logger('OpenFeatureProvider');

// Abstract OpenFeatureProvider interface for extensibility.

  String get name;

  // Shutdown method for cleaning u p resources.

  // Shutdown method for cleaning up resources.
  Future<void> shutdown() async {
    _logger.info('Shutting down provider: $name');
    // Default implementation does nothing.
  }

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
    OpenFeatureProvider._logger
        .info('Returning default value for flag: $flagKey');
    return null;
  }

  // Implement the shutdown method (even if it does nothing).
  @override
  Future<void> shutdown() async {
    // No-op shutdown implementation (does nothing).
    OpenFeatureProvider._logger.info('Shutting down provider: $name');
  }
}

// Global evaluation context shared across feature evaluations.
class OpenFeatureEvaluationContext {
  final Map<String, dynamic> attributes;
  TransactionContext?
      transactionContext; // Optional, for transaction-specific data

  OpenFeatureEvaluationContext(this.attributes, {this.transactionContext});

  /// Merge this context with another context
  OpenFeatureEvaluationContext merge(OpenFeatureEvaluationContext other) {
    return OpenFeatureEvaluationContext(
      {...attributes, ...other.attributes},
      transactionContext: other.transactionContext ?? this.transactionContext,
    );
  }
}

// Abstract OpenFeatureHook interface for pre/post evaluation logic.
abstract class OpenFeatureHook {
  void beforeEvaluation(String flagKey, Map<String, dynamic>? context);
  void afterEvaluation(
      String flagKey, dynamic result, Map<String, dynamic>? context);
}

// Singleton implementation of OpenFeatureAPI.
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
  // Stack to manage transaction contexts
  final List<TransactionContext> _transactionContextStack = [];

  // StreamController for provider updates
  late final StreamController<OpenFeatureProvider> _providerStreamController;
  // StreamController for eventing
  final StreamController<OpenFeatureEvent> _eventStreamController =
      StreamController<OpenFeatureEvent>.broadcast();
  // Private constructor
  OpenFeatureAPI._internal() {
    _configureLogging();
    _providerStreamController =
        StreamController<OpenFeatureProvider>.broadcast();
  }

  // Factory constructor for singleton instance
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
    // Perform any other cleanup tasks if necessary.
    _provider.shutdown();
  }

  /// Set the active feature provider and notify listeners.
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

  /// Get the active feature provider.
  OpenFeatureProvider get provider => _provider;

  /// Set the global evaluation context for the API.
  void setGlobalContext(OpenFeatureEvaluationContext context) {
    _logger.info('Setting global evaluation context: ${context.attributes}');
    _globalContext = context;
  }

  /// Get the current global evaluation context.
  OpenFeatureEvaluationContext? get globalContext => _globalContext;

  /// Add global hooks to the API.
  void addHooks(List<OpenFeatureHook> hooks) {
    _logger.info('Adding hooks: ${hooks.length} hook(s) added.');
    _hooks.addAll(hooks);
  }

  /// Retrieve the global hooks.
  List<OpenFeatureHook> get hooks => List.unmodifiable(_hooks);

  /// Reset the singleton instance for testing purposes.
  ///
  /// This ensures a clean state for each test case.
  @visibleForTesting
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  /// Emit an event to the event stream.
  void _emitEvent(OpenFeatureEvent event) {
    _logger.info('Emitting event: ${event.type} - ${event.message}');
    _eventStreamController.add(event);
  }

  /// Listen for all events in the system.
  Stream<OpenFeatureEvent> get events => _eventStreamController.stream;

  /// Stream to listen for provider updates.
  Stream<OpenFeatureProvider> get providerUpdates =>
      _providerStreamController.stream;

  /// Bind a client to a specific provider.
  void bindClientToProvider(String clientId, String providerName) {
    _domainManager.bindClientToProvider(clientId, providerName);

    // Emit contextUpdated event
    _emitEvent(OpenFeatureEvent(
      OpenFeatureEventType.contextUpdated,
      'Client $clientId bound to provider $providerName',
    ));
  }

  /// Evaluate a boolean flag with the hook lifecycle and emit events.
  Future<bool> evaluateBooleanFlag(String flagKey, String clientId,
      {Map<String, dynamic>? context}) async {
    // Get provider for the client
    final providerName = _domainManager.getProviderForClient(clientId);
    if (providerName != null) {
      _logger.info('Using provider $providerName for client $clientId');
      // Set the active provider before evaluation
      _provider =
          OpenFeatureNoOpProvider(); // Placeholder for real provider lookup
      _runBeforeEvaluationHooks(flagKey, context);

      try {
        final result = await _provider.getFlag(flagKey, context: context);

        // Emit flagEvaluated event
        _emitEvent(OpenFeatureEvent(
          OpenFeatureEventType.flagEvaluated,
          'Flag $flagKey evaluated for client $clientId',
          data: {'result': result, 'context': context},
        ));

        _runAfterEvaluationHooks(flagKey, result, context);
        return result ?? false;
      } catch (error) {
        _logger.warning(
            'Error evaluating flag $flagKey for client $clientId: $error');

        // Emit error event
        _emitEvent(OpenFeatureEvent(
          OpenFeatureEventType.error,
          'Error evaluating flag $flagKey for client $clientId',
          data: error,
        ));

        return false;
      }
    } else {
      _logger.warning('No provider found for client $clientId');
      return false;
    }
  }

  /// Run hooks before evaluation.
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

  /// Run hooks after evaluation.
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

  // **Shutdown**: Gracefully clean up the provider during shutdown
  Future<void> shutdown() async {
    _logger.info('Shutting down OpenFeatureAPI...');
    await _provider.shutdown(); // Shutdown the provider
    // Optionally, cleanup transaction contexts

    _transactionContextStack.clear();
    dispose();
  }

  // **Transaction Context Propagation**: Set a specific evaluation context for a transaction
  void pushTransactionContext(TransactionContext context) {
    _transactionContextStack.add(context);
    _logger.info('Pushed new transaction context: ${context.id}');
  }

  TransactionContext? popTransactionContext() {
    if (_transactionContextStack.isNotEmpty) {
      final context = _transactionContextStack.removeLast();
      _logger.info('Popped transaction context: ${context.id}');
      return context;
    } else {
      _logger.warning('No transaction context to pop');
      return null;
    }
  }

  TransactionContext? get currentTransactionContext {
    return _transactionContextStack.isNotEmpty
        ? _transactionContextStack.last
        : null;
  }
}
