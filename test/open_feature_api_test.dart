import 'package:test/test.dart';
import '../lib/feature_provider.dart';
import '../lib/domain_manager.dart';

// Test-only API class - no singleton, no shared state
class TestOpenFeatureAPI {
  late FeatureProvider _provider;
  final DomainManager _domainManager = DomainManager();
  final List<TestHook> _hooks = [];
  TestEvaluationContext? _globalContext;

  TestOpenFeatureAPI() {
    _initializeDefaultProvider();
  }

  void _initializeDefaultProvider() {
    _provider = TestImmediateProvider();
  }

  Future<void> setProvider(FeatureProvider provider) async {
    if (provider.state == ProviderState.NOT_READY) {
      try {
        await provider.initialize();
      } catch (e) {
        // Provider stays in ERROR state
      }
    }
    _provider = provider;
  }

  FeatureProvider get provider => _provider;

  void setGlobalContext(TestEvaluationContext context) {
    _globalContext = context;
  }

  TestEvaluationContext? get globalContext => _globalContext;

  void addHooks(List<TestHook> hooks) {
    _hooks.addAll(hooks);
  }

  void bindClientToProvider(String clientId, String providerId) {
    _domainManager.bindClientToProvider(clientId, providerId);
  }

  Future<bool> evaluateBooleanFlag(String flagKey, String clientId) async {
    if (_provider.state != ProviderState.READY) {
      return false;
    }

    try {
      _runBeforeHooks(flagKey);
      final result = await _provider.getBooleanFlag(flagKey, false);
      _runAfterHooks(flagKey, result.value);
      return result.value;
    } catch (e) {
      return false;
    }
  }

  void _runBeforeHooks(String flagKey) {
    for (var hook in _hooks) {
      hook.beforeEvaluation(flagKey, null);
    }
  }

  void _runAfterHooks(String flagKey, dynamic result) {
    for (var hook in _hooks) {
      hook.afterEvaluation(flagKey, result, null);
    }
  }

  void dispose() {
    _domainManager.dispose();
  }
}

class TestEvaluationContext {
  final Map<String, dynamic> attributes;
  TestEvaluationContext(this.attributes);

  TestEvaluationContext merge(TestEvaluationContext other) {
    return TestEvaluationContext({...attributes, ...other.attributes});
  }
}

class TestHook {
  final List<String> calls = [];

  void beforeEvaluation(String flagKey, Map<String, dynamic>? context) {
    calls.add('before:$flagKey');
  }

  void afterEvaluation(String flagKey, result, Map<String, dynamic>? context) {
    calls.add('after:$flagKey:$result');
  }
}

class TestImmediateProvider implements FeatureProvider {
  @override
  String get name => 'InMemoryProvider';

  @override
  ProviderState get state => ProviderState.READY;

  @override
  ProviderConfig get config => ProviderConfig();

  @override
  ProviderMetadata get metadata => ProviderMetadata(name: 'InMemoryProvider');

  @override
  Future<void> initialize([Map<String, dynamic>? config]) async {}

  @override
  Future<void> connect() async {}

  @override
  Future<void> shutdown() async {}

  @override
  Future<FlagEvaluationResult<bool>> getBooleanFlag(
    String flagKey,
    bool defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    return FlagEvaluationResult.error(
      flagKey,
      defaultValue,
      ErrorCode.FLAG_NOT_FOUND,
      'Flag not found',
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
        'Provider not ready',
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

void main() {
  group('TestOpenFeatureAPI', () {
    late TestOpenFeatureAPI api;

    setUp(() {
      api = TestOpenFeatureAPI(); // Fresh instance every test
    });

    tearDown(() {
      api.dispose();
    });

    test('sets and gets provider', () async {
      final provider = TestProvider({'test': true});
      await api.setProvider(provider);
      expect(api.provider, equals(provider));
      expect(api.provider.state, equals(ProviderState.READY));
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

      await api.setProvider(provider);
      expect(api.provider.state, equals(ProviderState.ERROR));

      api.bindClientToProvider('test-client', 'TestProvider');
      final result = await api.evaluateBooleanFlag('test-flag', 'test-client');

      expect(result, isFalse);
    });

    test('initializes default provider', () {
      expect(api.provider, isNotNull);
      expect(api.provider.name, equals('InMemoryProvider'));
      expect(api.provider.state, equals(ProviderState.READY));
    });

    test('sets and gets global context', () {
      final context = TestEvaluationContext({'key': 'value'});
      api.setGlobalContext(context);
      expect(api.globalContext?.attributes['key'], equals('value'));
    });

    test('merges evaluation contexts', () {
      final globalContext = TestEvaluationContext({'global': 'value'});
      final localContext = TestEvaluationContext({'local': 'value'});

      final merged = globalContext.merge(localContext);
      expect(merged.attributes['global'], equals('value'));
      expect(merged.attributes['local'], equals('value'));
    });
  });
}
