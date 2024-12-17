import 'package:test/test.dart';
import 'dart:async';
import '../lib/hooks.dart';

/// Mock hook implementation for testing
class TestHook implements Hook {
  final List<String> executionLog;
  final String name;
  final HookPriority priority;
  final bool throwError;
  final Duration? timeout;

  TestHook({
    required this.executionLog,
    required this.name,
    this.priority = HookPriority.NORMAL,
    this.throwError = false,
    this.timeout,
  });

  @override
  HookMetadata get metadata => HookMetadata(
        name: name,
        priority: priority,
        config: HookConfig(
          continueOnError: true,
          timeout: timeout ?? const Duration(seconds: 5),
        ),
      );

  @override
  Future<void> before(HookContext context) async {
    if (throwError) throw Exception('Test error in before hook');
    executionLog.add('$name:before');
  }

  @override
  Future<void> after(HookContext context) async {
    if (throwError) throw Exception('Test error in after hook');
    executionLog.add('$name:after');
  }

  @override
  Future<void> error(HookContext context) async {
    if (throwError) throw Exception('Test error in error hook');
    executionLog.add('$name:error');
  }

  @override
  Future<void> finally_(HookContext context) async {
    if (throwError) throw Exception('Test error in finally hook');
    executionLog.add('$name:finally');
  }
}

/// Slow hook that always times out
class SlowHook implements Hook {
  final Duration _delay;

  SlowHook() : _delay = const Duration(seconds: 2);

  @override
  HookMetadata get metadata => HookMetadata(
        name: 'SlowHook',
        config: HookConfig(
          timeout: const Duration(milliseconds: 100),
          continueOnError: false,
        ),
      );

  @override
  Future<void> before(HookContext context) async {
    // This operation will take longer than the timeout
    await Future.delayed(_delay);
  }

  @override
  Future<void> after(HookContext context) async {
    await Future.delayed(_delay);
  }

  @override
  Future<void> error(HookContext context) async {
    await Future.delayed(_delay);
  }

  @override
  Future<void> finally_(HookContext context) async {
    await Future.delayed(_delay);
  }
}

void main() {
  group('Hook System Tests', () {
    late HookManager hookManager;
    late List<String> executionLog;

    setUp(() {
      executionLog = [];
    });

    test('hooks execute in priority order', () async {
      hookManager = HookManager();
      final hooks = [
        TestHook(
          executionLog: executionLog,
          name: 'low',
          priority: HookPriority.LOW,
        ),
        TestHook(
          executionLog: executionLog,
          name: 'critical',
          priority: HookPriority.CRITICAL,
        ),
        TestHook(
          executionLog: executionLog,
          name: 'high',
          priority: HookPriority.HIGH,
        ),
        TestHook(
          executionLog: executionLog,
          name: 'normal',
          priority: HookPriority.NORMAL,
        ),
      ];

      hooks.forEach(hookManager.addHook);

      await hookManager.executeHooks(
        HookStage.BEFORE,
        'test-flag',
        {'context': 'value'},
      );

      expect(
        executionLog,
        equals([
          'critical:before',
          'high:before',
          'normal:before',
          'low:before',
        ]),
      );
    });

    test('hook timeout throws TimeoutException', () async {
      final slowHook = SlowHook();
      hookManager = HookManager(failFast: true);
      hookManager.addHook(slowHook);

      // We expect this to time out after 100ms (set in SlowHook metadata)
      await expectLater(
        () => Future.sync(() => hookManager.executeHooks(
              HookStage.BEFORE,
              'test-flag',
              null,
            )),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('complete hook lifecycle executes in correct order', () async {
      hookManager = HookManager();
      final hook = TestHook(executionLog: executionLog, name: 'lifecycle');
      hookManager.addHook(hook);

      await hookManager.executeHooks(
        HookStage.BEFORE,
        'test-flag',
        {'stage': 'before'},
      );

      await hookManager.executeHooks(
        HookStage.AFTER,
        'test-flag',
        {'stage': 'after'},
        result: true,
      );

      await hookManager.executeHooks(
        HookStage.ERROR,
        'test-flag',
        {'stage': 'error'},
        error: Exception('test error'),
      );

      await hookManager.executeHooks(
        HookStage.FINALLY,
        'test-flag',
        {'stage': 'finally'},
      );

      expect(
        executionLog,
        equals([
          'lifecycle:before',
          'lifecycle:after',
          'lifecycle:error',
          'lifecycle:finally',
        ]),
      );
    });

    test('error in hook with failFast=true stops execution', () async {
      hookManager = HookManager(failFast: true);

      final hooks = [
        TestHook(
          executionLog: executionLog,
          name: 'first',
          throwError: true,
        ),
        TestHook(
          executionLog: executionLog,
          name: 'second',
        ),
      ];

      hooks.forEach(hookManager.addHook);

      await expectLater(
        () => hookManager.executeHooks(
          HookStage.BEFORE,
          'test-flag',
          null,
        ),
        throwsA(isA<Exception>()),
      );

      expect(executionLog, isEmpty);
    });

    test('error in hook with failFast=false continues execution', () async {
      hookManager = HookManager();
      final hooks = [
        TestHook(
          executionLog: executionLog,
          name: 'first',
          throwError: true,
        ),
        TestHook(
          executionLog: executionLog,
          name: 'second',
        ),
      ];

      hooks.forEach(hookManager.addHook);

      await hookManager.executeHooks(
        HookStage.BEFORE,
        'test-flag',
        null,
      );

      expect(executionLog, equals(['second:before']));
    });

    test('HookConfig defaults are set correctly', () {
      final config = HookConfig();

      expect(config.continueOnError, isTrue);
      expect(config.timeout, equals(const Duration(seconds: 5)));
      expect(config.customConfig, isEmpty);
    });

    test('HookMetadata construction with custom values', () {
      final metadata = HookMetadata(
        name: 'CustomHook',
        version: '2.0.0',
        priority: HookPriority.HIGH,
        config: HookConfig(
          continueOnError: false,
          timeout: const Duration(seconds: 10),
          customConfig: {'key': 'value'},
        ),
      );

      expect(metadata.name, equals('CustomHook'));
      expect(metadata.version, equals('2.0.0'));
      expect(metadata.priority, equals(HookPriority.HIGH));
      expect(metadata.config.continueOnError, isFalse);
      expect(metadata.config.timeout, equals(const Duration(seconds: 10)));
      expect(metadata.config.customConfig, containsPair('key', 'value'));
    });
  });
}
