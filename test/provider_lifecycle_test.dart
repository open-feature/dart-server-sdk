import 'dart:async';

import 'package:test/test.dart';

import '../lib/feature_provider.dart';
import '../lib/open_feature_api.dart';
import '../lib/open_feature_event.dart';
import '../lib/provider_lifecycle.dart';

class _LegacyProvider implements FeatureProvider {
  final String providerName;
  final Map<String, dynamic> flags;
  ProviderState _state;
  int initializeCount = 0;
  int shutdownCount = 0;

  _LegacyProvider(
    this.flags, {
    this.providerName = 'provider',
    ProviderState initialState = ProviderState.NOT_READY,
  }) : _state = initialState;

  @override
  String get name => providerName;

  @override
  ProviderState get state => _state;

  @override
  ProviderConfig get config => const ProviderConfig();

  @override
  ProviderMetadata get metadata => ProviderMetadata(name: providerName);

  @override
  Future<void> initialize([Map<String, dynamic>? config]) async {
    initializeCount++;
    _state = ProviderState.READY;
  }

  @override
  Future<void> connect() async {
    _state = ProviderState.READY;
  }

  @override
  Future<void> shutdown() async {
    shutdownCount++;
    _state = ProviderState.SHUTDOWN;
  }

  @override
  Future<FlagEvaluationResult<bool>> getBooleanFlag(
    String flagKey,
    bool defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    final value = flags[flagKey];
    if (value is bool) {
      return _result(flagKey, value);
    }
    return FlagEvaluationResult.error(
      flagKey,
      defaultValue,
      value == null ? ErrorCode.FLAG_NOT_FOUND : ErrorCode.TYPE_MISMATCH,
      'Boolean flag not found.',
      evaluatorId: name,
    );
  }

  @override
  Future<FlagEvaluationResult<String>> getStringFlag(
    String flagKey,
    String defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    final value = flags[flagKey];
    return value is String
        ? _result(flagKey, value)
        : FlagEvaluationResult.error(
            flagKey,
            defaultValue,
            ErrorCode.FLAG_NOT_FOUND,
            'String flag not found.',
            evaluatorId: name,
          );
  }

  @override
  Future<FlagEvaluationResult<int>> getIntegerFlag(
    String flagKey,
    int defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    final value = flags[flagKey];
    return value is int
        ? _result(flagKey, value)
        : FlagEvaluationResult.error(
            flagKey,
            defaultValue,
            ErrorCode.FLAG_NOT_FOUND,
            'Integer flag not found.',
            evaluatorId: name,
          );
  }

  @override
  Future<FlagEvaluationResult<double>> getDoubleFlag(
    String flagKey,
    double defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    final value = flags[flagKey];
    return value is double
        ? _result(flagKey, value)
        : FlagEvaluationResult.error(
            flagKey,
            defaultValue,
            ErrorCode.FLAG_NOT_FOUND,
            'Double flag not found.',
            evaluatorId: name,
          );
  }

  @override
  Future<FlagEvaluationResult<Map<String, dynamic>>> getObjectFlag(
    String flagKey,
    Map<String, dynamic> defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    final value = flags[flagKey];
    return value is Map<String, dynamic>
        ? _result(flagKey, value)
        : FlagEvaluationResult.error(
            flagKey,
            defaultValue,
            ErrorCode.FLAG_NOT_FOUND,
            'Object flag not found.',
            evaluatorId: name,
          );
  }

  FlagEvaluationResult<T> _result<T>(String flagKey, T value) {
    return FlagEvaluationResult<T>(
      flagKey: flagKey,
      value: value,
      reason: 'STATIC',
      evaluatedAt: DateTime.now(),
      evaluatorId: name,
    );
  }

  @override
  Future<void> track(
    String trackingEventName, {
    Map<String, dynamic>? evaluationContext,
    TrackingEventDetails? trackingDetails,
  }) async {}
}

class _EventProvider extends _LegacyProvider implements ProviderEventSource {
  final StreamController<ProviderLifecycleEvent> _events =
      StreamController<ProviderLifecycleEvent>.broadcast();
  final bool emitReady;
  final bool failInitialization;
  final Duration readyEventDelay;

  _EventProvider(
    super.flags, {
    super.providerName,
    this.emitReady = true,
    this.failInitialization = false,
    this.readyEventDelay = Duration.zero,
  });

  @override
  Stream<ProviderLifecycleEvent> get providerEvents => _events.stream;

  @override
  Future<void> initialize([Map<String, dynamic>? config]) async {
    initializeCount++;
    if (failInitialization) {
      _state = ProviderState.ERROR;
      _events.add(
        ProviderLifecycleEvent(
          ProviderLifecycleEventType.PROVIDER_ERROR,
          'Provider initialization failed.',
          errorCode: ErrorCode.PROVIDER_FATAL,
        ),
      );
      throw const ProviderException(
        'Provider initialization failed.',
        code: ErrorCode.PROVIDER_FATAL,
      );
    }

    _state = ProviderState.READY;
    if (emitReady) {
      void emitReadyEvent() => _events.add(
        ProviderLifecycleEvent(
          ProviderLifecycleEventType.PROVIDER_READY,
          'Provider is ready.',
        ),
      );
      if (readyEventDelay == Duration.zero) {
        emitReadyEvent();
      } else {
        unawaited(Future<void>.delayed(readyEventDelay, emitReadyEvent));
      }
    }
  }

  void emit(ProviderLifecycleEvent event) => _events.add(event);
}

class _DelayedShutdownEventProvider extends _EventProvider {
  final Completer<void> shutdownStarted = Completer<void>();
  final Completer<void> allowShutdown = Completer<void>();

  _DelayedShutdownEventProvider(super.flags);

  @override
  Future<void> shutdown() async {
    shutdownCount++;
    if (!shutdownStarted.isCompleted) {
      shutdownStarted.complete();
    }
    await allowShutdown.future;
    _state = ProviderState.SHUTDOWN;
  }
}

class _DomainScopedProvider extends _EventProvider
    implements DomainScopedProvider {
  _DomainScopedProvider(super.flags);
}

void main() {
  group('OpenFeature v0.9 provider lifecycle', () {
    setUp(() async {
      await OpenFeatureAPI.resetInstance();
    });

    tearDown(() async {
      await OpenFeatureAPI.resetInstance();
    });

    test('provider event updates status before API handlers run', () async {
      final api = OpenFeatureAPI();
      final provider = _EventProvider({'flag': true});
      final observedStatuses = <ProviderState>[];
      final events = <OpenFeatureEvent>[];
      final subscription = api.events.listen((event) {
        if (identical(event.provider, provider)) {
          events.add(event);
          observedStatuses.add(api.providerStatus);
        }
      });

      await api.setProviderAndWait(provider);
      await Future<void>.delayed(Duration.zero);

      expect(api.providerStatus, ProviderState.READY);
      expect(events, hasLength(1));
      expect(events.single.type, OpenFeatureEventType.PROVIDER_READY);
      expect(observedStatuses, [ProviderState.READY]);
      await subscription.cancel();
    });

    test(
      'event-capable provider must emit within the lifecycle timeout',
      () async {
        final api = OpenFeatureAPI();
        final provider = _EventProvider({'flag': true}, emitReady: false);
        final lifecycleEvents = <OpenFeatureEvent>[];
        final subscription = api.events.listen((event) {
          if (identical(event.provider, provider)) {
            lifecycleEvents.add(event);
          }
        });

        await expectLater(
          api.setProviderAndWait(provider),
          throwsA(
            isA<ProviderException>().having(
              (error) => error.message,
              'message',
              contains('did not emit a lifecycle event within'),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(identical(api.provider, provider), isTrue);
        expect(api.providerStatus, ProviderState.NOT_READY);
        expect(lifecycleEvents, isEmpty);
        await subscription.cancel();
      },
    );

    test('provider error event sets fatal status without synthesis', () async {
      final api = OpenFeatureAPI();
      final provider = _EventProvider({'flag': true}, failInitialization: true);
      final events = <OpenFeatureEvent>[];
      final subscription = api.events.listen((event) {
        if (identical(event.provider, provider)) {
          events.add(event);
        }
      });

      await expectLater(
        api.setProviderAndWait(provider),
        throwsA(isA<ProviderException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(api.providerStatus, ProviderState.FATAL);
      expect(events, hasLength(1));
      expect(events.single.type, OpenFeatureEventType.PROVIDER_ERROR);
      expect(events.single.errorCode, ErrorCode.PROVIDER_FATAL);
      await subscription.cancel();
    });

    test(
      'accepts a lifecycle event emitted shortly after initialize',
      () async {
        final api = OpenFeatureAPI();
        final provider = _EventProvider({
          'flag': true,
        }, readyEventDelay: const Duration(milliseconds: 20));

        await api.setProviderAndWait(provider);

        expect(api.providerStatus, ProviderState.READY);
        expect(provider.initializeCount, 1);
      },
    );

    test(
      'legacy providers retain synthesized lifecycle compatibility',
      () async {
        final api = OpenFeatureAPI();
        final provider = _LegacyProvider({'flag': true});
        final events = <OpenFeatureEvent>[];
        final subscription = api.events.listen((event) {
          if (identical(event.provider, provider)) {
            events.add(event);
          }
        });

        await api.setProviderAndWait(provider);
        await Future<void>.delayed(Duration.zero);

        expect(api.providerStatus, ProviderState.READY);
        expect(events, hasLength(1));
        expect(events.single.type, OpenFeatureEventType.PROVIDER_READY);
        await subscription.cancel();
      },
    );

    test('already-ready legacy provider still announces readiness', () async {
      final api = OpenFeatureAPI();
      final provider = _LegacyProvider({
        'flag': true,
      }, initialState: ProviderState.READY);
      final events = <OpenFeatureEvent>[];
      final subscription = api.events.listen((event) {
        if (identical(event.provider, provider)) {
          events.add(event);
        }
      });

      await api.setProviderAndWait(provider);
      await Future<void>.delayed(Duration.zero);

      expect(provider.initializeCount, 0);
      expect(events, hasLength(1));
      expect(events.single.type, OpenFeatureEventType.PROVIDER_READY);
      await subscription.cancel();
    });

    test('existing clients follow default provider replacement', () async {
      final api = OpenFeatureAPI();
      final first = _EventProvider({'flag': true}, providerName: 'shared');
      final second = _EventProvider({'flag': false}, providerName: 'shared');

      await api.setProviderAndWait(first);
      final client = api.getClient('existing-client');
      expect(await client.getBooleanFlag('flag'), isTrue);

      await api.setProviderAndWait(second);

      expect(identical(client.provider, second), isTrue);
      expect(client.providerStatus, ProviderState.READY);
      expect(await client.getBooleanFlag('flag'), isFalse);
    });

    test('rebinding waits for an in-progress provider shutdown', () async {
      final api = OpenFeatureAPI();
      final first = _DelayedShutdownEventProvider({'flag': true});
      final second = _EventProvider({'flag': false});

      await api.setProviderAndWait(first);
      final replacement = api.setProviderAndWait(second);
      await first.shutdownStarted.future;

      var rebindCompleted = false;
      final rebind = api.setProviderAndWait(first).then((_) {
        rebindCompleted = true;
      });
      await Future<void>.delayed(Duration.zero);

      expect(rebindCompleted, isFalse);
      expect(first.initializeCount, 1);

      first.allowShutdown.complete();
      await Future.wait([replacement, rebind]);

      expect(first.initializeCount, 2);
      expect(identical(api.provider, first), isTrue);
      expect(api.providerStatus, ProviderState.READY);
    });

    test('same-name instances remain isolated by provider ID', () async {
      final api = OpenFeatureAPI();
      final first = _EventProvider({'flag': true}, providerName: 'shared');
      final second = _EventProvider({'flag': false}, providerName: 'shared');

      await api.registerProviderAndWait(first, providerId: 'shared-blue');
      await api.registerProviderAndWait(second, providerId: 'shared-green');
      await api.bindClientToProviderAndWait('blue', 'shared-blue');
      await api.bindClientToProviderAndWait('green', 'shared-green');

      final blue = api.getClient('blue', domain: 'blue');
      final green = api.getClient('green', domain: 'green');
      final blueEvents = <OpenFeatureEvent>[];
      final greenEvents = <OpenFeatureEvent>[];
      final blueSubscription = blue.events.listen(blueEvents.add);
      final greenSubscription = green.events.listen(greenEvents.add);

      expect(await blue.getBooleanFlag('flag'), isTrue);
      expect(await green.getBooleanFlag('flag'), isFalse);

      second.emit(
        ProviderLifecycleEvent(
          ProviderLifecycleEventType.PROVIDER_STALE,
          'Green provider is stale.',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(blueEvents, isEmpty);
      expect(greenEvents, hasLength(1));
      expect(green.providerStatus, ProviderState.STALE);
      await blueSubscription.cancel();
      await greenSubscription.cancel();
      await blue.dispose();
      await green.dispose();
    });

    test('legacy name-first binding activates after registration', () async {
      final api = OpenFeatureAPI();
      api.bindClientToProvider('checkout', 'late-provider');
      final client = api.getClient('checkout', domain: 'checkout');
      final provider = _EventProvider({'flag': true});

      await api.registerProviderAndWait(provider, providerId: 'late-provider');

      expect(identical(client.provider, provider), isTrue);
      expect(client.providerStatus, ProviderState.READY);
      expect(provider.initializeCount, 1);
      expect(await client.getBooleanFlag('flag'), isTrue);
    });

    test(
      'provider shuts down only after its final binding is removed',
      () async {
        final api = OpenFeatureAPI();
        final first = _EventProvider({'flag': true}, providerName: 'first');
        final replacement = _EventProvider({
          'flag': false,
        }, providerName: 'replacement');

        await api.setProviderAndWait(first);
        api.registerProvider(first, providerId: 'first-domain');
        await api.bindClientToProviderAndWait('checkout', 'first-domain');

        await api.setProviderAndWait(replacement);
        expect(first.shutdownCount, 0);

        api.registerProvider(replacement, providerId: 'replacement-domain');
        await api.bindClientToProviderAndWait('checkout', 'replacement-domain');

        expect(first.shutdownCount, 1);
        expect(replacement.shutdownCount, 0);
      },
    );

    test('event provider can be rebound after final shutdown', () async {
      final api = OpenFeatureAPI();
      final provider = _EventProvider({'flag': true}, providerName: 'first');
      final replacement = _EventProvider({
        'flag': false,
      }, providerName: 'replacement');

      await api.setProviderAndWait(provider);
      await api.setProviderAndWait(replacement);
      await api.setProviderAndWait(provider);

      expect(provider.initializeCount, 2);
      expect(provider.shutdownCount, 1);
      expect(api.providerStatus, ProviderState.READY);
    });

    test('legacy provider can be rebound after final shutdown', () async {
      final api = OpenFeatureAPI();
      final provider = _LegacyProvider({'flag': true}, providerName: 'first');
      final replacement = _LegacyProvider({
        'flag': false,
      }, providerName: 'replacement');

      await api.setProviderAndWait(provider);
      await api.setProviderAndWait(replacement);
      await api.setProviderAndWait(provider);

      expect(provider.initializeCount, 2);
      expect(provider.shutdownCount, 1);
      expect(api.providerStatus, ProviderState.READY);
    });

    test('shut-down providers stop forwarding lifecycle events', () async {
      final api = OpenFeatureAPI();
      final provider = _EventProvider({'flag': true}, providerName: 'first');
      final replacement = _EventProvider({
        'flag': false,
      }, providerName: 'replacement');
      final forwarded = <OpenFeatureEvent>[];
      final subscription = api.events.listen((event) {
        if (identical(event.provider, provider)) {
          forwarded.add(event);
        }
      });

      await api.setProviderAndWait(provider);
      await api.setProviderAndWait(replacement);
      forwarded.clear();
      provider.emit(
        ProviderLifecycleEvent(
          ProviderLifecycleEventType.PROVIDER_STALE,
          'Stale after shutdown.',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(forwarded, isEmpty);
      await subscription.cancel();
    });

    test('non-wait binding activates only after provider readiness', () async {
      final api = OpenFeatureAPI();
      final provider = _EventProvider(
        {'flag': true},
        providerName: 'delayed',
        readyEventDelay: const Duration(milliseconds: 20),
      );
      api.registerProvider(provider, providerId: 'delayed');
      final client = api.getClient('checkout', domain: 'checkout');
      final configured = api.events.firstWhere(
        (event) =>
            event.type == OpenFeatureEventType.PROVIDER_CONFIGURATION_CHANGED &&
            event.domain == 'checkout',
      );

      api.bindClientToProvider('checkout', 'delayed');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(identical(client.provider, provider), isFalse);
      await configured;
      expect(identical(client.provider, provider), isTrue);
      expect(client.providerStatus, ProviderState.READY);
    });

    test('domain-scoped provider rejects a second domain', () async {
      final api = OpenFeatureAPI();
      final provider = _DomainScopedProvider({'flag': true});

      await api.registerProviderAndWait(provider, providerId: 'scoped');
      await api.bindClientToProviderAndWait('domain-a', 'scoped');

      await expectLater(
        api.bindClientToProviderAndWait('domain-b', 'scoped'),
        throwsA(
          isA<ProviderException>().having(
            (error) => error.code,
            'code',
            ErrorCode.INVALID_CONTEXT,
          ),
        ),
      );
    });
  });
}
