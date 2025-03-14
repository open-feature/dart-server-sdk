// Hook interface and default hooks.
import 'dart:async';

/// Defines the stages in the hook lifecycle
/// Used internally by the hook manager for execution ordering
enum HookStage {
  BEFORE, // Before flag evaluation
  AFTER, // After successful evaluation
  ERROR, // When an error occurs
  FINALLY // Always executed last
}

/// Hook priority levels
enum HookPriority {
  CRITICAL, // Highest priority, executes first
  HIGH, // High priority
  NORMAL, // Default priority
  LOW // Lowest priority
}

/// Configuration for hook behavior
class HookConfig {
  final bool continueOnError;
  final Duration timeout;
  final Map<String, dynamic> customConfig;

  const HookConfig({
    this.continueOnError = true,
    this.timeout = const Duration(seconds: 5),
    this.customConfig = const {},
  });
}

/// Metadata for hook identification and configuration
class HookMetadata {
  final String name;
  final String version;
  final HookPriority priority;
  final HookConfig config;

  const HookMetadata({
    required this.name,
    this.version = '1.0.0',
    this.priority = HookPriority.NORMAL,
    this.config = const HookConfig(),
  });
}

/// Context passed to hooks during execution
class HookContext {
  final String flagKey;
  final Map<String, dynamic>? evaluationContext;
  final dynamic result;
  final Exception? error;
  final Map<String, dynamic> metadata;

  HookContext({
    required this.flagKey,
    this.evaluationContext,
    this.result,
    this.error,
    this.metadata = const {},
  });
}

/// Interface for implementing hooks
abstract class Hook {
  /// Hook metadata and configuration
  HookMetadata get metadata;

  /// Before flag evaluation
  Future<void> before(HookContext context);

  /// After successful evaluation
  Future<void> after(HookContext context);

  /// When an error occurs
  Future<void> error(HookContext context);

  /// Always executed at the end
  Future<void> finally_(HookContext context);
}

/// Manager for hook registration and execution
class HookManager {
  final List<Hook> _hooks = [];
  final bool _failFast;
  final Duration _defaultTimeout;

  HookManager({
    bool failFast = false,
    Duration defaultTimeout = const Duration(seconds: 5),
  })  : _failFast = failFast,
        _defaultTimeout = defaultTimeout;

  /// Register a new hook
  void addHook(Hook hook) {
    _hooks.add(hook);
    _sortHooks();
  }

  /// Execute hooks for a specific stage
  Future<void> executeHooks(
    HookStage stage,
    String flagKey,
    Map<String, dynamic>? context, {
    dynamic result,
    Exception? error,
  }) async {
    final hookContext = HookContext(
      flagKey: flagKey,
      evaluationContext: context,
      result: result,
      error: error,
    );

    for (final hook in _hooks) {
      try {
        await _executeHookWithTimeout(
          hook,
          stage,
          hookContext,
          hook.metadata.config.timeout,
        );
      } catch (e) {
        if (_failFast || !hook.metadata.config.continueOnError) {
          rethrow;
        }
        print('Error in ${hook.metadata.name} hook: $e');
      }
    }
  }

  /// Sort hooks by priority
  void _sortHooks() {
    _hooks.sort((a, b) =>
        a.metadata.priority.index.compareTo(b.metadata.priority.index));
  }

  /// Execute a single hook with timeout
  Future<void> _executeHookWithTimeout(
    Hook hook,
    HookStage stage,
    HookContext context,
    Duration? timeout,
  ) async {
    final effectiveTimeout = timeout ?? _defaultTimeout;

    Future<void> hookExecution;
    switch (stage) {
      case HookStage.BEFORE:
        hookExecution = hook.before(context);
        break;
      case HookStage.AFTER:
        hookExecution = hook.after(context);
        break;
      case HookStage.ERROR:
        hookExecution = hook.error(context);
        break;
      case HookStage.FINALLY:
        hookExecution = hook.finally_(context);
        break;
    }

    await hookExecution.timeout(
      effectiveTimeout,
      onTimeout: () {
        throw TimeoutException(
          'Hook ${hook.metadata.name} timed out after ${effectiveTimeout.inSeconds} seconds',
        );
      },
    );
  }
}
