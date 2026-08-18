import 'immutable.dart';

/// Immutable targeting data used by static-context flag evaluations.
final class EvaluationContext {
  factory EvaluationContext({
    String? targetingKey,
    Map<String, Object?> attributes = const {},
  }) {
    if (attributes.containsKey('targetingKey')) {
      throw ArgumentError.value(
        attributes,
        'attributes',
        'Use the targetingKey parameter for the targeting key',
      );
    }
    return EvaluationContext._(
      targetingKey,
      immutableStructure(attributes, path: 'attributes'),
    );
  }

  const EvaluationContext._(this.targetingKey, this.attributes);

  /// An empty evaluation context.
  static const empty = EvaluationContext._(null, <String, Object?>{});

  /// Identifies the subject of flag evaluation.
  final String? targetingKey;

  /// Custom context fields.
  final Map<String, Object?> attributes;

  /// Returns the custom field for [key].
  Object? getValue(String key) => attributes[key];

  /// Returns all fields, including `targetingKey` when it is set.
  Map<String, Object?> asMap() {
    return Map<String, Object?>.unmodifiable({
      if (targetingKey != null) 'targetingKey': targetingKey,
      ...attributes,
    });
  }
}
