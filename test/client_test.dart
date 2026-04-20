import 'dart:async';
import 'package:test/test.dart';
import '../lib/client.dart';
import '../lib/feature_provider.dart';
import '../lib/evaluation_context.dart';
import '../lib/hooks.dart';
import '../lib/open_feature_event.dart';
import '../lib/transaction_context.dart';

class MockProvider implements FeatureProvider {
  final Map<String, dynamic> flags;
  ProviderState _state = ProviderState.READY;
  int booleanCalls = 0;

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
  Future<void> track(
    String trackingEventName, {
    Map<String, dynamic>? evaluationContext,
    TrackingEventDetails? trackingDetails,
  }) async {}

  @override
  Future<FlagEvaluationResult<bool>> getBooleanFlag(
    String flagKey,
    bool defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    booleanCalls++;
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

class TrackingMockProvider extends MockProvider {
  Map<String, dynamic>? lastTrackingContext;

  TrackingMockProvider(super.flags);

  @override
  Future<void> track(
    String trackingEventName, {
    Map<String, dynamic>? evaluationContext,
    TrackingEventDetails? trackingDetails,
  }) async {
    lastTrackingContext = evaluationContext;
  }
}

class ContextCapturingProvider extends MockProvider {
  Map<String, dynamic>? lastEvaluationContext;

  ContextCapturingProvider(super.flags);

  @override
  Future<FlagEvaluationResult<bool>> getBooleanFlag(
    String flagKey,
    bool defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    lastEvaluationContext = context == null ? null : {...context};
    return super.getBooleanFlag(flagKey, defaultValue, context: context);
  }
}

class ThrowingProvider extends MockProvider {
  final ProviderException exception;

  ThrowingProvider(super.flags, this.exception);

  @override
  Future<FlagEvaluationResult<bool>> getBooleanFlag(
    String flagKey,
    bool defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    throw exception;
  }
}

class LifecycleHook extends BaseHook {
  final List<String> calls = [];
  EvaluationDetails? finalDetails;
  Exception? lastError;
  final Map<String, dynamic>? beforeUpdates;

  LifecycleHook({this.beforeUpdates})
    : super(metadata: HookMetadata(name: 'LifecycleHook'));

  @override
  Future<Map<String, dynamic>?> before(HookContext context) async {
    calls.add('before');
    return beforeUpdates;
  }

  @override
  Future<void> after(HookContext context) async {
    calls.add('after');
  }

  @override
  Future<void> error(HookContext context) async {
    calls.add('error');
    lastError = context.error;
  }

  @override
  Future<void> finally_(
    HookContext context,
    EvaluationDetails? evaluationDetails, [
    HookHints? hints,
  ]) async {
    calls.add('finally');
    finalDetails = evaluationDetails;
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

    test('get details evaluates provider only once', () async {
      final details = await client.getBooleanDetails('test-flag');

      expect(details.value, isTrue);
      expect(provider.booleanCalls, equals(1));
    });

    test('tracking merges api, transaction, client, and invocation contexts', () async {
      final trackingProvider = TrackingMockProvider({'test-flag': true});
      final transactionManager = TransactionContextManager();
      client = FeatureClient(
        metadata: ClientMetadata(name: 'test-client'),
        hookManager: hookManager,
        apiContext: const EvaluationContext(
          attributes: {'global': 'value'},
        ),
        defaultContext: const EvaluationContext(
          attributes: {'client': 'value'},
        ),
        provider: trackingProvider,
        transactionManager: transactionManager,
      );

      await transactionManager.withContext('tx', {'requestId': '123'}, () async {
        await client.track(
          'checkout',
          context: const EvaluationContext(attributes: {'userId': 'u-1'}),
        );
      });

      expect(trackingProvider.lastTrackingContext?['global'], equals('value'));
      expect(trackingProvider.lastTrackingContext?['requestId'], equals('123'));
      expect(trackingProvider.lastTrackingContext?['client'], equals('value'));
      expect(trackingProvider.lastTrackingContext?['userId'], equals('u-1'));
    });

    test('client handlers receive forwarded events', () async {
      final controller = StreamController<OpenFeatureEvent>.broadcast();
      final received = <OpenFeatureEvent>[];

      client = FeatureClient(
        metadata: ClientMetadata(name: 'test-client'),
        hookManager: hookManager,
        defaultContext: context,
        provider: provider,
        eventStream: controller.stream,
      );

      final sub = client.addHandler(received.add);
      controller.add(
        OpenFeatureEvent(
          OpenFeatureEventType.PROVIDER_READY,
          'ready',
          providerMetadata: provider.metadata,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 10));
      expect(received, hasLength(1));

      await sub.cancel();
      await client.dispose();
      await controller.close();
    });

    test('provider error result triggers error hooks instead of after hooks', () async {
      final lifecycleHook = LifecycleHook();
      hookManager.addHook(lifecycleHook);

      final result = await client.getBooleanFlag(
        'missing-flag',
        defaultValue: false,
      );

      expect(result, isFalse);
      expect(lifecycleHook.calls, equals(['before', 'error', 'finally']));
      expect(lifecycleHook.finalDetails?.value, isFalse);
      expect(lifecycleHook.lastError, isA<ProviderException>());
      expect(
        (lifecycleHook.lastError as ProviderException).code,
        equals(ErrorCode.FLAG_NOT_FOUND),
      );
    });

    test('preserves ProviderException error codes from thrown provider errors', () async {
      final throwingProvider = ThrowingProvider(
        {'test-flag': true},
        const ProviderException(
          'provider unavailable',
          code: ErrorCode.PROVIDER_NOT_READY,
        ),
      );

      client = FeatureClient(
        metadata: ClientMetadata(name: 'test-client'),
        hookManager: hookManager,
        defaultContext: context,
        provider: throwingProvider,
      );

      final details = await client.getBooleanDetails(
        'test-flag',
        defaultValue: false,
      );

      expect(details.value, isFalse);
      expect(details.errorCode, equals(ErrorCode.PROVIDER_NOT_READY));
      expect(details.errorMessage, equals('provider unavailable'));
    });

    test('before hook context updates are merged into provider evaluation context', () async {
      final capturingProvider = ContextCapturingProvider({'test-flag': true});
      final transactionManager = TransactionContextManager();
      final lifecycleHook = LifecycleHook(
        beforeUpdates: {'hook': 'value', 'userId': 'hook-user'},
      );
      hookManager.addHook(lifecycleHook);

      client = FeatureClient(
        metadata: ClientMetadata(name: 'test-client'),
        hookManager: hookManager,
        apiContext: const EvaluationContext(
          attributes: {'global': 'value'},
        ),
        defaultContext: const EvaluationContext(
          attributes: {'client': 'value'},
        ),
        provider: capturingProvider,
        transactionManager: transactionManager,
      );

      await transactionManager.withContext('tx', {'requestId': '123'}, () async {
        await client.getBooleanFlag(
          'test-flag',
          context: const EvaluationContext(attributes: {'userId': 'invocation'}),
        );
      });

      expect(capturingProvider.lastEvaluationContext?['global'], equals('value'));
      expect(
        capturingProvider.lastEvaluationContext?['requestId'],
        equals('123'),
      );
      expect(capturingProvider.lastEvaluationContext?['client'], equals('value'));
      expect(capturingProvider.lastEvaluationContext?['hook'], equals('value'));
      expect(
        capturingProvider.lastEvaluationContext?['userId'],
        equals('hook-user'),
      );
    });
  });
}
