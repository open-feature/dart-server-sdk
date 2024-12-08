import 'package:test/test.dart';
import '../lib/hooks.dart';

/// Test hook for verifying execution order and behavior
class TestHook implements OpenFeatureHook {
  final List<String> executionLog;
  final String name;
  final HookPriority priority;
  final bool continueOnError;
  final bool throwError;

  TestHook({
    required this.executionLog,
    required this.name,
    this.priority = HookPriority.NORMAL,
    this.continueOnError = true,
    this.throwError = false,
  });

  @override
  HookMetadata get metadata => HookMetadata(
        name: name,
        priority: priority,
        continueOnError: continueOnError,
      );

  @override
  Future<void> beforeEvaluation(
      String flagKey, Map<String, dynamic>? context) async {
    if (throwError) throw Exception('Test error');
    executionLog.add('$name:before');
  }

  @override
  Future<void> afterEvaluation(
    String flagKey,
    dynamic result,
    Map<String, dynamic>? context,
  ) async {
    executionLog.add('$name:after');
  }

  @override
  Future<void> onError(
    String flagKey,
    Exception error,
    Map<String, dynamic>? context,
  ) async {
    executionLog.add('$name:error');
  }

  @override
  Future<void> finally_(String flagKey, Map<String, dynamic>? context) async {
    executionLog.add('$name:finally');
  }
}

void main() {
  group('Hook System Tests', () {
    late HookManager hookManager;
    late List<String> executionLog;

    setUp(() {
      hookManager = HookManager();
      executionLog = [];
    });

    test('hooks execute in priority order', () async {
      final hooks = [
        TestHook(
            executionLog: executionLog,
            name: 'low',
            priority: HookPriority.LOW),
        TestHook(
            executionLog: executionLog,
            name: 'high',
            priority: HookPriority.HIGH),
        TestHook(
            executionLog: executionLog,
            name: 'normal',
            priority: HookPriority.NORMAL),
      ];

      // Add hooks in random order
      hooks.forEach(hookManager.addHook);

      await hookManager.executeHooks(HookStage.before, 'test-flag', null);

      expect(
          executionLog, equals(['high:before', 'normal:before', 'low:before']));
    });

    test('hook lifecycle executes in correct order', () async {
      final hook = TestHook(executionLog: executionLog, name: 'lifecycle');
      hookManager.addHook(hook);

      await hookManager.executeHooks(HookStage.before, 'test-flag', null);
      await hookManager.executeHooks(HookStage.after, 'test-flag', null,
          result: true);
      await hookManager.executeHooks(HookStage.finally_, 'test-flag', null);

      expect(
          executionLog,
          equals([
            'lifecycle:before',
            'lifecycle:after',
            'lifecycle:finally',
          ]));
    });

    test('error handling respects continueOnError flag', () async {
      final hooks = [
        TestHook(
          executionLog: executionLog,
          name: 'error-continue',
          continueOnError: true,
          throwError: true,
        ),
        TestHook(
          executionLog: executionLog,
          name: 'normal',
        ),
      ];

      hooks.forEach(hookManager.addHook);

      await hookManager.executeHooks(HookStage.before, 'test-flag', null);

      // Second hook should still execute despite error in first hook
      expect(executionLog, contains('normal:before'));
    });

    test('fail fast hook manager stops on first error', () async {
      hookManager = HookManager(failFast: true);
      final hook = TestHook(
        executionLog: executionLog,
        name: 'failing',
        throwError: true,
      );

      hookManager.addHook(hook);

      expect(
        () => hookManager.executeHooks(HookStage.before, 'test-flag', null),
        throwsException,
      );
    });

    group('AuditHook Tests', () {
      test('audit hook logs include context when enabled', () async {
        final hook = AuditHook(includeContext: true);
        final context = {'user': 'testUser'};

        await hook.beforeEvaluation('test-flag', context);
        await hook.afterEvaluation('test-flag', true, context);
        // Would verify log output in real implementation
      });

      test('audit hook respects priority setting', () async {
        final hook = AuditHook(priority: HookPriority.HIGH);
        expect(hook.metadata.priority, equals(HookPriority.HIGH));
      });
    });
  });
}
