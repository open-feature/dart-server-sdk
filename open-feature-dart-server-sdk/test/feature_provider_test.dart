import 'package:test/test.dart';
import '../lib/feature_provider.dart';

void main() {
  group('Provider Tests', () {
    late NoOpProvider provider;

    setUp(() {
      provider = NoOpProvider();
    });

    group('Provider Lifecycle', () {
      test('initial state is NOT_READY', () {
        expect(provider.state, equals(ProviderState.NOT_READY));
      });

      test('initialization changes state to READY', () async {
        await provider.initialize();
        expect(provider.state, equals(ProviderState.READY));
      });

      test('shutdown changes state to SHUTDOWN', () async {
        await provider.initialize();
        await provider.shutdown();
        expect(provider.state, equals(ProviderState.SHUTDOWN));
      });

      test('health check returns true only when READY', () async {
        expect(await provider.healthCheck(), isFalse);
        await provider.initialize();
        expect(await provider.healthCheck(), isTrue);
        await provider.shutdown();
        expect(await provider.healthCheck(), isFalse);
      });
    });

    group('Provider Metadata', () {
      test('metadata contains correct default values', () {
        final metadata = provider.metadata;
        expect(metadata.name, equals('NoOpProvider'));
        expect(metadata.version, equals('1.0.0'));
        expect(metadata.capabilities, containsPair('supportsTargeting', false));
        expect(metadata.supportedFeatures, isEmpty);
      });
    });

    group('Flag Evaluation', () {
      setUp(() async {
        await provider.initialize();
      });

      test('getBooleanFlag returns FlagEvaluationResult with default value',
          () async {
        final result = await provider.getBooleanFlag('test-flag', true);
        expect(result, isA<FlagEvaluationResult<bool>>());
        expect(result.value, isTrue);
        expect(result.flagKey, equals('test-flag'));
        expect(result.reason, equals('DEFAULT'));
        expect(result.evaluatorId, equals('NoOpProvider'));
      });

      test('getStringFlag returns FlagEvaluationResult with default value',
          () async {
        final result = await provider.getStringFlag('test-flag', 'default');
        expect(result.value, equals('default'));
      });

      test('getIntegerFlag returns FlagEvaluationResult with default value',
          () async {
        final result = await provider.getIntegerFlag('test-flag', 42);
        expect(result.value, equals(42));
      });

      test('getDoubleFlag returns FlagEvaluationResult with default value',
          () async {
        final result = await provider.getDoubleFlag('test-flag', 3.14);
        expect(result.value, equals(3.14));
      });

      test('getObjectFlag returns FlagEvaluationResult with default value',
          () async {
        final defaultValue = {'key': 'value'};
        final result = await provider.getObjectFlag('test-flag', defaultValue);
        expect(result.value, equals(defaultValue));
      });

      test('throws ProviderException when not in READY state', () async {
        await provider.shutdown();
        expect(
          () => provider.getBooleanFlag('test-flag', false),
          throwsA(isA<ProviderException>().having(
            (e) => e.code,
            'error code',
            equals('PROVIDER_NOT_READY'),
          )),
        );
      });
    });

    group('Metrics Tracking', () {
      setUp(() async {
        await provider.initialize();
      });

      test('metrics are updated after flag evaluations', () async {
        await provider.getBooleanFlag('test-flag', false);
        await provider.getStringFlag('test-flag', '');

        final metrics = provider.getMetrics();
        expect(metrics.totalRequests, equals(2));
        expect(metrics.successfulRequests, equals(2));
        expect(metrics.failedRequests, equals(0));
      });

      test('cache metrics are tracked', () async {
        final metrics = provider.getMetrics();
        expect(metrics.cacheHits, equals(0));
        expect(metrics.cacheMisses, equals(0));
      });
    });

    group('Plugin Management', () {
      late PluginConfig testPlugin;

      setUp(() async {
        await provider.initialize();
        testPlugin = PluginConfig(
          pluginId: 'test-plugin',
          version: '1.0.0',
          settings: {'key': 'value'},
        );
      });

      test('can register and retrieve plugin', () async {
        await provider.registerPlugin('test-plugin', testPlugin);
        expect(provider.getRegisteredPlugins(), contains('test-plugin'));
        expect(provider.getPluginConfig('test-plugin'), equals(testPlugin));
      });

      test('can unregister plugin', () async {
        await provider.registerPlugin('test-plugin', testPlugin);
        await provider.unregisterPlugin('test-plugin');
        expect(provider.getRegisteredPlugins(), isEmpty);
        expect(provider.getPluginConfig('test-plugin'), isNull);
      });

      test('throws when registering plugin with plugins disabled', () async {
        final providerWithPluginsDisabled = NoOpProvider(
          ProviderConfig(enablePlugins: false),
        );
        await providerWithPluginsDisabled.initialize();

        expect(
          () => providerWithPluginsDisabled.registerPlugin(
              'test-plugin', testPlugin),
          throwsA(isA<ProviderException>()),
        );
      });

      test('throws when starting nonexistent plugin', () async {
        expect(
          () => provider.startPlugin('nonexistent'),
          throwsA(isA<ProviderException>()),
        );
      });
    });

    group('Cache Management', () {
      setUp(() async {
        await provider.initialize();
      });

      test('clearCache clears the cache', () async {
        // First evaluation potentially caches the result
        await provider.getBooleanFlag('test-flag', true);
        await provider.clearCache();

        final metrics = provider.getMetrics();
        expect(metrics.cacheHits, equals(0));
      });
    });

    group('Authentication', () {
      test('authenticate succeeds even with no-op implementation', () async {
        await provider.initialize();
        final auth = ProviderAuth(
          type: 'test',
          credentials: {'key': 'value'},
        );

        // Should complete without throwing
        await expectLater(
          provider.authenticate(auth),
          completes,
        );
      });
    });

    group('Configuration', () {
      test('custom config is respected', () {
        final customConfig = ProviderConfig(
          maxRetries: 5,
          enableCache: false,
          maxConcurrentRequests: 50,
        );

        final customProvider = NoOpProvider(customConfig);
        expect(customProvider.config, equals(customConfig));
      });
    });
  });
}
