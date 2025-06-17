import 'dart:async';
import 'package:test/test.dart';
import '../lib/open_feature_api.dart';
import '../lib/feature_provider.dart';
import 'helpers/open_feature_api_test_helpers.dart';

class TestProvider implements FeatureProvider {
  bool booleanValue = true;
  ProviderState _state = ProviderState.NOT_READY;

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

    return FlagEvaluationResult(
      flagKey: flagKey,
      value: booleanValue,
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
    throw UnimplementedError();
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

class TestHook implements OpenFeatureHook {
  final List<String> callLog = [];

  @override
  void beforeEvaluation(String flagKey, Map<String, dynamic>? context) {
    callLog.add('before:$flagKey');
  }

  @override
  void afterEvaluation(
    String flagKey,
    dynamic result,
    Map<String, dynamic>? context,
  ) {
    callLog.add('after:$flagKey:$result');
  }
}

void main() {
  late OpenFeatureAPI api;
  late TestProvider provider;
  late TestHook hook;

  setUp(() {
    OpenFeatureAPITestHelpers.reset();
    api = OpenFeatureAPI();
    provider = TestProvider();
    hook = TestHook();
  });

  group('OpenFeatureAPI', () {
    test('singleton instance', () {
      final instance1 = OpenFeatureAPI();
      final instance2 = OpenFeatureAPI();
      expect(identical(instance1, instance2), isTrue);
    });

    test('sets and gets provider', () async {
      await api.setProvider(provider);
      expect(api.provider, equals(provider));
      expect(provider.state, equals(ProviderState.READY));
    });

    test('sets and gets global context', () async {
      final context = OpenFeatureEvaluationContext({'key': 'value'});
      await api.setProvider(provider);
      api.setGlobalContext(context);
      expect(api.globalContext?.attributes['key'], equals('value'));
    });

    test('merges evaluation contexts', () {
      final context1 = OpenFeatureEvaluationContext({'key1': 'value1'});
      final context2 = OpenFeatureEvaluationContext({'key2': 'value2'});
      final merged = context1.merge(context2);

      expect(merged.attributes['key1'], equals('value1'));
      expect(merged.attributes['key2'], equals('value2'));
    });

    test('evaluates boolean flag with hooks', () async {
      await api.setProvider(provider);
      api.addHooks([hook]);
      api.bindClientToProvider('test-client', provider.name);

      final result = await api.evaluateBooleanFlag('test-flag', 'test-client');

      expect(result, isTrue);
      expect(hook.callLog, contains('before:test-flag'));
      expect(hook.callLog, contains('after:test-flag:true'));
    });

    test('handles provider not ready gracefully', () async {
      // Don't initialize provider, keep it in NOT_READY state
      provider._state = ProviderState.ERROR; // Force error state
      await api.setProvider(provider);
      api.bindClientToProvider('test-client', provider.name);

      final result = await api.evaluateBooleanFlag('test-flag', 'test-client');

      // Should return default value when provider has error
      expect(result, isFalse);
    });

    test('binds client to provider', () async {
      await api.setProvider(provider);

      final eventCompleter = Completer<OpenFeatureEvent>();
      final subscription = api.events.listen((event) {
        if (event.type == OpenFeatureEventType.domainUpdated) {
          eventCompleter.complete(event);
        }
      });

      api.bindClientToProvider('client1', 'provider1');

      final event = await eventCompleter.future;
      expect(event.message, contains('client1'));
      expect(event.message, contains('provider1'));

      await subscription.cancel();
    });

    test('emits events on provider change', () async {
      final eventCompleter = Completer<OpenFeatureEvent>();
      final subscription = api.events.listen((event) {
        if (event.type == OpenFeatureEventType.providerChanged) {
          eventCompleter.complete(event);
        }
      });

      await api.setProvider(provider);

      final event = await eventCompleter.future;
      expect(event.message, contains(provider.name));

      await subscription.cancel();
    });

    test('emits error events for flag evaluation issues', () async {
      provider.booleanValue = false;
      provider._state = ProviderState.ERROR;
      await api.setProvider(provider);
      api.bindClientToProvider('test-client', provider.name);

      final errorEvents = <OpenFeatureEvent>[];
      final subscription = api.events.listen((event) {
        if (event.type == OpenFeatureEventType.error) {
          errorEvents.add(event);
        }
      });

      await api.evaluateBooleanFlag('error-flag', 'test-client');

      // Wait for events to be processed
      await Future.delayed(Duration(milliseconds: 10));

      await subscription.cancel();
      expect(errorEvents.isNotEmpty, isTrue);
    });

    test('handles evaluation errors gracefully', () async {
      await api.setProvider(provider);
      provider.booleanValue = false;
      api.bindClientToProvider('test-client', provider.name);

      final result = await api.evaluateBooleanFlag('error-flag', 'test-client');
      expect(result, isFalse);
    });

    test('streams provider updates', () async {
      final completer = Completer<FeatureProvider>();
      final subscription = api.providerUpdates.listen(
        (p) => completer.complete(p),
      );

      await api.setProvider(provider);

      final emittedProvider = await completer.future;
      expect(emittedProvider, equals(provider));

      await subscription.cancel();
    });

    test('initializes default provider', () {
      // The API should have a default InMemoryProvider that's ready
      expect(api.provider, isA<InMemoryProvider>());
      expect(api.provider.state, equals(ProviderState.READY));
    });

    test('provider metadata is accessible', () async {
      await api.setProvider(provider);
      expect(api.provider.metadata.name, equals('TestProvider'));
    });
  });
}
