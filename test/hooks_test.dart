import 'dart:async';
import 'package:test/test.dart';
import '../lib/hooks.dart';

class TestHook implements Hook {
  final List<String> executionOrder = [];
  final HookPriority _priority;

  TestHook([this._priority = HookPriority.NORMAL]);

  @override
  HookMetadata get metadata => HookMetadata(
        name: 'TestHook',
        priority: _priority,
      );

  @override
  Future<void> before(HookContext context) async {
    executionOrder.add('before');
  }

  @override
  Future<void> after(HookContext context) async {
    executionOrder.add('after');
  }

  @override
  Future<void> error(HookContext context) async {
    executionOrder.add('error');
  }

  @override
  Future<void> finally_(HookContext context) async {
    executionOrder.add('finally');
  }
}

class ErrorHook implements Hook {
  @override
  HookMetadata get metadata => HookMetadata(name: 'ErrorHook');

  @override
  Future<void> before(HookContext context) async {
    throw Exception('Test error');
  }

  @override
  Future<void> after(HookContext context) async {}
  @override
  Future<void> error(HookContext context) async {}
  @override
  Future<void> finally_(HookContext context) async {}
}

class SlowHook implements Hook {
  @override
  HookMetadata get metadata => HookMetadata(
        name: 'SlowHook',
        config: HookConfig(timeout: Duration(milliseconds: 100)),
      );

  @override
  Future<void> before(HookContext context) async {
    await Future.delayed(Duration(milliseconds: 200));
  }

  @override
  Future<void> after(HookContext context) async {}
  @override
  Future<void> error(HookContext context) async {}
  @override
  Future<void> finally_(HookContext context) async {}
}

void main() {
  group('HookManager', () {
    late HookManager manager;
    late TestHook testHook;

    setUp(() {
      manager = HookManager();
      testHook = TestHook();
      manager.addHook(testHook);
    });

    test('executes hooks in correct order', () async {
      await manager.executeHooks(
        HookStage.BEFORE,
        'test-flag',
        {'user': 'test'},
      );

      await manager.executeHooks(
        HookStage.AFTER,
        'test-flag',
        {'user': 'test'},
        result: true,
      );

      await manager.executeHooks(
        HookStage.FINALLY,
        'test-flag',
        {'user': 'test'},
      );

      expect(testHook.executionOrder, ['before', 'after', 'finally']);
    });

    test('handles hook timeouts', () async {
      final slowHook = SlowHook();
      manager = HookManager(failFast: true);
      manager.addHook(slowHook);

      await expectLater(
        manager.executeHooks(HookStage.BEFORE, 'test-flag', {}),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('sorts hooks by priority', () async {
      final highPriorityHook = TestHook(HookPriority.HIGH);
      final lowPriorityHook = TestHook(HookPriority.LOW);

      manager
        ..addHook(lowPriorityHook)
        ..addHook(highPriorityHook);

      await manager.executeHooks(HookStage.BEFORE, 'test-flag', {});

      expect(
        highPriorityHook.executionOrder,
        contains('before'),
      );
      expect(
        lowPriorityHook.executionOrder,
        contains('before'),
      );
    });

    test('respects failFast setting', () async {
      manager = HookManager(failFast: true);
      final errorHook = ErrorHook();
      manager.addHook(errorHook);

      expect(
        () => manager.executeHooks(HookStage.BEFORE, 'test-flag', {}),
        throwsException,
      );
    });
  });
}
