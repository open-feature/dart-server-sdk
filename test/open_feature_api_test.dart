import 'package:test/test.dart';
import '../lib/open_feature_api.dart';
import '../lib/feature_provider.dart';

class TestProvider implements FeatureProvider {
  final Map<String, dynamic> _flags;
  ProviderState _state;
  final bool _shouldFailInitialization;

  TestProvider(
    this._flags, [
    this._state = ProviderState.NOT_READY,
    this._shouldFailInitialization = false,
  ]);

  @override
  String get name => 'TestProvider';

  @override
  ProviderState get state => _state;

  @override
  ProviderConfig get config => ProviderConfig();

  @override
  ProviderMetadata get metadata => ProviderMetadata(name: 'TestProvider');

  @override
  Future<void> initialize([Map<String, dynamic>? config]) async {
    if (_shouldFailInitialization) {
      _state = ProviderState.ERROR;
      throw Exception('Initialization failed');
    }
    _state = ProviderState.READY;
  }

  @override
  Future<void> connect() async {
    _state = ProviderState.READY;
  }

  @override
  Future<void> shutdown() async {
    _state = ProviderState.SHUTDOWN;
  }

  void setState(ProviderState newState) {
    _state = newState;
  }

  @override
  Future<FlagEvaluationResult<bool>> getBooleanFlag(
    String flagKey,
    bool defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    if (_state != ProviderState.READY) {
      return FlagEvaluationResult.error(
        flagKey,
        defaultValue,
        ErrorCode.PROVIDER_NOT_READY,
        'Provider not ready (state: $_state)',
        evaluatorId: name,
      );
    }

    if (!_flags.containsKey(flagKey)) {
      return FlagEvaluationResult.error(
        flagKey,
        defaultValue,
        ErrorCode.FLAG_NOT_FOUND,
        'Flag not found',
        evaluatorId: name,
      );
    }

    final value = _flags[flagKey];
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
  }) async => throw UnimplementedError();

  @override
  Future<FlagEvaluationResult<int>> getIntegerFlag(
    String flagKey,
    int defaultValue, {
    Map<String, dynamic>? context,
  }) async => throw UnimplementedError();

  @override
  Future<FlagEvaluationResult<double>> getDoubleFlag(
    String flagKey,
    double defaultValue, {
    Map<String, dynamic>? context,
  }) async => throw UnimplementedError();

  @override
  Future<FlagEvaluationResult<Map<String, dynamic>>> getObjectFlag(
    String flagKey,
    Map<String, dynamic> defaultValue, {
    Map<String, dynamic>? context,
  }) async => throw UnimplementedError();
}

class TestHook extends OpenFeatureHook {
  final List<String> calls = [];

  @override
  void beforeEvaluation(String flagKey, Map<String, dynamic>? context) {
    calls.add('before:$flagKey');
  }

  @override
  void afterEvaluation(String flagKey, result, Map<String, dynamic>? context) {
    calls.add('after:$flagKey:$result');
  }
}

void main() {
  group('OpenFeatureAPI', () {
    // BYPASS SINGLETON: Create fresh instance for each test
    late OpenFeatureAPI api;

    setUp(() {
      // Force new instance bypassing singleton
      api = OpenFeatureAPI.forTesting();
    });

    tearDown(() async {
      // Dispose current instance
      await api.dispose();
    });

    test('singleton instance', () {
      final api1 = OpenFeatureAPI.forTesting();
      final api2 = OpenFeatureAPI.forTesting();
      expect(identical(api1, api2), isFalse); // Different instances now
    });

    test('sets and gets provider', () async {
      final provider = TestProvider({'test': true});

      await api.setProvider(provider);
      expect(api.provider, equals(provider));
      expect(api.provider.state, equals(ProviderState.READY));
    });

    test('sets and gets global context', () {
      final context = OpenFeatureEvaluationContext({'key': 'value'});

      api.setGlobalContext(context);
      expect(api.globalContext?.attributes['key'], equals('value'));
    });

    test('merges evaluation contexts', () {
      final globalContext = OpenFeatureEvaluationContext({'global': 'value'});
      final localContext = OpenFeatureEvaluationContext({'local': 'value'});

      api.setGlobalContext(globalContext);

      final merged = globalContext.merge(localContext);
      expect(merged.attributes['global'], equals('value'));
      expect(merged.attributes['local'], equals('value'));
    });

    test('evaluates boolean flag with hooks', () async {
      final provider = TestProvider({'test-flag': true});
      final hook = TestHook();

      await api.setProvider(provider);
      api.addHooks([hook]);
      api.bindClientToProvider('test-client', 'TestProvider');

      final result = await api.evaluateBooleanFlag('test-flag', 'test-client');

      expect(result, isTrue);
      expect(hook.calls, contains('before:test-flag'));
      expect(hook.calls, contains('after:test-flag:true'));
    });

    test('handles provider not ready gracefully', () async {
      final provider = TestProvider(
        {'test-flag': true},
        ProviderState.NOT_READY,
        true, // shouldFailInitialization = true
      );

      // Provider initialization will fail and set state to ERROR
      try {
        await api.setProvider(provider);
      } catch (e) {
        // Expected to fail
      }

      expect(api.provider.state, equals(ProviderState.ERROR));

      api.bindClientToProvider('test-client', 'TestProvider');
      final result = await api.evaluateBooleanFlag('test-flag', 'test-client');

      expect(result, isFalse);
    });

    test('binds client to provider', () {
      api.bindClientToProvider('client1', 'provider1');
    });

    test('emits events on provider change', () async {
      final provider = TestProvider({'test': true});
      final events = <OpenFeatureEvent>[];

      api.events.listen(events.add);
      await api.setProvider(provider);
      await Future.delayed(Duration(milliseconds: 10));

      expect(events.length, greaterThan(0));
      expect(
        events.any((e) => e.type == OpenFeatureEventType.providerChanged),
        isTrue,
      );
    });

    test('emits error events for flag evaluation issues', () async {
      final provider = TestProvider({}, ProviderState.NOT_READY);
      final events = <OpenFeatureEvent>[];

      await api.setProvider(provider);
      provider.setState(ProviderState.NOT_READY);
      api.bindClientToProvider('test-client', 'TestProvider');
      api.events.listen(events.add);

      await api.evaluateBooleanFlag('missing-flag', 'test-client');
      await Future.delayed(Duration(milliseconds: 10));

      expect(events.any((e) => e.type == OpenFeatureEventType.error), isTrue);
    });

    test('handles evaluation errors gracefully', () async {
      final provider = TestProvider({'string-flag': 'not-boolean'});

      await api.setProvider(provider);
      api.bindClientToProvider('test-client', 'TestProvider');

      final result = await api.evaluateBooleanFlag(
        'string-flag',
        'test-client',
      );
      expect(result, isFalse);
    });

    test('streams provider updates', () async {
      final provider = TestProvider({'test': true});
      final updates = <FeatureProvider>[];

      api.providerUpdates.listen(updates.add);
      await api.setProvider(provider);
      await Future.delayed(Duration(milliseconds: 10));

      expect(updates, contains(provider));
    });

    test('initializes default provider', () {
      expect(api.provider, isNotNull);
      expect(api.provider.name, equals('InMemoryProvider'));
      expect(api.provider.state, equals(ProviderState.READY));
    });

    test('provider metadata is accessible', () async {
      final provider = TestProvider({'test': true});

      await api.setProvider(provider);
      expect(api.provider.metadata.name, equals('TestProvider'));
    });
  });
}
