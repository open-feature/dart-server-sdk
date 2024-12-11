import 'package:test/test.dart';
import '../lib/open_feature_api.dart';
import 'helpers/open_feature_api_test_helpers.dart';

void main() {
  group('OpenFeatureAPI Tests', () {
    late OpenFeatureAPI api;

    setUp(() {
      // Ensure a fresh singleton instance before each test
      OpenFeatureAPILocator.instance = OpenFeatureAPI();
      api = OpenFeatureAPILocator.instance;
    });

    tearDown(() {
      // Clean up resources
      api.dispose();
    });

    test('Singleton behavior: always returns the same instance', () {
      final instance1 = OpenFeatureAPI();
      final instance2 = OpenFeatureAPI();

      expect(instance1, same(instance2),
          reason: 'OpenFeatureAPI should be a singleton.');
    });

    test('Default provider is OpenFeatureNoOpProvider', () {
      expect(api.provider.name, equals('OpenFeatureNoOpProvider'),
          reason: 'Default provider should be OpenFeatureNoOpProvider.');
    });

    test('Set and get provider updates correctly', () async {
      final customProvider = _MockProvider();
      api.setProvider(customProvider);

      expect(api.provider, equals(customProvider),
          reason: 'Provider should update to the new instance.');
    });

    test('Stream notifies on provider change', () async {
      final customProvider = _MockProvider();
      final stream = api.providerUpdates;

      final future = expectLater(stream, emits(customProvider));
      api.setProvider(customProvider);

      await future;
    });

    test('Global context is set and retrieved correctly', () {
      final context = OpenFeatureEvaluationContext({'user': 'test-user'});
      api.setGlobalContext(context);

      expect(api.globalContext, equals(context),
          reason: 'Global context should match the one set.');
    });

    test('Add and retrieve global hooks', () {
      final hook1 = _MockHook();
      final hook2 = _MockHook();

      api.addHooks([hook1, hook2]);

      expect(api.hooks, containsAll([hook1, hook2]),
          reason: 'Hooks should include all added hooks.');
    });

    test('Boolean flag evaluation returns false when no provider', () async {
      final result = await api.evaluateBooleanFlag('flag-key', 'client-1');

      expect(result, isFalse,
          reason: 'Boolean flag should return false with no provider.');
    });

    test('Provider evaluation triggers hooks', () async {
      final hook = _MockHook();
      api.addHooks([hook]);
      final customProvider = _MockProvider();
      api.setProvider(customProvider);

      await api.evaluateBooleanFlag('flag-key', 'client-1');

      expect(hook.beforeEvaluationCalled, isTrue,
          reason: 'beforeEvaluation hook should be triggered.');
      expect(hook.afterEvaluationCalled, isTrue,
          reason: 'afterEvaluation hook should be triggered.');
    });
  });
}

// Mock provider for testing
class _MockProvider implements OpenFeatureProvider {
  @override
  String get name => 'MockProvider';

  @override
  Future<dynamic> getFlag(String flagKey,
      {Map<String, dynamic>? context}) async {
    return true; // Example mock return value
  }
}

// Mock hook for testing
class _MockHook implements OpenFeatureHook {
  bool beforeEvaluationCalled = false;
  bool afterEvaluationCalled = false;

  @override
  void beforeEvaluation(String flagKey, Map<String, dynamic>? context) {
    beforeEvaluationCalled = true;
  }

  @override
  void afterEvaluation(
      String flagKey, dynamic result, Map<String, dynamic>? context) {
    afterEvaluationCalled = true;
  }
}
