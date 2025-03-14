import 'package:test/test.dart';
import '../lib/client.dart';

void main() {
  group('ClientMetadata Tests', () {
    test('creates with required name only', () {
      final metadata = ClientMetadata(name: 'test-client');
      expect(metadata.name, equals('test-client'));
      expect(metadata.version, equals('1.0.0'));
      expect(metadata.attributes, isEmpty);
    });

    test('creates with all parameters', () {
      final metadata = ClientMetadata(
        name: 'test-client',
        version: '2.0.0',
        attributes: {'env': 'prod'},
      );
      expect(metadata.name, equals('test-client'));
      expect(metadata.version, equals('2.0.0'));
      expect(metadata.attributes['env'], equals('prod'));
    });
  });

  group('CacheEntry Tests', () {
    test('correctly identifies expired entries', () {
      final entry = CacheEntry<bool>(
        value: true,
        ttl: Duration(milliseconds: 1),
        contextHash: 'test-hash',
      );

      // Wait for expiration
      Future.delayed(Duration(milliseconds: 2), () {
        expect(entry.isExpired, isTrue);
      });
    });

    test('maintains value and context hash', () {
      const contextHash = 'test-hash';
      const value = true;

      final entry = CacheEntry<bool>(
        value: value,
        ttl: Duration(minutes: 5),
        contextHash: contextHash,
      );

      expect(entry.value, equals(value));
      expect(entry.contextHash, equals(contextHash));
    });
  });

  group('ClientMetrics Tests', () {
    test('calculates average response time', () {
      final metrics = ClientMetrics()
        ..responseTimes.addAll([
          Duration(milliseconds: 100),
          Duration(milliseconds: 200),
          Duration(milliseconds: 300),
        ]);

      expect(metrics.averageResponseTime, equals(Duration(milliseconds: 200)));
    });

    test('handles empty response times', () {
      final metrics = ClientMetrics();
      expect(metrics.averageResponseTime, equals(Duration.zero));
    });

    test('tracks error counts', () {
      final metrics = ClientMetrics();
      metrics.errorCounts['TestError'] = 1;
      metrics.errorCounts['TestError'] = 2;

      expect(metrics.errorCounts['TestError'], equals(2));
    });

    test('converts to JSON correctly', () {
      final metrics = ClientMetrics()
        ..flagEvaluations = 10
        ..cacheHits = 5
        ..cacheMisses = 5
        ..responseTimes.add(Duration(milliseconds: 100))
        ..errorCounts['TestError'] = 1;

      final json = metrics.toJson();

      expect(json['flagEvaluations'], equals(10));
      expect(json['cacheHits'], equals(5));
      expect(json['cacheMisses'], equals(5));
      expect(json['averageResponseTime'], equals(100));
      expect(json['errorCounts']['TestError'], equals(1));
    });
  });
}
