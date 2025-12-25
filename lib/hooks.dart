// Hook interface with OpenTelemetry support
import 'dart:async';
import 'dart:convert';
import 'client.dart';
import 'feature_provider.dart';

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

  EvaluationDetails({
    required this.flagKey,
    required this.value,
    this.variant,
    this.reason = 'DEFAULT',
    required this.evaluationTime,
    this.additionalDetails,
  });
}

/// Context passed to hooks during execution
class HookContext {
  final String flagKey;
  final Map<String, dynamic>? evaluationContext;
  final dynamic result;
  final Exception? error;
  final Map<String, dynamic> metadata;
  final ClientMetadata? clientMetadata;
  final ProviderMetadata? providerMetadata;

  HookContext({
    required this.flagKey,
    this.evaluationContext,
    this.result,
    this.error,
    this.metadata = const {},
    this.clientMetadata,
    this.providerMetadata,
  });
}

/// Optional hints for hook execution
class HookHints {
  final Map<String, dynamic> hints;

  const HookHints({this.hints = const {}});
}

/// Interface for implementing hooks
abstract class Hook {
  /// Hook metadata and configuration
  HookMetadata get metadata;

  /// Before flag evaluation
  Future<void> before(HookContext context);

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
  final bool _failFast;
  final Duration _defaultTimeout;

  HookManager({
    bool failFast = false,
    Duration defaultTimeout = const Duration(seconds: 5),
  }) : _failFast = failFast,
       _defaultTimeout = defaultTimeout;

  /// Register a new hook
  void addHook(Hook hook) {
    _hooks.add(hook);
    _sortHooks();
  }

  /// Execute hooks for a specific stage
  Future<void> executeHooks(
    HookStage stage,
    String flagKey,
    Map<String, dynamic>? context, {
    dynamic result,
    Exception? error,
    EvaluationDetails? evaluationDetails,
    HookHints? hints,
    ClientMetadata? clientMetadata,
    ProviderMetadata? providerMetadata,
  }) async {
    final hookContext = HookContext(
      flagKey: flagKey,
      evaluationContext: context,
      result: result,
      error: error,
      clientMetadata: clientMetadata,
      providerMetadata: providerMetadata,
    );

    for (final hook in _hooks) {
      try {
        await _executeHookWithTimeout(
          hook,
          stage,
          hookContext,
          hook.metadata.config.timeout,
          evaluationDetails,
          hints,
        );
      } catch (e) {
        if (_failFast || !hook.metadata.config.continueOnError) {
          rethrow;
        }
        print('Error in ${hook.metadata.name} hook: $e');
      }
    }
  }

  /// Sort hooks by priority
  void _sortHooks() {
    _hooks.sort(
      (a, b) => a.metadata.priority.index.compareTo(b.metadata.priority.index),
    );
  }

  /// Execute a single hook with timeout
  Future<void> _executeHookWithTimeout(
    Hook hook,
    HookStage stage,
    HookContext context,
    Duration? timeout,
    EvaluationDetails? evaluationDetails,
    HookHints? hints,
  ) async {
    final effectiveTimeout = timeout ?? _defaultTimeout;

    Future<void> hookExecution;
    switch (stage) {
      case HookStage.BEFORE:
        hookExecution = hook.before(context);
        break;
      case HookStage.AFTER:
        hookExecution = hook.after(context);
        break;
      case HookStage.ERROR:
        hookExecution = hook.error(context);
        break;
      case HookStage.FINALLY:
        hookExecution = hook.finally_(context, evaluationDetails, hints);
        break;
    }

    await hookExecution.timeout(
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
  Future<void> before(HookContext context) async {}

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
