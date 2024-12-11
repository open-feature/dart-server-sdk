// Hook interface and default hooks.
/// Defines the stages in the hook lifecycle
/// Used internally by the hook manager for execution ordering
enum HookStage {
  before, // before flag evaluation
  after, // after successful evaluation
  error, // when error occur
  finally_ // always executed at the end
}

/// Simple priority levels for hook execution ordering
enum HookPriority {
  HIGH, // executes first
  NORMAL, // default priority
  LOW // executes last
}

/// Metadata for hooks providing identification and configuration
class HookMetadata {
  /// Name of the hook for identification
  final String name;

  /// Priority level determining execution order
  final HookPriority priority;

  /// Whether the hook should continue on errors
  final bool continueOnError;

  const HookMetadata({
    required this.name,
    this.priority = HookPriority.NORMAL,
    this.continueOnError = true,
  });
}

abstract class OpenFeatureHook {
  /// Hook metadata - provides configuration and identification
  HookMetadata get metadata;

  /// Logic to execute before a flag is evaluated. (Before flag evaluation)
  Future<void> beforeEvaluation(
      String flagKey, Map<String, dynamic>? context) async {}

  /// Logic to execute after a flag is evaluated. (After successful flag evaluation)
  Future<void> afterEvaluation(
    String flagKey,
    dynamic result,
    Map<String, dynamic>? context,
  ) async {}

  /// When an error occurs during evaluation
  Future<void> onError(
    String flagKey,
    Exception error,
    Map<String, dynamic>? context,
  ) async {}

  /// Always executed after evaluation completes
  Future<void> finally_(String flagKey, Map<String, dynamic>? context) async {}
}

/// Manager class handling hook registration and execution
class HookManager {
  final List<OpenFeatureHook> _hooks = [];
  final bool _failFast;

  HookManager({bool failFast = false}) : _failFast = failFast;

  /// Register a new hook
  void addHook(OpenFeatureHook hook) {
    _hooks.add(hook);
    // Sort hooks by priority
    _hooks.sort((a, b) =>
        a.metadata.priority.index.compareTo(b.metadata.priority.index));
  }

  /// Execute hooks for a specific stage
  Future<void> executeHooks(
    HookStage stage,
    String flagKey,
    Map<String, dynamic>? context, {
    dynamic result,
    Exception? error,
  }) async {
    for (final hook in _hooks) {
      try {
        switch (stage) {
          case HookStage.before:
            await hook.beforeEvaluation(flagKey, context);
            break;
          case HookStage.after:
            await hook.afterEvaluation(flagKey, result, context);
            break;
          case HookStage.error:
            if (error != null) {
              await hook.onError(flagKey, error, context);
            }
            break;
          case HookStage.finally_:
            await hook.finally_(flagKey, context);
            break;
        }
      } catch (e) {
        if (_failFast || !hook.metadata.continueOnError) {
          rethrow;
        }
        // Log error but continue if hook allows it
        print('Error in ${hook.metadata.name} hook: $e');
      }
    }
  }
}

/// Example audit hook implementation showing usage of the enhanced system
class AuditHook implements OpenFeatureHook {
  final bool includeContext;
  final HookPriority priority;

  AuditHook({
    this.includeContext = false,
    this.priority = HookPriority.LOW,
  });

  @override
  HookMetadata get metadata => HookMetadata(
        name: 'AuditHook',
        priority: priority,
        continueOnError: true,
      );

  @override
  Future<void> beforeEvaluation(
      String flagKey, Map<String, dynamic>? context) async {
    final contextLog = includeContext ? ', Context: $context' : '';
    print('Before evaluating flag: $flagKey$contextLog');
  }

  @override
  Future<void> afterEvaluation(
    String flagKey,
    dynamic result,
    Map<String, dynamic>? context,
  ) async {
    final contextLog = includeContext ? ', Context: $context' : '';
    print('After evaluating flag: $flagKey, Result: $result$contextLog');
  }

  @override
  Future<void> onError(
    String flagKey,
    Exception error,
    Map<String, dynamic>? context,
  ) async {
    final contextLog = includeContext ? ', Context: $context' : '';
    print('Error evaluating flag: $flagKey, Error: $error$contextLog');
  }

  @override
  Future<void> finally_(String flagKey, Map<String, dynamic>? context) {
    final contextLog = includeContext ? ', Context: $context' : '';
    print('Finally evaluating flag: $flagKey$contextLog');
    return Future.value();
  }
}
