import 'dart:async';
import 'package:test/test.dart';
import '../lib/open_feature_api.dart';
import '../lib/feature_provider.dart';
import 'helpers/open_feature_api_test_helpers.dart';

class TestProvider implements FeatureProvider {
  bool booleanValue = true;

  @override
  String get name => 'TestProvider';

  @override
  ProviderState get state => ProviderState.READY;

  @override
  ProviderConfig get config => ProviderConfig();

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
    return FlagEvaluationResult(
      flagKey: flagKey,
      value: booleanValue,
      evaluatedAt: DateTime.now(),
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
      String flagKey, dynamic result, Map<String, dynamic>? context) {
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

    test('sets and gets provider', () {
      api.setProvider(provider);
      expect(api.provider, equals(provider));
    });

    test('sets and gets global context', () {
      final context = OpenFeatureEvaluationContext({'key': 'value'});
      api.setProvider(provider);
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
      api.setProvider(provider);
      api.addHooks([hook]);
      api.bindClientToProvider('test-client', provider.name);

      final result = await api.evaluateBooleanFlag('test-flag', 'test-client');

      expect(result, isTrue);
      expect(hook.callLog, contains('before:test-flag'));
      expect(hook.callLog, contains('after:test-flag:true'));
    });

    test('binds client to provider', () async {
      api.setProvider(provider);

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

      api.setProvider(provider);

      final event = await eventCompleter.future;
      expect(event.message, contains(provider.name));

      await subscription.cancel();
    });

    test('handles evaluation errors gracefully', () async {
      api.setProvider(provider);
      provider.booleanValue = false;
      api.bindClientToProvider('test-client', provider.name);

      final result = await api.evaluateBooleanFlag('error-flag', 'test-client');
      expect(result, isFalse);
    });

    test('streams provider updates', () async {
      final completer = Completer<FeatureProvider>();
      final subscription =
          api.providerUpdates.listen((p) => completer.complete(p));

      api.setProvider(provider);

      final emittedProvider = await completer.future;
      expect(emittedProvider, equals(provider));

      await subscription.cancel();
    });
  });
}
