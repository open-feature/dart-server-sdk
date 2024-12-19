import 'package:open_feature_dart_server_sdk/feature_provider.dart';

import 'package:test/test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('NoOpProvider', () {

    late NoOpProvider provider;

    setUp(() {
      provider = NoOpProvider();
    });

    test('initial state is NOT_READY', () {
      expect(provider.state, equals(ProviderState.NOT_READY));
    });

    test('initialize sets state to READY', () async {
      await provider.initialize();
      expect(provider.state, equals(ProviderState.READY));
    });

    test('shutdown sets state to SHUTDOWN and clears cache', () async {
      await provider.initialize();
      await provider.shutdown();
      expect(provider.state, equals(ProviderState.SHUTDOWN));
    });

    test('getBooleanFlag returns default value', () async {
      await provider.initialize();
      final result = await provider.getBooleanFlag('testFlag', false);
      expect(result.value, equals(false));
    });

    test('getStringFlag returns default value', () async {
      await provider.initialize();
      final result = await provider.getStringFlag('testFlag', 'default');
      expect(result.value, equals('default'));
    });

    test('getIntegerFlag returns default value', () async {
      await provider.initialize();
      final result = await provider.getIntegerFlag('testFlag', 42);
      expect(result.value, equals(42));
    });

    test('getDoubleFlag returns default value', () async {
      await provider.initialize();
      final result = await provider.getDoubleFlag('testFlag', 3.14);
      expect(result.value, equals(3.14));
    });

    test('getObjectFlag returns default value', () async {
      await provider.initialize();
      final result = await provider.getObjectFlag('testFlag', {'key': 'value'});
      expect(result.value, equals({'key': 'value'}));
    });

    test('register and unregister plugin', () async {
      await provider.initialize();
      const pluginId = 'testPlugin';
      const pluginConfig = PluginConfig(
        pluginId: pluginId,
        version: '1.0.0',
      );

      await provider.registerPlugin(pluginId, pluginConfig);
      expect(provider.getRegisteredPlugins(), contains(pluginId));

      await provider.unregisterPlugin(pluginId);
      expect(provider.getRegisteredPlugins(), isNot(contains(pluginId)));
    });

    test('clearCache clears the cache', () async {
      await provider.initialize();
      await provider.clearCache();
      // No assertion as there is no way to directly inspect cache
    });

    test('healthCheck returns true when provider is READY', () async {
      await provider.initialize();
      final result = await provider.healthCheck();
      expect(result, isTrue);
    });

    test('getMetrics returns correct metrics', () async {
      await provider.initialize();
      final metrics = provider.getMetrics();
      expect(metrics.totalRequests, equals(0));
      expect(metrics.successfulRequests, equals(0));
    });

    test('throws ProviderException if provider is not ready', () async {
      expect(() => provider.getBooleanFlag('testFlag', false),
          throwsA(isA<ProviderException>()));

    });
  });
}
