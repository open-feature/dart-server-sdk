import 'package:test/test.dart';
import '../lib/open_feature_api.dart';
import 'helpers/open_feature_api_test_helpers.dart'; // Import test helper

void main() {
  group('OpenFeatureAPI Tests', () {
    setUp(() {
      // Reset the singleton before each test
      OpenFeatureAPI.reset();
    });

    tearDown(() {
      // Clean up after each test
      OpenFeatureAPI.reset();
    });

    test('Singleton behavior: always returns the same instance', () {
      final instance1 = OpenFeatureAPI();
      final instance2 = OpenFeatureAPI();

      expect(instance1, same(instance2),
          reason: 'OpenFeatureAPI should be a singleton.');
    });

    test('Default provider is NoOpProvider', () {
      final api = OpenFeatureAPI();
      expect(api.provider.name, equals('NoOpProvider'),
          reason: 'Default provider should be NoOpProvider.');
    });

    test('Set and get provider updates correctly', () async {
      final api = OpenFeatureAPI();
      final customProvider = _MockProvider();

      api.setProvider(customProvider);

      expect(api.provider, equals(customProvider),
          reason: 'Provider should update to the new instance.');
    });

    test('Stream notifies on provider change', () async {
      final api = OpenFeatureAPI();
      final customProvider = _MockProvider();
      final stream = api.providerUpdates;

      final future = expectLater(
        stream,
        emitsInOrder([customProvider]),
      );

      api.setProvider(customProvider);

      await future;
    });

    test('Global context is set and retrieved correctly', () {
      final api = OpenFeatureAPI();
      final context = EvaluationContext({'user': 'test-user'});

      api.setGlobalContext(context);

      expect(api.globalContext, equals(context),
          reason: 'Global context should match the one set.');
    });

    test('Add and retrieve global hooks', () {
      final api = OpenFeatureAPI();
      final hook1 = _MockHook();
      final hook2 = _MockHook();

      api.addHooks([hook1, hook2]);

      expect(api.hooks, containsAll([hook1, hook2]),
          reason: 'Hooks should include all added hooks.');
    });
  });
}

// Mock provider for testing
class _MockProvider implements FeatureProvider {
  @override
  String get name => 'MockProvider';

  @override
  Future<dynamic> getFlag(String flagKey,
      {Map<String, dynamic>? context}) async {
    return 'mock-value';
  }
}

// Mock hook for testing
class _MockHook implements Hook {
  @override
  void beforeEvaluation(String flagKey, Map<String, dynamic>? context) {}

  @override
  void afterEvaluation(
      String flagKey, dynamic result, Map<String, dynamic>? context) {}
}
