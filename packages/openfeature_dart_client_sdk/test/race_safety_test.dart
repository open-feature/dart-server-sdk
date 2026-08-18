import 'dart:async';

import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk_experimental.dart'
    show createIsolatedOpenFeatureAPI;
import 'package:test/test.dart';

void main() {
  late OpenFeatureAPI api;

  setUp(() {
    api = createIsolatedOpenFeatureAPI();
  });

  tearDown(() => api.shutdown());

  test('provider replacement waits for active reconciliation', () async {
    final original = _GatedContextProvider(name: 'original');
    final replacement = _GatedContextProvider(name: 'replacement');
    await api.setProviderAndWait(original);
    final context = EvaluationContext(targetingKey: 'user-a');

    final contextChange = api.setEvaluationContextAndWait(context);
    await original.waitForChange(1);
    final replacementRequest = api.setProviderAndWait(replacement);

    expect(api.getClient().providerMetadata.name, 'original');
    expect(replacement.changes, isEmpty);
    original.allowChange(0);
    await Future.wait([contextChange, replacementRequest]);

    final client = api.getClient();
    expect(client.providerMetadata.name, 'replacement');
    expect(client.getBooleanValue('flag', false), isTrue);
    expect(replacement.lastEvaluationContext, same(context));
    expect(original.shutdownCalls, 1);

    original.emit(ProviderEventType.contextChanged);
    expect(client.providerStatus, ProviderStatus.ready);
  });

  test(
    'shutdown waits for reconciliation and blocks late restoration',
    () async {
      final provider = _GatedContextProvider();
      await api.setProviderAndWait(provider);
      final contextChange = api.setEvaluationContextAndWait(
        EvaluationContext(targetingKey: 'user-a'),
      );
      await provider.waitForChange(1);
      var shutdownCompleted = false;

      final shutdown = api.shutdown().then((_) {
        shutdownCompleted = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(shutdownCompleted, isFalse);
      provider.allowChange(0);
      await Future.wait([contextChange, shutdown]);

      expect(provider.shutdownCalls, 1);
      expect(api.getClient().providerStatus, ProviderStatus.notReady);
      expect(api.getClient().getBooleanValue('flag', false), isFalse);
      provider.emit(ProviderEventType.ready);
      expect(api.getClient().providerStatus, ProviderStatus.notReady);
    },
  );

  test(
    'older context work cannot replace the latest active revision',
    () async {
      final provider = _GatedContextProvider();
      await api.setProviderAndWait(provider);
      final first = EvaluationContext(targetingKey: 'first');
      final second = EvaluationContext(targetingKey: 'second');

      final firstRequest = api.setEvaluationContextAndWait(first);
      await provider.waitForChange(1);
      final secondRequest = api.setEvaluationContextAndWait(second);
      await Future<void>.delayed(Duration.zero);
      expect(provider.changes, hasLength(1));

      provider.allowChange(0);
      await provider.waitForChange(2);
      expect(provider.activeContext, same(first));
      provider.allowChange(1);
      await Future.wait([firstRequest, secondRequest]);

      expect(provider.activeContext, same(second));
      expect(provider.changes, [
        (EvaluationContext.empty, first),
        (first, second),
      ]);
      expect(api.getClient().getBooleanValue('flag', false), isTrue);
      expect(provider.lastEvaluationContext, same(second));

      provider.emit(ProviderEventType.contextChanged);
      api.getClient().getBooleanValue('flag', false);
      expect(provider.lastEvaluationContext, same(second));
    },
  );

  test(
    'different providers reconcile the global context concurrently',
    () async {
      final defaultProvider = _GatedContextProvider(name: 'default');
      final domainProvider = _GatedContextProvider(name: 'domain');
      await api.setProviderAndWait(defaultProvider);
      await api.setProviderForDomainAndWait('checkout', domainProvider);

      final contextChange = api.setEvaluationContextAndWait(
        EvaluationContext(targetingKey: 'user-a'),
      );
      await Future.wait([
        defaultProvider.waitForChange(1),
        domainProvider.waitForChange(1),
      ]);

      defaultProvider.allowChange(0);
      domainProvider.allowChange(0);
      await contextChange;
      expect(defaultProvider.activeContext.targetingKey, 'user-a');
      expect(domainProvider.activeContext.targetingKey, 'user-a');
    },
  );
}

final class _GatedContextProvider
    implements
        FeatureProvider,
        ContextReconciliationProvider,
        ProviderEventSource,
        ShutdownProvider {
  _GatedContextProvider({this.name = 'gated-provider'})
    : _delegate = InMemoryProvider({'flag': true});

  final String name;
  final InMemoryProvider _delegate;
  final StreamController<ProviderEvent> _events =
      StreamController<ProviderEvent>.broadcast(sync: true);
  final StreamController<int> _starts = StreamController<int>.broadcast(
    sync: true,
  );
  final List<Completer<void>> _gates = <Completer<void>>[];
  final List<(EvaluationContext, EvaluationContext)> changes = [];
  EvaluationContext activeContext = EvaluationContext.empty;
  EvaluationContext? lastEvaluationContext;
  int shutdownCalls = 0;

  @override
  Stream<ProviderEvent> get events => _events.stream;

  @override
  ProviderMetadata get metadata => ProviderMetadata(name: name);

  Future<void> waitForChange(int count) async {
    if (changes.length >= count) {
      return;
    }
    await _starts.stream.firstWhere((started) => started >= count);
  }

  void allowChange(int index) => _gates[index].complete();

  void emit(ProviderEventType type) {
    _events.add(ProviderEvent(type: type));
  }

  @override
  Future<void> onContextChanged(
    EvaluationContext previousContext,
    EvaluationContext newContext,
  ) async {
    final gate = Completer<void>();
    _gates.add(gate);
    changes.add((previousContext, newContext));
    _events.add(ProviderEvent(type: ProviderEventType.reconciling));
    _starts.add(changes.length);
    await gate.future;
    activeContext = newContext;
    _events.add(ProviderEvent(type: ProviderEventType.contextChanged));
  }

  @override
  Future<void> shutdown() async {
    shutdownCalls++;
  }

  @override
  ResolutionDetails<bool> resolveBooleanValue(
    String flagKey,
    bool defaultValue,
    EvaluationContext context,
  ) {
    lastEvaluationContext = context;
    return _delegate.resolveBooleanValue(flagKey, defaultValue, context);
  }

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
