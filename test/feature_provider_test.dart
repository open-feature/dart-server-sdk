import 'package:test/test.dart';
import '../lib/feature_provider.dart';

void main() {
  group('ProviderConfig', () {
    test('creates with default values', () {
      final config = ProviderConfig();
      expect(config.connectionTimeout, equals(Duration(seconds: 30)));
      expect(config.maxRetries, equals(3));
      expect(config.enableCache, isTrue);
    });
  });

  group('InMemoryProvider', () {
    late InMemoryProvider provider;
    final testFlags = {
      'bool-flag': true,
      'string-flag': 'test',
      'int-flag': 42,
      'double-flag': 3.14,
      'object-flag': {'key': 'value'}
    };

    setUp(() {
      provider = InMemoryProvider(testFlags);
      provider.initialize();
    });

    test('lifecycle state management', () async {
      expect(provider.state, equals(ProviderState.READY));
      await provider.shutdown();
      expect(provider.state, equals(ProviderState.SHUTDOWN));
    });

    test('throws when not ready', () async {
      await provider.shutdown();
      expect(
        () => provider.getBooleanFlag('test', false),
        throwsA(isA<ProviderException>()),
      );
    });

    group('flag evaluation', () {
      test('evaluates boolean flag', () async {
        final result = await provider.getBooleanFlag('bool-flag', false);
        expect(result.value, isTrue);
        expect(result.flagKey, equals('bool-flag'));
        expect(result.evaluatorId, equals('InMemoryProvider'));
      });

      test('returns default for missing boolean flag', () async {
        final result = await provider.getBooleanFlag('missing-flag', true);
        expect(result.value, isTrue);
      });

      test('evaluates string flag', () async {
        final result = await provider.getStringFlag('string-flag', '');
        expect(result.value, equals('test'));
      });

      test('evaluates integer flag', () async {
        final result = await provider.getIntegerFlag('int-flag', 0);
        expect(result.value, equals(42));
      });

      test('evaluates double flag', () async {
        final result = await provider.getDoubleFlag('double-flag', 0.0);
        expect(result.value, equals(3.14));
      });

      test('evaluates object flag', () async {
        final result = await provider.getObjectFlag('object-flag', {});
        expect(result.value, equals({'key': 'value'}));
      });
    });
  });
}
