import 'package:test/test.dart';
import '../lib/client.dart';
import '../lib/feature_provider.dart';
import '../lib/evaluation_context.dart';
import '../lib/hooks.dart';

class MockProvider implements FeatureProvider {
  final Map<String, dynamic> flags;
  ProviderState _state = ProviderState.READY;

  MockProvider(this.flags);

  @override
  String get name => 'MockProvider';

  @override
  ProviderState get state => _state;

  @override
  ProviderConfig get config => ProviderConfig();

  @override
  ProviderMetadata get metadata => ProviderMetadata(name: 'MockProvider');

  @override
  Future<void> initialize([Map<String, dynamic>? config]) async {
    _state = ProviderState.READY;
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> shutdown() async {
    _state = ProviderState.SHUTDOWN;
  }

  @override
  Future<FlagEvaluationResult<bool>> getBooleanFlag(
    String flagKey,
    bool defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    if (!flags.containsKey(flagKey)) {
      return FlagEvaluationResult.error(
        flagKey,
        defaultValue,
        ErrorCode.FLAG_NOT_FOUND,
        'Flag not found',
        evaluatorId: name,
      );
    }

    final value = flags[flagKey];
    if (value is! bool) {
      return FlagEvaluationResult.error(
        flagKey,
        defaultValue,
        ErrorCode.TYPE_MISMATCH,
        'Type mismatch',
        evaluatorId: name,
      );
    }

    return FlagEvaluationResult(
      flagKey: flagKey,
      value: value,
      reason: 'STATIC',
      evaluatedAt: DateTime.now(),
      evaluatorId: name,
    );
  }

  @override
  Future<FlagEvaluationResult<String>> getStringFlag(
    String flagKey,
    String defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    if (!flags.containsKey(flagKey)) {
      return FlagEvaluationResult.error(
        flagKey,
        defaultValue,
        ErrorCode.FLAG_NOT_FOUND,
        'Flag not found',
        evaluatorId: name,
      );
    }

    final value = flags[flagKey];
    if (value is! String) {
      return FlagEvaluationResult.error(
        flagKey,
        defaultValue,
        ErrorCode.TYPE_MISMATCH,
        'Type mismatch',
        evaluatorId: name,
      );
    }

    return FlagEvaluationResult(
      flagKey: flagKey,
      value: value,
      reason: 'STATIC',
      evaluatedAt: DateTime.now(),
      evaluatorId: name,
    );
  }

  @override
  Future<FlagEvaluationResult<int>> getIntegerFlag(
    String flagKey,
    int defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<FlagEvaluationResult<double>> getDoubleFlag(
    String flagKey,
    double defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<FlagEvaluationResult<Map<String, dynamic>>> getObjectFlag(
    String flagKey,
    Map<String, dynamic> defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    throw UnimplementedError();
  }
}

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

  group('ClientMetrics Tests', () {
    test('calculates average response time', () {
      final metrics =
          ClientMetrics()
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
        ..responseTimes.add(Duration(milliseconds: 100))
        ..errorCounts['TestError'] = 1;


      final json = metrics.toJson();

      expect(json['flagEvaluations'], equals(10));
      expect(json['averageResponseTime'], equals(100));
      expect(json['errorCounts']['TestError'], equals(1));
    });
  });

  group('FeatureClient Tests', () {
    late FeatureClient client;
    late MockProvider provider;
    late HookManager hookManager;
    late EvaluationContext context;

    setUp(() {
      provider = MockProvider({'test-flag': true, 'string-flag': 'hello'});
      hookManager = HookManager();
      context = EvaluationContext(attributes: {});

      client = FeatureClient(
        metadata: ClientMetadata(name: 'test-client'),
        hookManager: hookManager,
        defaultContext: context,
        provider: provider,
      );
    });

    test('evaluates boolean flag successfully', () async {
      final result = await client.getBooleanFlag('test-flag');
      expect(result, isTrue);
    });

    test('returns default for missing flag', () async {
      final result = await client.getBooleanFlag(
        'missing-flag',
        defaultValue: false,
      );
      expect(result, isFalse);
    });

    test('handles type mismatch gracefully', () async {
      final result = await client.getBooleanFlag(
        'string-flag',
        defaultValue: false,
      );
      expect(result, isFalse); // default value returned
    });

    test('tracks metrics correctly', () async {
      await client.getBooleanFlag('test-flag');
      await client.getBooleanFlag('missing-flag');

      final metrics = client.getMetrics();
      expect(metrics.flagEvaluations, equals(2));
      expect(metrics.errorCounts['FLAG_NOT_FOUND'], equals(1));
    });


    test('evaluates string flags', () async {
      final result = await client.getStringFlag('string-flag');
      expect(result, equals('hello'));
    });

    test('provider metadata is accessible through client', () {
      expect(client.provider.metadata.name, equals('MockProvider'));

    });
  });
}
