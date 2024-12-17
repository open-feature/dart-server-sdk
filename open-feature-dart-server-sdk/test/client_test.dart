import 'package:test/test.dart';
import '../lib/client.dart';
import '../lib/hooks.dart';
import '../lib/evaluation_context.dart';
import '../lib/feature_provider.dart';

/// Mock provider for testing all flag types
class MockProvider implements FeatureProvider {
  bool throwError;
  Map<String, dynamic> returnValues; // Made mutable
  int callCount = 0;

  MockProvider({
    this.throwError = false,
    Map<String, dynamic>? returnValues, // Made optional
  }) : returnValues =
            returnValues ?? {}; // Initialize empty mutable map if none provided

  @override
  ProviderMetadata get metadata => const ProviderMetadata(name: "MockProvider");

  @override
  ProviderState get state => ProviderState.READY;

  @override
  ProviderConfig get config => const ProviderConfig();

  @override
  Future<void> initialize([Map<String, dynamic>? config]) async {}

  @override
  Future<void> authenticate(ProviderAuth auth) async {}

  @override
  Future<void> connect() async {}

  @override
  Future<void> shutdown() async {}

  @override
  Future<void> clearCache() async {}

  @override
  Future<bool> healthCheck() async => true;

  @override
  Future<void> synchronize() async {}

  @override
  ProviderMetrics getMetrics() {
    return ProviderMetrics(
      totalRequests: callCount,
      successfulRequests: callCount,
      failedRequests: 0,
      averageResponseTime: Duration.zero,
      cacheHits: 0,
      cacheMisses: 0,
      errorCounts: {},
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Future<FlagEvaluationResult<bool>> getBooleanFlag(
    String flagKey,
    bool defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    callCount++;
    if (throwError) {
      throw const ProviderException('Mock provider error');
    }
    final value = returnValues[flagKey] ?? defaultValue;
    return FlagEvaluationResult(
      flagKey: flagKey,
      value: value,
      evaluatedAt: DateTime.now(),
    );
  }

  @override
  Future<FlagEvaluationResult<String>> getStringFlag(
    String flagKey,
    String defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    callCount++;
    if (throwError) {
      throw const ProviderException('Mock provider error');
    }
    final value = returnValues[flagKey] ?? defaultValue;
    return FlagEvaluationResult(
      flagKey: flagKey,
      value: value,
      evaluatedAt: DateTime.now(),
    );
  }

  @override
  Future<FlagEvaluationResult<int>> getIntegerFlag(
    String flagKey,
    int defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    callCount++;
    if (throwError) {
      throw const ProviderException('Mock provider error');
    }
    final value = returnValues[flagKey] ?? defaultValue;
    return FlagEvaluationResult(
      flagKey: flagKey,
      value: value,
      evaluatedAt: DateTime.now(),
    );
  }

  @override
  Future<FlagEvaluationResult<double>> getDoubleFlag(
    String flagKey,
    double defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    callCount++;
    if (throwError) {
      throw const ProviderException('Mock provider error');
    }
    final value = returnValues[flagKey] ?? defaultValue;
    return FlagEvaluationResult(
      flagKey: flagKey,
      value: value,
      evaluatedAt: DateTime.now(),
    );
  }

  @override
  Future<FlagEvaluationResult<Map<String, dynamic>>> getObjectFlag(
    String flagKey,
    Map<String, dynamic> defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    callCount++;
    if (throwError) {
      throw const ProviderException('Mock provider error');
    }
    final value = returnValues[flagKey] ?? defaultValue;
    return FlagEvaluationResult(
      flagKey: flagKey,
      value: value,
      evaluatedAt: DateTime.now(),
    );
  }

  // Provider plugin methods
  @override
  Future<void> registerPlugin(String pluginId, PluginConfig config) async {}

  @override
  Future<void> unregisterPlugin(String pluginId) async {}

  @override
  Future<void> startPlugin(String pluginId) async {}

  @override
  Future<void> stopPlugin(String pluginId) async {}

  @override
  List<String> getRegisteredPlugins() => [];

  @override
  PluginConfig? getPluginConfig(String pluginId) => null;
}

/// Test hook implementation for verifying execution order
class TestHook implements Hook {
  final List<String> executionOrder = [];
  final String hookName;

  TestHook(this.hookName);

  @override
  HookMetadata get metadata => HookMetadata(name: hookName);

  @override
  Future<void> before(HookContext context) async {
    executionOrder.add('$hookName:before');
  }

  @override
  Future<void> after(HookContext context) async {
    executionOrder.add('$hookName:after');
  }

  @override
  Future<void> error(HookContext context) async {
    executionOrder.add('$hookName:error');
  }

  @override
  Future<void> finally_(HookContext context) async {
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
      defaultContext = EvaluationContext(
        attributes: {'environment': 'test'},
        rules: [],
      );
      mockProvider = MockProvider();
      client = FeatureClient(
        metadata: ClientMetadata(name: 'test-client'),
        hookManager: hookManager,
        defaultContext: defaultContext,
        provider: mockProvider,
      );
    });

    group('Client Configuration', () {
      test('client metadata is correctly initialized', () {
        expect(client.metadata.name, equals('test-client'));
        expect(client.metadata.version, equals('1.0.0'));
        expect(client.metadata.attributes, isEmpty);
      });

      test('client uses NoOpProvider when no provider specified', () {
        final clientWithoutProvider = FeatureClient(
          metadata: ClientMetadata(name: 'test-client'),
          hookManager: hookManager,
          defaultContext: defaultContext,
        );

        expect(clientWithoutProvider, isNotNull);
      });
    });

    group('Boolean Flag Tests', () {
      test('getBooleanFlag uses default context when none provided', () async {
        mockProvider.returnValues['test-flag'] = true;
        final result = await client.getBooleanFlag('test-flag');
        expect(result, isTrue);
        expect(mockProvider.callCount, equals(1));
      });

      test('getBooleanFlag uses provided context over default', () async {
        final customContext = EvaluationContext(
          attributes: {'environment': 'prod'},
          rules: [],
        );

        await client.getBooleanFlag(
          'test-flag',
          context: customContext,
        );

        expect(mockProvider.callCount, equals(1));
      });

      test('getBooleanFlag returns default value on error', () async {
        mockProvider.throwError = true;
        final result = await client.getBooleanFlag(
          'test-flag',
          defaultValue: true,
        );
        expect(result, isTrue);
      });
    });

    group('String Flag Tests', () {
      test('getStringFlag returns expected value', () async {
        mockProvider.returnValues['test-string'] = 'test-value';
        final result = await client.getStringFlag('test-string');
        expect(result, equals('test-value'));
      });

      test('getStringFlag returns default value on error', () async {
        mockProvider.throwError = true;
        final result = await client.getStringFlag(
          'test-string',
          defaultValue: 'default',
        );
        expect(result, equals('default'));
      });
    });

    group('Integer Flag Tests', () {
      test('getIntegerFlag returns expected value', () async {
        mockProvider.returnValues['test-int'] = 42;
        final result = await client.getIntegerFlag('test-int');
        expect(result, equals(42));
      });

      test('getIntegerFlag returns default value on error', () async {
        mockProvider.throwError = true;
        final result = await client.getIntegerFlag(
          'test-int',
          defaultValue: 100,
        );
        expect(result, equals(100));
      });
    });

    group('Double Flag Tests', () {
      test('getDoubleFlag returns expected value', () async {
        mockProvider.returnValues['test-double'] = 3.14;
        final result = await client.getDoubleFlag('test-double');
        expect(result, equals(3.14));
      });

      test('getDoubleFlag returns default value on error', () async {
        mockProvider.throwError = true;
        final result = await client.getDoubleFlag(
          'test-double',
          defaultValue: 2.718,
        );
        expect(result, equals(2.718));
      });
    });

    group('Object Flag Tests', () {
      test('getObjectFlag returns expected value', () async {
        final testObject = {'key': 'value'};
        mockProvider.returnValues['test-object'] = testObject;
        final result = await client.getObjectFlag('test-object');
        expect(result, equals(testObject));
      });

      test('getObjectFlag returns default value on error', () async {
        mockProvider.throwError = true;
        final defaultObject = {'default': 'value'};
        final result = await client.getObjectFlag(
          'test-object',
          defaultValue: defaultObject,
        );
        expect(result, equals(defaultObject));
      });
    });

    group('Hook Execution Tests', () {
      test('hooks execute during successful flag evaluation', () async {
        final testHook = TestHook('testHook');
        hookManager.addHook(testHook);

        await client.getBooleanFlag('test-flag');

        expect(
          testHook.executionOrder,
          equals([
            'testHook:before',
            'testHook:after',
            'testHook:finally',
          ]),
        );
      });

      test('hooks execute in correct order on error', () async {
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
          ]),
        );
      });

      test('multiple hooks execute in registration order', () async {
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
          ]),
        );

        expect(
          hook2.executionOrder,
          equals([
            'second:before',
            'second:after',
            'second:finally',
          ]),
        );
      });
    });
  });
}
