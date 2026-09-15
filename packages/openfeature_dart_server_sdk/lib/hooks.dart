// Hook interface with OpenTelemetry support
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'evaluation_context.dart';
import 'client.dart';
import 'feature_provider.dart';
import 'src/context_snapshot.dart';

/// Defines the stages in the hook lifecycle
/// Used internally by the hook manager for execution ordering
enum HookStage {
  BEFORE, // Before flag evaluation
  AFTER, // After successful evaluation
  ERROR, // When an error occurs
  FINALLY, // Always executed last
}

/// Hook priority levels
enum HookPriority {
  CRITICAL, // Highest priority, executes first
  HIGH, // High priority
  NORMAL, // Default priority
  LOW, // Lowest priority
}

/// Flag value types for hook context
enum FlagValueType { BOOLEAN, STRING, INTEGER, DOUBLE, OBJECT }

/// Configuration for hook behavior
class HookConfig {
  final bool continueOnError;
  final Duration timeout;
  final Map<String, dynamic> customConfig;

  const HookConfig({
    this.continueOnError = true,
    this.timeout = const Duration(seconds: 5),
    this.customConfig = const {},
  });
}

/// Metadata for hook identification and configuration
class HookMetadata {
  final String name;
  final String version;
  final HookPriority priority;
  final HookConfig config;

  const HookMetadata({
    required this.name,
    this.version = '1.0.0',
    this.priority = HookPriority.NORMAL,
    this.config = const HookConfig(),
  });
}

/// Details about the evaluation result
class EvaluationDetails {
  final String flagKey;
  final dynamic value;
  final String? variant;
  final String reason;
  final DateTime evaluationTime;
  final Map<String, dynamic>? additionalDetails;
  final ErrorCode? errorCode;
  final String? errorMessage;
  final Map<String, dynamic> flagMetadata;

  EvaluationDetails({
    required this.flagKey,
    required dynamic value,
    this.variant,
    this.reason = 'DEFAULT',
    required this.evaluationTime,
    Map<String, dynamic>? additionalDetails,
    this.errorCode,
    this.errorMessage,
    Map<String, dynamic> flagMetadata = const {},
  }) : value = _snapshotHookValue(value),
       additionalDetails = additionalDetails == null
           ? null
           : Map.unmodifiable(additionalDetails),
       flagMetadata = _snapshotHookValue(flagMetadata);
}

/// Mutable data container that propagates between hook stages (spec Section 4.6)
/// Hook data allows mutable state to be shared across before/after/error/finally stages
/// within a single flag evaluation lifecycle.
class HookData {
  final Map<String, dynamic> _data = {};
  final Map<Object, HookData> _scopedData = HashMap.identity();

  /// Set a value in hook data
  void set(String key, dynamic value) {
    _data[key] = value;
  }

  /// Get a value from hook data
  dynamic get(String key) => _data[key];

  /// Check if a key exists
  bool containsKey(String key) => _data.containsKey(key);

  /// Remove a key
  dynamic remove(String key) => _data.remove(key);

  /// Get all entries as an unmodifiable map
  Map<String, dynamic> toMap() => Map.unmodifiable(_data);

  HookData _scopeFor(Object scopeKey) =>
      _scopedData.putIfAbsent(scopeKey, HookData.new);
}

/// Context passed to hooks during execution
class HookContext {
  final String flagKey;
  final Map<String, dynamic> evaluationContext;
  final dynamic result;
  final Exception? error;
  final Map<String, dynamic> metadata;
  final ClientMetadata? clientMetadata;
  final ProviderMetadata? providerMetadata;
  final dynamic defaultValue;
  final FlagValueType? flagValueType;
  final HookData hookData;
  final HookHints hints;
  final EvaluationDetails? evaluationDetails;

  HookContext({
    required this.flagKey,
    Map<String, dynamic>? evaluationContext,
    this.result,
    this.error,
    this.metadata = const {},
    this.clientMetadata,
    this.providerMetadata,
    this.defaultValue,
    this.flagValueType,
    HookData? hookData,
    this.hints = const HookHints(),
    this.evaluationDetails,
  }) : evaluationContext = Map.unmodifiable(
         Map<String, dynamic>.from(evaluationContext ?? const {}),
       ),
       hookData = hookData ?? HookData();
}

/// Optional hints for hook execution
class HookHints {
  final Map<String, dynamic> hints;

  /// Legacy constructor; runtime entry points capture an immutable snapshot.
  const HookHints({this.hints = const {}});

  factory HookHints.immutable(Map<String, dynamic> hints) =>
      HookHints(hints: snapshotContextMap(hints, validateTargetingKey: false));

  HookHints snapshot() => HookHints.immutable(hints);
}

/// Interface for implementing hooks
abstract class Hook {
  /// Hook metadata and configuration
  HookMetadata get metadata;

  /// Before flag evaluation.
  ///
  /// Returned context updates are merged into the evaluation context before the
  /// provider is called and before later before hooks execute.
  Future<Map<String, dynamic>?> before(HookContext context);

  /// After successful evaluation
  Future<void> after(HookContext context);

  /// When an error occurs
  Future<void> error(HookContext context);

  /// Always executed at the end, now with evaluation details parameter
  Future<void> finally_(
    HookContext context,
    EvaluationDetails? evaluationDetails, [
    HookHints? hints,
  ]);
}

/// Manager for hook registration and execution
class HookManager {
  final List<Hook> _hooks = [];
  final Duration _defaultTimeout;

  HookManager({Duration defaultTimeout = const Duration(seconds: 5)})
    : _defaultTimeout = defaultTimeout;

  /// Register a new hook
  void addHook(Hook hook) {
    _hooks.add(hook);
  }

  void removeHook(Hook hook) {
    final index = _hooks.indexWhere(
      (registered) => identical(registered, hook),
    );
    if (index >= 0) _hooks.removeAt(index);
  }

  /// Registration order for SDK evaluations; legacy priorities apply only to
  /// direct standalone manager execution.
  List<Hook> get registeredHooks => List.unmodifiable(_hooks);

  /// Execute hooks for a specific stage
  Future<Map<String, dynamic>> executeHooks(
    HookStage stage,
    String flagKey,
    Map<String, dynamic>? context, {
    dynamic result,
    Exception? error,
    EvaluationDetails? evaluationDetails,
    HookHints? hints,
    ClientMetadata? clientMetadata,
    ProviderMetadata? providerMetadata,
    dynamic defaultValue,
    FlagValueType? flagValueType,
    HookData? hookData,
    Iterable<Hook> additionalHooks = const [],
    List<Hook>? executionHooks,
    void Function(Map<String, dynamic>)? onContextChanged,
  }) async {
    var currentContext = snapshotContextMap(context ?? const {});
    final evaluationHookData = hookData ?? HookData();
    final immutableHints = (hints ?? const HookHints()).snapshot();
    for (final hook in _hooksForStage(stage, additionalHooks, executionHooks)) {
      try {
        if (hook is EvaluationHook && !hook.stages.contains(stage)) continue;
        final hookContext = HookContext(
          flagKey: flagKey,
          evaluationContext: currentContext,
          result: _snapshotHookValue(result),
          error: error,
          clientMetadata: clientMetadata,
          providerMetadata: providerMetadata == null
              ? null
              : ProviderMetadata(
                  name: providerMetadata.name,
                  version: providerMetadata.version,
                  attributes: Map.unmodifiable(providerMetadata.attributes),
                ),
          defaultValue: _snapshotHookValue(defaultValue),
          flagValueType: flagValueType,
          hookData: evaluationHookData._scopeFor(hook),
          hints: immutableHints,
          evaluationDetails: evaluationDetails,
        );

        final contextUpdates = await _executeHookWithTimeout(
          hook,
          stage,
          hookContext,
          hook.metadata.config.timeout,
          evaluationDetails,
          hints == null ? null : immutableHints,
        );

        if (stage == HookStage.BEFORE &&
            contextUpdates != null &&
            contextUpdates.isNotEmpty) {
          currentContext = snapshotContextMap({
            ...currentContext,
            ...contextUpdates,
          });
          onContextChanged?.call(currentContext);
        }
      } catch (e) {
        if (stage == HookStage.BEFORE || stage == HookStage.AFTER) {
          rethrow;
        }
        // Error/finally failures cannot suppress remaining cleanup hooks.
      }
    }

    return currentContext;
  }

  List<Hook> _hooksForStage(
    HookStage stage,
    Iterable<Hook> additionalHooks,
    List<Hook>? executionHooks,
  ) {
    final local = [..._hooks];
    if (executionHooks == null) {
      local.sort(
        (a, b) =>
            a.metadata.priority.index.compareTo(b.metadata.priority.index),
      );
    }
    final combined = executionHooks ?? [...local, ...additionalHooks];
    return List.unmodifiable(
      stage == HookStage.BEFORE ? combined : combined.reversed,
    );
  }

  /// Execute a single hook with timeout
  Future<Map<String, dynamic>?> _executeHookWithTimeout(
    Hook hook,
    HookStage stage,
    HookContext context,
    Duration? timeout,
    EvaluationDetails? evaluationDetails,
    HookHints? hints,
  ) async {
    final effectiveTimeout = timeout ?? _defaultTimeout;

    Future<Map<String, dynamic>?> hookExecution;
    switch (stage) {
      case HookStage.BEFORE:
        hookExecution = hook.before(context);
        break;
      case HookStage.AFTER:
        hookExecution = () async {
          await hook.after(context);
          return null;
        }();
        break;
      case HookStage.ERROR:
        hookExecution = () async {
          await hook.error(context);
          return null;
        }();
        break;
      case HookStage.FINALLY:
        hookExecution = () async {
          await hook.finally_(context, evaluationDetails, hints);
          return null;
        }();
        break;
    }

    return await hookExecution.timeout(
      effectiveTimeout,
      onTimeout: () {
        throw TimeoutException(
          'Hook ${hook.metadata.name} timed out after ${effectiveTimeout.inSeconds} seconds',
        );
      },
    );
  }
}

/// A base hook implementation with empty methods
abstract class BaseHook implements Hook {
  @override
  final HookMetadata metadata;

  BaseHook({required this.metadata});

  @override
  Future<Map<String, dynamic>?> before(HookContext context) async => null;

  @override
  Future<void> after(HookContext context) async {}

  @override
  Future<void> error(HookContext context) async {}

  @override
  Future<void> finally_(
    HookContext context,
    EvaluationDetails? evaluationDetails, [
    HookHints? hints,
  ]) async {}
}

/// A lightweight hook that emits structured logs for each lifecycle stage.
class LoggingHook extends BaseHook {
  final void Function(String message)? logger;
  final bool includeContext;
  static const String _circularReferenceMarker = '[Circular]';

  LoggingHook({
    this.logger,
    this.includeContext = false,
    HookPriority priority = HookPriority.NORMAL,
  }) : super(
         metadata: HookMetadata(name: 'LoggingHook', priority: priority),
       );

  Object? _safeJsonValue(dynamic value, [Set<Object>? visited]) {
    final seen = visited ?? Set<Object>.identity();

    if (value == null || value is num || value is bool || value is String) {
      return value;
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    if (value is Duration) {
      return value.inMicroseconds;
    }

    if (value is Enum) {
      return value.name;
    }

    if (value is Map) {
      if (!seen.add(value)) {
        return _circularReferenceMarker;
      }

      final jsonSafeMap = <String, Object?>{};
      value.forEach((key, nestedValue) {
        jsonSafeMap[key.toString()] = _safeJsonValue(nestedValue, seen);
      });
      seen.remove(value);
      return jsonSafeMap;
    }

    if (value is Iterable) {
      if (!seen.add(value)) {
        return _circularReferenceMarker;
      }

      final jsonSafeValues = value
          .map((element) => _safeJsonValue(element, seen))
          .toList(growable: false);
      seen.remove(value);
      return jsonSafeValues;
    }

    return value.toString();
  }

  void _writeLog(String message) {
    if (logger != null) {
      logger!(message);
    } else {
      print(message);
    }
  }

  void _log(String stage, HookContext context, [EvaluationDetails? details]) {
    try {
      final payload = jsonEncode({
        'stage': stage,
        'flagKey': context.flagKey,
        'provider': context.providerMetadata?.name,
        'client': context.clientMetadata?.name,
        if (includeContext)
          'context': _safeJsonValue(context.evaluationContext),
        if (!includeContext && context.evaluationContext.isNotEmpty)
          'contextKeys': context.evaluationContext.keys.toList(growable: false),
        'result': _safeJsonValue(details?.value ?? context.result),
        'reason': details?.reason,
        'error': context.error?.toString(),
      });

      _writeLog(payload);
    } catch (error) {
      final fallbackMessage =
          'LoggingHook failed to serialize log for stage: '
          '$stage, flag: ${context.flagKey}. Error: $error';
      try {
        _writeLog(fallbackMessage);
      } catch (_) {
        // Logging must never interfere with flag evaluation.
      }
    }
  }

  @override
  Future<Map<String, dynamic>?> before(HookContext context) async {
    _log('before', context);
    return null;
  }

  @override
  Future<void> after(HookContext context) async => _log('after', context);

  @override
  Future<void> error(HookContext context) async => _log('error', context);

  @override
  Future<void> finally_(
    HookContext context,
    EvaluationDetails? evaluationDetails, [
    HookHints? hints,
  ]) async => _log('finally', context, evaluationDetails);
}

//
// OpenTelemetry Support
//

/// OpenTelemetry semantic conventions for feature flags
/// Based on https://opentelemetry.io/docs/specs/semconv/feature-flags/feature-flags-spans/
class OTelFeatureFlagConstants {
  /// Common attributes
  static const String FEATURE_FLAG = 'feature_flag';
  static const String FLAG_KEY = 'feature_flag.key';
  static const String FLAG_PROVIDER_NAME = 'feature_flag.provider_name';
  static const String FLAG_VARIANT = 'feature_flag.variant';

  /// Value type specific attributes
  static const String FLAG_EVALUATED = 'feature_flag.evaluated';
  static const String FLAG_VALUE_TYPE = 'feature_flag.value_type';
  static const String FLAG_VALUE_BOOLEAN = 'feature_flag.value.boolean';
  static const String FLAG_VALUE_STRING = 'feature_flag.value.string';
  static const String FLAG_VALUE_INT = 'feature_flag.value.int';
  static const String FLAG_VALUE_FLOAT = 'feature_flag.value.float';

  /// Reason constants
  static const String REASON = 'feature_flag.reason';
  static const String REASON_DEFAULT = 'DEFAULT';
  static const String REASON_TARGETING_MATCH = 'TARGETING_MATCH';
  static const String REASON_SPLIT = 'SPLIT';
  static const String REASON_CACHED = 'CACHED';
  static const String REASON_ERROR = 'ERROR';
  static const String REASON_DISABLED = 'DISABLED';
  static const String REASON_UNKNOWN = 'UNKNOWN';
  static const String REASON_STALE = 'STALE';

  /// Value types
  static const String TYPE_BOOLEAN = 'BOOLEAN';
  static const String TYPE_STRING = 'STRING';
  static const String TYPE_INT = 'INTEGER';
  static const String TYPE_DOUBLE = 'FLOAT';
  static const String TYPE_OBJECT = 'OBJECT';
}

/// Represents an OpenTelemetry attribute
class OTelAttribute {
  final String key;
  final dynamic value;

  const OTelAttribute(this.key, this.value);

  Map<String, dynamic> toJson() => {key: value};
}

/// A collection of OpenTelemetry attributes
class OTelAttributes {
  final List<OTelAttribute> attributes;

  const OTelAttributes(this.attributes);

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    for (final attr in attributes) {
      result.addAll(attr.toJson());
    }
    return result;
  }

  @override
  String toString() => jsonEncode(toJson());
}

/// Utility class for generating OpenTelemetry-compatible telemetry from feature flag evaluations
class OpenTelemetryUtil {
  /// Creates OpenTelemetry-compatible attributes for a feature flag evaluation
  ///
  /// These attributes follow the OpenTelemetry semantic conventions for feature flags.
  /// They can be used with any OpenTelemetry-compatible telemetry system.
  static OTelAttributes createOTelAttributes({
    required String flagKey,
    required dynamic value,
    String? providerName,
    String? variant,
    String reason = OTelFeatureFlagConstants.REASON_DEFAULT,
    Map<String, dynamic>? evaluationContext,
  }) {
    final attributes = <OTelAttribute>[];

    // Add common attributes
    attributes.add(OTelAttribute(OTelFeatureFlagConstants.FLAG_KEY, flagKey));
    attributes.add(
      OTelAttribute(OTelFeatureFlagConstants.FLAG_EVALUATED, true),
    );

    if (providerName != null && providerName.isNotEmpty) {
      attributes.add(
        OTelAttribute(
          OTelFeatureFlagConstants.FLAG_PROVIDER_NAME,
          providerName,
        ),
      );
    }

    if (variant != null && variant.isNotEmpty) {
      attributes.add(
        OTelAttribute(OTelFeatureFlagConstants.FLAG_VARIANT, variant),
      );
    }

    attributes.add(OTelAttribute(OTelFeatureFlagConstants.REASON, reason));

    // Add value and determine type
    if (value != null) {
      if (value is bool) {
        attributes.add(
          OTelAttribute(
            OTelFeatureFlagConstants.FLAG_VALUE_TYPE,
            OTelFeatureFlagConstants.TYPE_BOOLEAN,
          ),
        );
        attributes.add(
          OTelAttribute(OTelFeatureFlagConstants.FLAG_VALUE_BOOLEAN, value),
        );
      } else if (value is String) {
        attributes.add(
          OTelAttribute(
            OTelFeatureFlagConstants.FLAG_VALUE_TYPE,
            OTelFeatureFlagConstants.TYPE_STRING,
          ),
        );
        attributes.add(
          OTelAttribute(OTelFeatureFlagConstants.FLAG_VALUE_STRING, value),
        );
      } else if (value is int) {
        attributes.add(
          OTelAttribute(
            OTelFeatureFlagConstants.FLAG_VALUE_TYPE,
            OTelFeatureFlagConstants.TYPE_INT,
          ),
        );
        attributes.add(
          OTelAttribute(OTelFeatureFlagConstants.FLAG_VALUE_INT, value),
        );
      } else if (value is double) {
        attributes.add(
          OTelAttribute(
            OTelFeatureFlagConstants.FLAG_VALUE_TYPE,
            OTelFeatureFlagConstants.TYPE_DOUBLE,
          ),
        );
        attributes.add(
          OTelAttribute(OTelFeatureFlagConstants.FLAG_VALUE_FLOAT, value),
        );
      } else {
        attributes.add(
          OTelAttribute(
            OTelFeatureFlagConstants.FLAG_VALUE_TYPE,
            OTelFeatureFlagConstants.TYPE_OBJECT,
          ),
        );
        // For non-primitive types, we convert to a string representation
        attributes.add(
          OTelAttribute(
            OTelFeatureFlagConstants.FLAG_VALUE_STRING,
            value.toString(),
          ),
        );
      }
    }

    return OTelAttributes(attributes);
  }

  /// Creates OpenTelemetry-compatible attributes from EvaluationDetails
  ///
  /// This is a convenience method for use in hooks, especially the finally_ hook.
  static OTelAttributes fromEvaluationDetails(
    EvaluationDetails details, {
    String? providerName,
  }) {
    return createOTelAttributes(
      flagKey: details.flagKey,
      value: details.value,
      providerName: providerName,
      variant: details.variant,
      reason: details.reason,
    );
  }

  /// Creates OpenTelemetry-compatible attributes from HookContext
  ///
  /// This is a convenience method for use in hooks when EvaluationDetails is not available.
  static OTelAttributes fromHookContext(
    HookContext context, {
    String? providerName,
    String? reason,
  }) {
    return createOTelAttributes(
      flagKey: context.flagKey,
      value: context.result,
      providerName: providerName,
      reason:
          reason ??
          (context.error != null
              ? OTelFeatureFlagConstants.REASON_ERROR
              : OTelFeatureFlagConstants.REASON_DEFAULT),
      evaluationContext: context.evaluationContext,
    );
  }
}

/// A hook that generates OpenTelemetry-compatible telemetry
class OpenTelemetryHook extends BaseHook {
  final String providerName;
  final void Function(OTelAttributes)? telemetryCallback;

  OpenTelemetryHook({
    required this.providerName,
    this.telemetryCallback,
    HookPriority priority = HookPriority.NORMAL,
  }) : super(
         metadata: HookMetadata(name: 'OpenTelemetryHook', priority: priority),
       );

  @override
  Future<void> finally_(
    HookContext context,
    EvaluationDetails? evaluationDetails, [
    HookHints? hints,
  ]) async {
    // Generate OpenTelemetry attributes
    final otelAttributes = evaluationDetails != null
        ? OpenTelemetryUtil.fromEvaluationDetails(
            evaluationDetails,
            providerName: providerName,
          )
        : OpenTelemetryUtil.fromHookContext(
            context,
            providerName: providerName,
          );

    // Call the telemetry callback if provided
    telemetryCallback?.call(otelAttributes);
  }
}

// Hook-visible structured values are private snapshots. Application fallbacks
// themselves retain identity and are never replaced by these copies.
dynamic _snapshotHookValue(dynamic value) => value is Map || value is List
    ? snapshotContextMap({'value': value})['value']
    : value;

/// Immutable per-invocation hook registration and hints.
class EvaluationOptions {
  final List<Hook> hooks;
  final HookHints hints;
  EvaluationOptions({Iterable<Hook> hooks = const [], HookHints? hints})
    : hooks = List.unmodifiable(hooks),
      hints = (hints ?? const HookHints()).snapshot();
}

typedef BeforeEvaluationHook =
    FutureOr<EvaluationContext?> Function(HookContext context, HookHints hints);
typedef AfterEvaluationHook =
    FutureOr<void> Function(
      HookContext context,
      EvaluationDetails details,
      HookHints hints,
    );
typedef ErrorEvaluationHook =
    FutureOr<void> Function(
      HookContext context,
      Exception error,
      HookHints hints,
    );

/// A hook declaring only its supported stages, with typed stage arguments.
/// Existing Hook/BaseHook implementations remain supported unchanged.
class EvaluationHook extends BaseHook {
  final BeforeEvaluationHook? _before;
  final AfterEvaluationHook? _after;
  final ErrorEvaluationHook? _error;
  final AfterEvaluationHook? _finallyAfter;
  final Set<HookStage> stages;

  EvaluationHook({
    required super.metadata,
    BeforeEvaluationHook? before,
    AfterEvaluationHook? after,
    ErrorEvaluationHook? error,
    AfterEvaluationHook? finallyAfter,
  }) : _before = before,
       _after = after,
       _error = error,
       _finallyAfter = finallyAfter,
       stages = Set.unmodifiable({
         if (before != null) HookStage.BEFORE,
         if (after != null) HookStage.AFTER,
         if (error != null) HookStage.ERROR,
         if (finallyAfter != null) HookStage.FINALLY,
       }) {
    if (stages.isEmpty) {
      throw ArgumentError('A hook must specify at least one stage.');
    }
  }

  @override
  Future<Map<String, dynamic>?> before(HookContext context) async =>
      (await _before?.call(context, context.hints))?.toProviderContext();
  @override
  Future<void> after(HookContext context) async {
    await _after?.call(context, context.evaluationDetails!, context.hints);
  }

  @override
  Future<void> error(HookContext context) async {
    await _error?.call(context, context.error!, context.hints);
  }

  /// Dart spelling of the specification's finally stage.
  Future<void> finallyAfter(
    HookContext context,
    EvaluationDetails details, [
    HookHints? hints,
  ]) async {
    await _finallyAfter?.call(context, details, hints ?? context.hints);
  }

  @override
  Future<void> finally_(
    HookContext context,
    EvaluationDetails? details, [
    HookHints? hints,
  ]) async {
    await finallyAfter(context, details!, hints);
  }
}
