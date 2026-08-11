import 'dart:async';
import 'dart:collection';

import '../feature_provider.dart';
import '../provider_lifecycle.dart';

typedef ProviderLifecycleEventHandler =
    void Function(FeatureProvider provider, ProviderLifecycleEvent event);

/// Coordinates provider lifecycle by provider instance.
///
/// Providers implementing [ProviderEventSource] own their lifecycle events.
/// Providers without that capability are supported by a deprecated compatibility
/// path that derives ready/error events from lifecycle return values and state.
class ProviderLifecycleManager {
  static const Duration _lifecycleEventTimeout = Duration(seconds: 1);

  final ProviderLifecycleEventHandler _onProviderEvent;
  final HashMap<FeatureProvider, _ProviderLifecycleRecord> _records =
      HashMap.identity();

  ProviderLifecycleManager(this._onProviderEvent);

  _ProviderLifecycleRecord _recordFor(FeatureProvider provider) {
    return _records.putIfAbsent(provider, () {
      final record = _ProviderLifecycleRecord(
        status: _normalizeState(provider.state),
        usesLegacyLifecycle: provider is! ProviderEventSource,
      );

      if (provider case final ProviderEventSource eventSource) {
        record.eventSubscription = eventSource.providerEvents.listen(
          (event) => _handleProviderEvent(provider, record, event),
        );
      }

      return record;
    });
  }

  ProviderState statusOf(FeatureProvider provider) =>
      _recordFor(provider).status;

  bool usesLegacyLifecycle(FeatureProvider provider) =>
      _recordFor(provider).usesLegacyLifecycle;

  /// Starts lifecycle tracking without relying on a status lookup for its
  /// side effect.
  void track(FeatureProvider provider) {
    _recordFor(provider);
  }

  void bindDefault(FeatureProvider provider) {
    _recordFor(provider).defaultBinding = true;
  }

  void bindDomain(FeatureProvider provider, String domain) {
    final record = _recordFor(provider);
    if (provider is DomainScopedProvider &&
        record.domains.isNotEmpty &&
        !record.domains.contains(domain)) {
      throw ProviderException(
        'Domain-scoped provider ${provider.metadata.name} is already bound to '
        '${record.domains.first}.',
        code: ErrorCode.INVALID_CONTEXT,
        details: {'domain': domain, 'boundDomains': record.domains.toList()},
      );
    }
    record.domains.add(domain);
  }

  Future<void> unbindDefault(FeatureProvider provider) async {
    final record = _recordFor(provider);
    record.defaultBinding = false;
    await _shutdownAfterFinalUse(provider, record);
  }

  Future<void> unbindDomain(FeatureProvider provider, String domain) async {
    final record = _recordFor(provider);
    record.domains.remove(domain);
    await _shutdownAfterFinalUse(provider, record);
  }

  Future<void> initialize(FeatureProvider provider) {
    final record = _recordFor(provider);
    if (record.status == ProviderState.READY &&
        (!record.usesLegacyLifecycle || record.lifecycleObserved)) {
      return Future.value();
    }

    final activeInitialization = record.initialization;
    if (activeInitialization != null) {
      return activeInitialization;
    }

    final initialization = record.usesLegacyLifecycle
        ? _initializeLegacyProvider(provider, record)
        : _initializeEventProvider(provider, record);
    record.initialization = initialization;
    return initialization.whenComplete(() {
      record.initialization = null;
    });
  }

  Future<void> _initializeLegacyProvider(
    FeatureProvider provider,
    _ProviderLifecycleRecord record,
  ) async {
    var errorEventEmitted = false;
    try {
      if (_normalizeState(provider.state) == ProviderState.NOT_READY) {
        await provider.initialize();
      }

      record.status = _normalizeState(provider.state);
      if (record.status == ProviderState.READY) {
        _onProviderEvent(
          provider,
          ProviderLifecycleEvent(
            ProviderLifecycleEventType.PROVIDER_READY,
            'Provider ready: ${provider.name}',
          ),
        );
        record.lifecycleObserved = true;
        return;
      }

      final errorCode = _errorCodeForState(record.status);
      record.status = errorCode == ErrorCode.PROVIDER_FATAL
          ? ProviderState.FATAL
          : ProviderState.ERROR;
      _onProviderEvent(
        provider,
        ProviderLifecycleEvent(
          ProviderLifecycleEventType.PROVIDER_ERROR,
          'Provider not ready: ${provider.name}',
          data: {'state': record.status.name, 'legacyLifecycle': true},
          errorCode: errorCode,
        ),
      );
      record.lifecycleObserved = true;
      errorEventEmitted = true;
      throw ProviderException(
        'Provider failed to reach READY state: ${record.status.name}',
        code: errorCode ?? ErrorCode.PROVIDER_NOT_READY,
      );
    } catch (error) {
      if (!errorEventEmitted) {
        record.status = _statusForError(error, provider.state);
        _onProviderEvent(
          provider,
          ProviderLifecycleEvent(
            ProviderLifecycleEventType.PROVIDER_ERROR,
            'Provider initialization failed: ${provider.name}',
            data: {'error': error, 'legacyLifecycle': true},
            errorCode: _errorCodeForError(error, record.status),
          ),
        );
        record.lifecycleObserved = true;
      }
      rethrow;
    }
  }

  Future<void> _initializeEventProvider(
    FeatureProvider provider,
    _ProviderLifecycleRecord record,
  ) async {
    if (_normalizeState(provider.state) != ProviderState.NOT_READY) {
      throw ProviderException(
        'Provider is not ready for initialization: ${record.status.name}',
        code: _errorCodeForState(record.status) ?? ErrorCode.PROVIDER_NOT_READY,
      );
    }

    final signal = Completer<ProviderLifecycleEvent>();
    record.initializationSignal = signal;

    Object? initializationError;
    StackTrace? initializationStack;
    try {
      await provider.initialize();
    } catch (error, stackTrace) {
      initializationError = error;
      initializationStack = stackTrace;
    }

    ProviderLifecycleEvent event;
    try {
      event = await signal.future.timeout(_lifecycleEventTimeout);
    } on TimeoutException {
      Error.throwWithStackTrace(
        ProviderException(
          'Provider ${provider.metadata.name} did not emit a lifecycle event '
          'within ${_lifecycleEventTimeout.inMilliseconds}ms of '
          'initialization.',
          code: ErrorCode.GENERAL,
          details: {
            'expected': initializationError == null
                ? ProviderLifecycleEventType.PROVIDER_READY.name
                : ProviderLifecycleEventType.PROVIDER_ERROR.name,
            if (initializationError != null)
              'initializationError': initializationError,
          },
        ),
        initializationStack ?? StackTrace.current,
      );
    } finally {
      if (identical(record.initializationSignal, signal)) {
        record.initializationSignal = null;
      }
    }
    if (initializationError != null) {
      if (event.type != ProviderLifecycleEventType.PROVIDER_ERROR) {
        throw ProviderException(
          'Provider ${provider.metadata.name} emitted ${event.type.name} after '
          'initialization failed.',
          code: ErrorCode.GENERAL,
        );
      }
      Error.throwWithStackTrace(
        initializationError,
        initializationStack ?? StackTrace.current,
      );
    }

    if (event.type != ProviderLifecycleEventType.PROVIDER_READY ||
        record.status != ProviderState.READY) {
      throw ProviderException(
        event.message,
        code:
            event.errorCode ??
            _errorCodeForState(record.status) ??
            ErrorCode.PROVIDER_NOT_READY,
        details: event.data is Map<String, dynamic>
            ? event.data as Map<String, dynamic>
            : null,
      );
    }
  }

  void _handleProviderEvent(
    FeatureProvider provider,
    _ProviderLifecycleRecord record,
    ProviderLifecycleEvent event,
  ) {
    record.status = _statusForEvent(event, record.status);
    record.lifecycleObserved = true;
    final signal = record.initializationSignal;
    if (signal != null &&
        !signal.isCompleted &&
        (event.type == ProviderLifecycleEventType.PROVIDER_READY ||
            event.type == ProviderLifecycleEventType.PROVIDER_ERROR)) {
      signal.complete(event);
    }

    // Status is updated before the API dispatches the event to handlers.
    _onProviderEvent(provider, event);
  }

  Future<void> _shutdownAfterFinalUse(
    FeatureProvider provider,
    _ProviderLifecycleRecord record,
  ) async {
    if (record.defaultBinding || record.domains.isNotEmpty) {
      return;
    }

    final activeShutdown = record.shutdown;
    if (activeShutdown != null) {
      return activeShutdown;
    }

    final shutdown = _shutdownProvider(provider, record);
    record.shutdown = shutdown;
    await shutdown.whenComplete(() {
      record.shutdown = null;
    });
  }

  Future<void> _shutdownProvider(
    FeatureProvider provider,
    _ProviderLifecycleRecord record,
  ) async {
    try {
      await provider.shutdown();
      // Shutdown is the one lifecycle transition inferred by the SDK in v0.9.
      record.status = ProviderState.NOT_READY;
    } finally {
      await record.eventSubscription?.cancel();
      record.eventSubscription = null;
      record.lifecycleObserved = false;
      if (identical(_records[provider], record)) {
        _records.remove(provider);
      }
    }
  }

  Future<void> dispose() async {
    for (final record in _records.values) {
      await record.eventSubscription?.cancel();
    }
    _records.clear();
  }

  static ProviderState _normalizeState(ProviderState state) {
    return switch (state) {
      ProviderState.SHUTDOWN => ProviderState.NOT_READY,
      ProviderState.PLUGIN_ERROR => ProviderState.ERROR,
      _ => state,
    };
  }

  static ProviderState _statusForEvent(
    ProviderLifecycleEvent event,
    ProviderState currentStatus,
  ) {
    return switch (event.type) {
      ProviderLifecycleEventType.PROVIDER_READY => ProviderState.READY,
      ProviderLifecycleEventType.PROVIDER_ERROR =>
        event.errorCode == ErrorCode.PROVIDER_FATAL
            ? ProviderState.FATAL
            : ProviderState.ERROR,
      ProviderLifecycleEventType.PROVIDER_STALE => ProviderState.STALE,
      ProviderLifecycleEventType.PROVIDER_CONTEXT_CHANGED =>
        ProviderState.READY,
      ProviderLifecycleEventType.PROVIDER_RECONCILING =>
        ProviderState.SYNCHRONIZING,
      ProviderLifecycleEventType.PROVIDER_CONFIGURATION_CHANGED =>
        currentStatus,
    };
  }

  static ProviderState _statusForError(Object error, ProviderState state) {
    if (error is ProviderException && error.code == ErrorCode.PROVIDER_FATAL) {
      return ProviderState.FATAL;
    }
    final normalized = _normalizeState(state);
    return normalized == ProviderState.FATAL
        ? ProviderState.FATAL
        : ProviderState.ERROR;
  }

  static ErrorCode? _errorCodeForState(ProviderState state) {
    return switch (state) {
      ProviderState.FATAL => ErrorCode.PROVIDER_FATAL,
      ProviderState.READY => null,
      _ => ErrorCode.PROVIDER_NOT_READY,
    };
  }

  static ErrorCode _errorCodeForError(Object error, ProviderState state) {
    if (error is ProviderException) {
      return error.code;
    }
    return _errorCodeForState(state) ?? ErrorCode.GENERAL;
  }
}

class _ProviderLifecycleRecord {
  ProviderState status;
  final bool usesLegacyLifecycle;
  bool lifecycleObserved = false;
  bool defaultBinding = false;
  final Set<String> domains = {};
  StreamSubscription<ProviderLifecycleEvent>? eventSubscription;
  Completer<ProviderLifecycleEvent>? initializationSignal;
  Future<void>? initialization;
  Future<void>? shutdown;

  _ProviderLifecycleRecord({
    required this.status,
    required this.usesLegacyLifecycle,
  });
}
