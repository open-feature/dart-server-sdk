// client_test.dart
// Tests for the feature flag client implementation

import 'package:test/test.dart';
import '../lib/client.dart';
import '../lib/hooks.dart';
import '../lib/evaluation_context.dart';
import '../lib/feature_provider.dart';

/// Mock provider for testing
class MockProvider implements OpenFeatureProvider {
  bool returnValue;
  bool throwError;
  int callCount = 0;

  MockProvider({
    this.returnValue = false,
    this.throwError = false,
  });

  @override
  OpenFeatureProviderMetadata get metadata =>
      OpenFeatureProviderMetadata("MockProvider");

  @override
  ProviderState get state => ProviderState.READY;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> shutdown() async {}

  @override
  Future<bool> getBooleanFlag(String flagKey,
      {Map<String, dynamic>? context}) async {
    callCount++;
    if (throwError) {
      throw Exception('Mock provider error');
    }
    return returnValue;
  }

  @override
  Future<String> getStringFlag(String flagKey,
      {Map<String, dynamic>? context}) async {
    throw UnimplementedError();
  }

  @override
  Future<int> getIntegerFlag(String flagKey,
      {Map<String, dynamic>? context}) async {
    throw UnimplementedError();
  }

  @override
  Future<double> getDoubleFlag(String flagKey,
      {Map<String, dynamic>? context}) async {
    throw UnimplementedError();
  }

  @override
  Future<dynamic> getObjectFlag(String flagKey,
      {Map<String, dynamic>? context}) async {
    throw UnimplementedError();
  }
}

/// Test hook implementation for testing hook execution order
class TestHook implements OpenFeatureHook {
  final List<String> executionOrder = [];
  final String hookName;

  TestHook(this.hookName);

  @override
  HookMetadata get metadata => HookMetadata(name: hookName);

  @override
  Future<void> beforeEvaluation(
      String flagKey, Map<String, dynamic>? context) async {
    executionOrder.add('$hookName:before');
  }

  @override
  Future<void> afterEvaluation(
      String flagKey, dynamic result, Map<String, dynamic>? context) async {
    executionOrder.add('$hookName:after');
  }

  @override
  Future<void> onError(
      String flagKey, Exception error, Map<String, dynamic>? context) async {
    executionOrder.add('$hookName:error');
  }

  @override
  Future<void> finally_(String flagKey, Map<String, dynamic>? context) async {
    executionOrder.add('$hookName:finally');
  }
}

void main() {
  group('FeatureClient Tests', () {
    late FeatureClient client;
    late HookManager hookManager;
    late EvaluationContext defaultContext;
    late MockProvider mockProvider;

    setUp(() {
      hookManager = HookManager();
      defaultContext = EvaluationContext(attributes: {'environment': 'test'});
      mockProvider = MockProvider();
      client = FeatureClient(
        metadata: ClientMetadata(name: 'test-client'),
        hookManager: hookManager,
        defaultContext: defaultContext,
        provider: mockProvider,
      );
    });

    test('client metadata is correctly initialized', () {
      expect(client.metadata.name, equals('test-client'));
      expect(client.metadata.version, equals('1.0.0'));
    });

    test('getBooleanFlag uses default context when none provided', () async {
      mockProvider.returnValue = true;
      final result = await client.getBooleanFlag('test-flag');
      expect(result, isTrue);
      expect(mockProvider.callCount, equals(1));
    });

    test('getBooleanFlag uses provided context over default', () async {
      final customContext = EvaluationContext(
        attributes: {'environment': 'prod'},
      );

      await client.getBooleanFlag(
        'test-flag',
        context: customContext,
      );

      // Verify that the custom context was passed to provider
      expect(mockProvider.callCount, equals(1));
    });

    test('hooks execute during flag evaluation', () async {
      final testHook = TestHook('testHook');
      hookManager.addHook(testHook);

      await client.getBooleanFlag('test-flag');

      expect(
          testHook.executionOrder,
          equals([
            'testHook:before',
            'testHook:after',
            'testHook:finally',
          ]));
    });

    test('error in flag evaluation triggers error hook', () async {
      final testHook = TestHook('errorHook');
      hookManager.addHook(testHook);
      mockProvider.throwError = true;

      await client.getBooleanFlag('test-flag');

      expect(
          testHook.executionOrder,
          equals([
            'errorHook:before',
            'errorHook:error',
            'errorHook:finally',
          ]));
    });

    test('client returns default value on provider error', () async {
      mockProvider.throwError = true;
      final result =
          await client.getBooleanFlag('test-flag', defaultValue: true);
      expect(result, isTrue);
    });

    test('client uses provider result when available', () async {
      mockProvider.returnValue = true;
      final result =
          await client.getBooleanFlag('test-flag', defaultValue: false);
      expect(result, isTrue);
    });

    test('hooks execute in correct order with successful evaluation', () async {
      final hook1 = TestHook('first');
      final hook2 = TestHook('second');

      hookManager.addHook(hook1);
      hookManager.addHook(hook2);

      await client.getBooleanFlag('test-flag');

      expect(
          hook1.executionOrder,
          equals([
            'first:before',
            'first:after',
            'first:finally',
          ]));

      expect(
          hook2.executionOrder,
          equals([
            'second:before',
            'second:after',
            'second:finally',
          ]));
    });
  });
}
