import 'dart:async';
import 'dart:collection';

import 'details.dart';
import 'error.dart';
import 'evaluation_context.dart';
import 'events.dart';
import 'hooks.dart';
import 'metadata.dart';
import 'no_op_provider.dart';
import 'provider.dart';

/// The static-context OpenFeature API.
final class OpenFeatureAPI {
  OpenFeatureAPI._();

  /// Creates an isolated API instance.
  ///
  /// This API is experimental. Prefer [instance] for application code.
  factory OpenFeatureAPI.createIsolated() => OpenFeatureAPI._();

  /// The process-wide default API instance.
  static final OpenFeatureAPI instance = OpenFeatureAPI._();

  static const FeatureProvider _noOpProvider = NoOpProvider();

  FeatureProvider _defaultProvider = _noOpProvider;
  final Map<String, FeatureProvider> _domainProviders =
      <String, FeatureProvider>{};
  EvaluationContext _globalContext = EvaluationContext.empty;
  final Map<String, EvaluationContext> _domainContexts =
      <String, EvaluationContext>{};
  final List<Hook> _hooks = <Hook>[];
  final Map<FeatureProvider, _ProviderRecord> _providerRecords =
      HashMap<FeatureProvider, _ProviderRecord>.identity();
  Future<void> _mutationQueue = Future<void>.value();

  /// Adds API hooks without removing existing hooks.
  void addHooks(Iterable<Hook> hooks) => _hooks.addAll(hooks);

  /// Gets a client bound to [domain], or to the default provider when omitted.
  OpenFeatureClient getClient([String? domain]) {
    return OpenFeatureClient._(this, ClientMetadata(domain: domain));
  }

  /// Gets metadata for the provider selected by [domain].
  ProviderMetadata getProviderMetadata([String? domain]) {
    return _providerForDomain(domain).metadata;
  }

  /// Starts registration of the default provider.
  void setProvider(FeatureProvider provider) {
    unawaited(setProviderAndWait(provider).catchError((Object _) {}));
  }

  /// Registers the default provider after its initialization terminates.
  Future<void> setProviderAndWait(FeatureProvider provider) {
    return _enqueueMutation(() => _setProvider(provider, domain: null));
  }

  /// Starts registration of [provider] for [domain].
  void setProviderForDomain(String domain, FeatureProvider provider) {
    unawaited(
      setProviderForDomainAndWait(domain, provider).catchError((Object _) {}),
    );
  }

  /// Registers [provider] for [domain] after initialization terminates.
  Future<void> setProviderForDomainAndWait(
    String domain,
    FeatureProvider provider,
  ) {
    return _enqueueMutation(() => _setProvider(provider, domain: domain));
  }

  /// Starts a global context change.
  void setEvaluationContext(EvaluationContext context) {
    unawaited(setEvaluationContextAndWait(context).catchError((Object _) {}));
  }

  /// Sets the global static evaluation context.
  Future<void> setEvaluationContextAndWait(EvaluationContext context) {
    return _enqueueMutation(() => _setGlobalContext(context));
  }

  Future<void> _setGlobalContext(EvaluationContext context) async {
    final previousContext = _globalContext;
    final providers = HashSet<FeatureProvider>.identity()
      ..add(_defaultProvider)
      ..addAll(
        _domainProviders.entries
            .where((entry) => !_domainContexts.containsKey(entry.key))
            .map((entry) => entry.value),
      )
      ..remove(_noOpProvider);

    await Future.wait(
      providers.map(
        (provider) => _reconcile(provider, previousContext, context),
      ),
    );
    _globalContext = context;
  }

  /// Starts a context change for [domain].
  void setEvaluationContextForDomain(String domain, EvaluationContext context) {
    unawaited(
      setEvaluationContextForDomainAndWait(
        domain,
        context,
      ).catchError((Object _) {}),
    );
  }

  /// Sets the static evaluation context for [domain].
  Future<void> setEvaluationContextForDomainAndWait(
    String domain,
    EvaluationContext context,
  ) {
    return _enqueueMutation(() => _setDomainContext(domain, context));
  }

  Future<void> _setDomainContext(
    String domain,
    EvaluationContext context,
  ) async {
    final previousContext = _contextForDomain(domain);
    final provider = _domainProviders[domain];
    if (provider != null) {
      await _reconcile(provider, previousContext, context);
    }
    _domainContexts[domain] = context;
  }

  /// Clears a domain context and restores global-context fallback.
  Future<void> clearEvaluationContextForDomainAndWait(String domain) {
    return _enqueueMutation(() => _clearDomainContext(domain));
  }

  Future<void> _clearDomainContext(String domain) async {
    final previousContext = _contextForDomain(domain);
    final provider = _domainProviders[domain];
    if (provider != null && _domainContexts.containsKey(domain)) {
      await _reconcile(provider, previousContext, _globalContext);
    }
    _domainContexts.remove(domain);
  }

  /// Starts clearing a domain context.
  void clearEvaluationContextForDomain(String domain) {
    unawaited(
      clearEvaluationContextForDomainAndWait(domain).catchError((Object _) {}),
    );
  }

  /// Shuts down all active providers and resets API state.
  Future<void> shutdown() => _enqueueMutation(_shutdown);

  Future<void> _shutdown() async {
    final records = _providerRecords.entries.toList(growable: false);
    _defaultProvider = _noOpProvider;
    _domainProviders.clear();
    _domainContexts.clear();
    _globalContext = EvaluationContext.empty;
    _hooks.clear();

    try {
      await Future.wait(
        records.map((entry) async {
          await entry.value.eventSubscription?.cancel();
          if (entry.key is ShutdownProvider) {
            await (entry.key as ShutdownProvider).shutdown();
          }
        }),
      );
    } finally {
      _providerRecords.clear();
    }
  }

  FeatureProvider _providerForDomain(String? domain) {
    if (domain == null) {
      return _defaultProvider;
    }
    return _domainProviders[domain] ?? _defaultProvider;
  }

  EvaluationContext _contextForDomain(String? domain) {
    if (domain == null) {
      return _globalContext;
    }
    return _domainContexts[domain] ?? _globalContext;
  }

  ProviderStatus _statusForDomain(String? domain) {
    final provider = _providerForDomain(domain);
    if (identical(provider, _noOpProvider)) {
      return ProviderStatus.notReady;
    }
    return _providerRecords[provider]?.status ?? ProviderStatus.notReady;
  }

  Future<void> _setProvider(
    FeatureProvider provider, {
    required String? domain,
  }) async {
    final current = _providerForExactBinding(domain);
    if (identical(current, provider)) {
      return;
    }
    _validateDomainScope(provider, domain);

    var record = _providerRecords[provider];
    Object? initializationError;
    StackTrace? initializationStackTrace;
    if (record == null) {
      record = _ProviderRecord(initialDomain: domain);
      _providerRecords[provider] = record;
      try {
        await _initialize(provider, record, domain);
      } on Object catch (error, stackTrace) {
        if (record.status != ProviderStatus.error &&
            record.status != ProviderStatus.fatal) {
          await record.eventSubscription?.cancel();
          _providerRecords.remove(provider);
          rethrow;
        }
        initializationError = error;
        initializationStackTrace = stackTrace;
      }
    }

    if (domain == null) {
      _defaultProvider = provider;
    } else {
      _domainProviders[domain] = provider;
    }
    record.bindingCount++;

    if (!identical(current, _noOpProvider)) {
      await _releaseProvider(current);
    }
    if (initializationError != null) {
      Error.throwWithStackTrace(initializationError, initializationStackTrace!);
    }
  }

  FeatureProvider _providerForExactBinding(String? domain) {
    if (domain == null) {
      return _defaultProvider;
    }
    return _domainProviders[domain] ?? _noOpProvider;
  }

  void _validateDomainScope(FeatureProvider provider, String? domain) {
    if (provider is! DomainScopedProvider) {
      return;
    }
    final record = _providerRecords[provider];
    if (record != null &&
        record.bindingCount > 0 &&
        record.initialDomain != domain) {
      throw const OpenFeatureException(
        'A domain-scoped provider can be bound to only one domain.',
      );
    }
  }

  Future<void> _enqueueMutation(Future<void> Function() operation) {
    final result = _mutationQueue.then(
      (_) => operation(),
      onError: (Object _, StackTrace _) => operation(),
    );
    _mutationQueue = result.catchError((Object _) {});
    return result;
  }

  Future<void> _initialize(
    FeatureProvider provider,
    _ProviderRecord record,
    String? domain,
  ) async {
    if (provider is ProviderEventSource) {
      record.eventSubscription = (provider as ProviderEventSource).events
          .listen((event) => _processEvent(record, event));
    }

    if (provider is! InitializableProvider) {
      record.status = ProviderStatus.ready;
      return;
    }
    if (provider is! ProviderEventSource) {
      throw const OpenFeatureException(
        'A provider with initialize() must expose provider events.',
      );
    }

    final terminalEvent = Completer<ProviderStatus>();
    record.terminalEvent = terminalEvent;
    try {
      await (provider as InitializableProvider).initialize(
        _contextForDomain(domain),
        domain: domain,
      );
      final status = await terminalEvent.future;
      if (status == ProviderStatus.error || status == ProviderStatus.fatal) {
        throw OpenFeatureException(
          'Provider initialization ended with status ${status.name}.',
          errorCode: status == ProviderStatus.fatal
              ? ErrorCode.providerFatal
              : ErrorCode.general,
        );
      }
    } finally {
      record.terminalEvent = null;
    }
  }

  Future<void> _reconcile(
    FeatureProvider provider,
    EvaluationContext previousContext,
    EvaluationContext newContext,
  ) async {
    if (provider is! ContextReconciliationProvider) {
      return;
    }
    if (provider is! ProviderEventSource) {
      throw const OpenFeatureException(
        'A provider with onContextChanged() must expose provider events.',
      );
    }

    final record = _providerRecords[provider];
    if (record == null) {
      return;
    }
    final terminalEvent = Completer<ProviderStatus>();
    record.terminalEvent = terminalEvent;
    try {
      await (provider as ContextReconciliationProvider).onContextChanged(
        previousContext,
        newContext,
      );
      final status = await terminalEvent.future;
      if (status == ProviderStatus.error || status == ProviderStatus.fatal) {
        throw OpenFeatureException(
          'Provider reconciliation ended with status ${status.name}.',
          errorCode: status == ProviderStatus.fatal
              ? ErrorCode.providerFatal
              : ErrorCode.general,
        );
      }
    } finally {
      record.terminalEvent = null;
    }
  }

  void _processEvent(_ProviderRecord record, ProviderEvent event) {
    switch (event.type) {
      case ProviderEventType.ready:
      case ProviderEventType.contextChanged:
        record.status = ProviderStatus.ready;
        break;
      case ProviderEventType.error:
        record.status = event.errorCode == ErrorCode.providerFatal
            ? ProviderStatus.fatal
            : ProviderStatus.error;
        break;
      case ProviderEventType.stale:
        record.status = ProviderStatus.stale;
        break;
      case ProviderEventType.reconciling:
        record.status = ProviderStatus.reconciling;
        break;
      case ProviderEventType.configurationChanged:
        break;
    }

    if (event.type == ProviderEventType.ready ||
        event.type == ProviderEventType.contextChanged ||
        event.type == ProviderEventType.error) {
      final terminalEvent = record.terminalEvent;
      if (terminalEvent != null && !terminalEvent.isCompleted) {
        terminalEvent.complete(record.status);
      }
    }
  }

  Future<void> _releaseProvider(FeatureProvider provider) async {
    final record = _providerRecords[provider];
    if (record == null) {
      return;
    }
    record.bindingCount--;
    if (record.bindingCount > 0) {
      return;
    }
    await record.eventSubscription?.cancel();
    try {
      if (provider is ShutdownProvider) {
        await (provider as ShutdownProvider).shutdown();
      }
    } finally {
      record.status = ProviderStatus.notReady;
      _providerRecords.remove(provider);
    }
  }
}

/// A client bound to one OpenFeature domain.
final class OpenFeatureClient {
  OpenFeatureClient._(this._api, this.metadata);

  final OpenFeatureAPI _api;
  final List<Hook> _hooks = <Hook>[];

  final ClientMetadata metadata;

  ProviderMetadata get providerMetadata =>
      _api.getProviderMetadata(metadata.domain);

  ProviderStatus get providerStatus => _api._statusForDomain(metadata.domain);

  /// Adds client hooks without removing existing hooks.
  void addHooks(Iterable<Hook> hooks) => _hooks.addAll(hooks);

  bool getBooleanValue(
    String flagKey,
    bool defaultValue, {
    EvaluationOptions? options,
  }) => getBooleanDetails(flagKey, defaultValue, options: options).value;

  FlagEvaluationDetails<bool> getBooleanDetails(
    String flagKey,
    bool defaultValue, {
    EvaluationOptions? options,
  }) {
    return _evaluate(
      flagKey,
      defaultValue,
      FlagValueType.boolean,
      (provider, context) =>
          provider.resolveBooleanValue(flagKey, defaultValue, context),
      options: options,
    );
  }

  String getStringValue(
    String flagKey,
    String defaultValue, {
    EvaluationOptions? options,
  }) => getStringDetails(flagKey, defaultValue, options: options).value;

  FlagEvaluationDetails<String> getStringDetails(
    String flagKey,
    String defaultValue, {
    EvaluationOptions? options,
  }) {
    return _evaluate(
      flagKey,
      defaultValue,
      FlagValueType.string,
      (provider, context) =>
          provider.resolveStringValue(flagKey, defaultValue, context),
      options: options,
    );
  }

  int getIntegerValue(
    String flagKey,
    int defaultValue, {
    EvaluationOptions? options,
  }) => getIntegerDetails(flagKey, defaultValue, options: options).value;

  FlagEvaluationDetails<int> getIntegerDetails(
    String flagKey,
    int defaultValue, {
    EvaluationOptions? options,
  }) {
    return _evaluate(
      flagKey,
      defaultValue,
      FlagValueType.integer,
      (provider, context) =>
          provider.resolveIntegerValue(flagKey, defaultValue, context),
      options: options,
    );
  }

  double getDoubleValue(
    String flagKey,
    double defaultValue, {
    EvaluationOptions? options,
  }) => getDoubleDetails(flagKey, defaultValue, options: options).value;

  FlagEvaluationDetails<double> getDoubleDetails(
    String flagKey,
    double defaultValue, {
    EvaluationOptions? options,
  }) {
    return _evaluate(
      flagKey,
      defaultValue,
      FlagValueType.double,
      (provider, context) =>
          provider.resolveDoubleValue(flagKey, defaultValue, context),
      options: options,
    );
  }

  Map<String, Object?> getStructureValue(
    String flagKey,
    Map<String, Object?> defaultValue, {
    EvaluationOptions? options,
  }) => getStructureDetails(flagKey, defaultValue, options: options).value;

  FlagEvaluationDetails<Map<String, Object?>> getStructureDetails(
    String flagKey,
    Map<String, Object?> defaultValue, {
    EvaluationOptions? options,
  }) {
    return _evaluate(
      flagKey,
      defaultValue,
      FlagValueType.structure,
      (provider, context) =>
          provider.resolveStructureValue(flagKey, defaultValue, context),
      options: options,
    );
  }

  /// Sends a non-blocking tracking call when the provider supports tracking.
  void track(String trackingEventName, {TrackingEventDetails? details}) {
    final provider = _api._providerForDomain(metadata.domain);
    if (provider is TrackingProvider) {
      try {
        (provider as TrackingProvider).track(
          trackingEventName,
          _api._contextForDomain(metadata.domain),
          details: details,
        );
      } on Object {
        // Tracking support must not cause abnormal application execution.
      }
    }
  }

  FlagEvaluationDetails<T> _evaluate<T extends Object>(
    String flagKey,
    T defaultValue,
    FlagValueType flagValueType,
    ResolutionDetails<T> Function(
      FeatureProvider provider,
      EvaluationContext context,
    )
    resolve, {
    EvaluationOptions? options,
  }) {
    final provider = _api._providerForDomain(metadata.domain);
    final evaluationContext = _api._contextForDomain(metadata.domain);
    final hints = options?.hookHints ?? HookHints();
    late final List<Hook> hooks;
    late final ProviderMetadata providerMetadata;
    try {
      providerMetadata = provider.metadata;
      hooks = <Hook>[
        ..._api._hooks,
        ..._hooks,
        ...?options?.hooks,
        if (provider is ProviderHooks) ...(provider as ProviderHooks).hooks,
      ];
    } on Object catch (error) {
      return _errorDetails(flagKey, defaultValue, error);
    }

    final hookContexts = hooks
        .map(
          (_) => HookContext(
            flagKey: flagKey,
            defaultValue: defaultValue,
            flagValueType: flagValueType,
            clientMetadata: metadata,
            providerMetadata: providerMetadata,
            evaluationContext: evaluationContext,
          ),
        )
        .toList(growable: false);

    FlagEvaluationDetails<T>? details;
    Object? evaluationError;
    try {
      for (var index = 0; index < hooks.length; index++) {
        hooks[index].before(hookContexts[index], hints);
      }
      final resolution = resolve(provider, evaluationContext);
      details = FlagEvaluationDetails<T>(
        flagKey: flagKey,
        value: resolution.errorCode == null ? resolution.value : defaultValue,
        errorCode: resolution.errorCode,
        errorMessage: resolution.errorMessage,
        reason: resolution.reason,
        variant: resolution.variant,
        flagMetadata: resolution.flagMetadata,
      );
      if (resolution.errorCode != null) {
        evaluationError = OpenFeatureException(
          resolution.errorMessage ?? 'Provider resolution failed.',
          errorCode: resolution.errorCode!,
        );
      } else {
        for (var index = hooks.length - 1; index >= 0; index--) {
          hooks[index].after(hookContexts[index], details, hints);
        }
      }
    } on Object catch (error) {
      evaluationError = error;
      details = _errorDetails(flagKey, defaultValue, error);
    }

    if (evaluationError != null) {
      for (var index = hooks.length - 1; index >= 0; index--) {
        try {
          hooks[index].error(hookContexts[index], evaluationError, hints);
        } on Object {
          // Error hooks must not prevent remaining hooks or evaluation.
        }
      }
    }

    for (var index = hooks.length - 1; index >= 0; index--) {
      try {
        hooks[index].finallyAfter(hookContexts[index], details, hints);
      } on Object {
        // Finally hooks must not prevent remaining hooks or evaluation.
      }
    }
    return details;
  }

  FlagEvaluationDetails<T> _errorDetails<T extends Object>(
    String flagKey,
    T defaultValue,
    Object error,
  ) {
    return FlagEvaluationDetails<T>(
      flagKey: flagKey,
      value: defaultValue,
      errorCode: error is OpenFeatureException
          ? error.errorCode
          : ErrorCode.general,
      errorMessage: error.toString(),
      reason: 'ERROR',
    );
  }
}

final class _ProviderRecord {
  _ProviderRecord({required this.initialDomain});

  final String? initialDomain;
  ProviderStatus status = ProviderStatus.notReady;
  int bindingCount = 0;
  StreamSubscription<ProviderEvent>? eventSubscription;
  Completer<ProviderStatus>? terminalEvent;
}
