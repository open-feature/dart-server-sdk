import 'dart:async';

import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk_experimental.dart'
    show createIsolatedOpenFeatureAPI;
import 'package:test/test.dart';

void main() {
  group('beta promotion lifecycle safety', () {
    test(
      'a missing terminal event times out and releases the provider',
      () async {
        final api = createIsolatedOpenFeatureAPI(
          lifecycleTimeout: const Duration(milliseconds: 25),
        );
        final provider = _SilentLifecycleProvider();

        await expectLater(
          api.setProviderAndWait(provider),
          throwsA(
            isA<OpenFeatureException>().having(
              (error) => error.message,
              'message',
              contains('did not complete'),
            ),
          ),
        );

        expect(provider.shutdownCalls, 1);
        await api.shutdown().timeout(const Duration(seconds: 1));
      },
    );

    test('the final lifecycle event at callback return wins', () async {
      final api = createIsolatedOpenFeatureAPI();
      addTearDown(api.shutdown);
      final provider = _BackgroundErrorProvider();

      await api.setProviderAndWait(provider);

      expect(api.getClient().providerStatus, ProviderStatus.ready);
    });

    test('a provider that throws before an event is shut down', () async {
      final api = createIsolatedOpenFeatureAPI();
      addTearDown(api.shutdown);
      final provider = _ThrowingLifecycleProvider();

      await expectLater(
        api.setProviderAndWait(provider),
        throwsA(isA<StateError>()),
      );

      expect(provider.shutdownCalls, 1);
      expect(api.getClient().providerStatus, ProviderStatus.notReady);
    });

    test('context-aware providers cannot be shared across bindings', () async {
      final api = createIsolatedOpenFeatureAPI();
      addTearDown(api.shutdown);
      final provider = _ContextProvider();

      await api.setProviderForDomainAndWait('one', provider);

      await expectLater(
        api.setProviderForDomainAndWait('two', provider),
        throwsA(
          isA<OpenFeatureException>().having(
            (error) => error.message,
            'message',
            contains('only one active binding'),
          ),
        ),
      );
    });

    test('one provider instance cannot be active in two APIs', () async {
      final firstApi = createIsolatedOpenFeatureAPI();
      final secondApi = createIsolatedOpenFeatureAPI();
      addTearDown(firstApi.shutdown);
      addTearDown(secondApi.shutdown);
      final provider = InMemoryProvider({'flag': true});

      await firstApi.setProviderAndWait(provider);
      await expectLater(
        secondApi.setProviderAndWait(provider),
        throwsA(isA<OpenFeatureException>()),
      );

      await firstApi.shutdown();
      await secondApi.setProviderAndWait(provider);
      expect(secondApi.getClient().getBooleanValue('flag', false), isTrue);
    });
  });

  group('beta promotion evaluation and context safety', () {
    test(
      'API and client hooks observe provider hook discovery failures',
      () async {
        final api = createIsolatedOpenFeatureAPI();
        addTearDown(api.shutdown);
        final apiHook = _RecordingHook();
        final clientHook = _RecordingHook();
        api.addHooks([apiHook]);
        await api.setProviderAndWait(_ThrowingHooksProvider());
        final client = api.getClient()..addHooks([clientHook]);

        final details = client.getBooleanDetails('flag', false);

        expect(details.value, isFalse);
        expect(details.reason, 'ERROR');
        expect(apiHook.errors, 1);
        expect(apiHook.finallyCalls, 1);
        expect(clientHook.errors, 1);
        expect(clientHook.finallyCalls, 1);
      },
    );

    test(
      'a partial global context failure rolls back successful providers',
      () async {
        final api = createIsolatedOpenFeatureAPI();
        addTearDown(api.shutdown);
        final successful = _ContextProvider();
        final failing = _ContextProvider(failTargetingKey: 'rejected');
        await api.setProviderAndWait(successful);
        await api.setProviderForDomainAndWait('checkout', failing);
        final rejected = EvaluationContext(targetingKey: 'rejected');

        await expectLater(
          api.setEvaluationContextAndWait(rejected),
          throwsA(isA<OpenFeatureException>()),
        );

        expect(successful.activeContext, same(EvaluationContext.empty));
        expect(successful.changes, [
          (EvaluationContext.empty, rejected),
          (rejected, EvaluationContext.empty),
        ]);
        successful.resolveBooleanValue('flag', false, EvaluationContext.empty);
        expect(successful.lastEvaluationContext, same(EvaluationContext.empty));
      },
    );
  });
}

class _DelegatingProvider implements FeatureProvider {
  final InMemoryProvider _delegate = InMemoryProvider({'flag': true});

  @override
  ProviderMetadata get metadata =>
      const ProviderMetadata(name: 'promotion-readiness-provider');

  @override
  ResolutionDetails<bool> resolveBooleanValue(
    String flagKey,
    bool defaultValue,
    EvaluationContext context,
  ) => _delegate.resolveBooleanValue(flagKey, defaultValue, context);

  @override
  ResolutionDetails<double> resolveDoubleValue(
    String flagKey,
    double defaultValue,
    EvaluationContext context,
  ) => _delegate.resolveDoubleValue(flagKey, defaultValue, context);

  @override
  ResolutionDetails<int> resolveIntegerValue(
    String flagKey,
    int defaultValue,
    EvaluationContext context,
  ) => _delegate.resolveIntegerValue(flagKey, defaultValue, context);

  @override
  ResolutionDetails<String> resolveStringValue(
    String flagKey,
    String defaultValue,
    EvaluationContext context,
  ) => _delegate.resolveStringValue(flagKey, defaultValue, context);

  @override
  ResolutionDetails<Map<String, Object?>> resolveStructureValue(
    String flagKey,
    Map<String, Object?> defaultValue,
    EvaluationContext context,
  ) => _delegate.resolveStructureValue(flagKey, defaultValue, context);
}

class _SilentLifecycleProvider extends _DelegatingProvider
    implements InitializableProvider, ProviderEventSource, ShutdownProvider {
  final StreamController<ProviderEvent> _events =
      StreamController<ProviderEvent>.broadcast(sync: true);
  int shutdownCalls = 0;

  @override
  Stream<ProviderEvent> get events => _events.stream;

  @override
  Future<void> initialize(EvaluationContext context, {String? domain}) async {}

  @override
  Future<void> shutdown() async {
    shutdownCalls++;
    await _events.close();
  }
}

final class _BackgroundErrorProvider extends _SilentLifecycleProvider {
  @override
  Future<void> initialize(EvaluationContext context, {String? domain}) async {
    _events.add(ProviderEvent(type: ProviderEventType.error));
    await Future<void>.delayed(Duration.zero);
    _events.add(ProviderEvent(type: ProviderEventType.ready));
  }
}

final class _ThrowingLifecycleProvider extends _SilentLifecycleProvider {
  @override
  Future<void> initialize(EvaluationContext context, {String? domain}) async {
    throw StateError('initialization failed');
  }
}

final class _ContextProvider extends _DelegatingProvider
    implements ContextReconciliationProvider, ProviderEventSource {
  _ContextProvider({this.failTargetingKey});

  final String? failTargetingKey;
  final StreamController<ProviderEvent> _events =
      StreamController<ProviderEvent>.broadcast(sync: true);
  final List<(EvaluationContext, EvaluationContext)> changes = [];
  EvaluationContext activeContext = EvaluationContext.empty;
  EvaluationContext? lastEvaluationContext;

  @override
  Stream<ProviderEvent> get events => _events.stream;

  @override
  Future<void> onContextChanged(
    EvaluationContext previousContext,
    EvaluationContext newContext,
  ) async {
    changes.add((previousContext, newContext));
    if (failTargetingKey != null &&
        newContext.targetingKey == failTargetingKey) {
      _events.add(ProviderEvent(type: ProviderEventType.error));
      return;
    }
    activeContext = newContext;
    _events.add(ProviderEvent(type: ProviderEventType.contextChanged));
  }

  @override
  ResolutionDetails<bool> resolveBooleanValue(
    String flagKey,
    bool defaultValue,
    EvaluationContext context,
  ) {
    lastEvaluationContext = context;
    return super.resolveBooleanValue(flagKey, defaultValue, context);
  }
}

final class _ThrowingHooksProvider extends _DelegatingProvider
    implements ProviderHooks {
  @override
  List<Hook> get hooks => throw StateError('hook discovery failed');
}

final class _RecordingHook extends HookAdapter {
  int errors = 0;
  int finallyCalls = 0;

  @override
  void error(HookContext context, Object error, HookHints hints) {
    errors++;
  }

  @override
  void finallyAfter(
    HookContext context,
    FlagEvaluationDetails<Object> details,
    HookHints hints,
  ) {
    finallyCalls++;
  }
}
