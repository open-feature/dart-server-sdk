import 'dart:collection';

/// Copies the v0.9.0 context value model into an immutable Dart structure.
/// Null is supported inside structured values, as in JSON, but not as a
/// top-level custom field. Collections must be acyclic and maps string-keyed.
Map<String, dynamic> snapshotContextMap(
  Map<String, dynamic> attributes, {
  bool validateTargetingKey = true,
}) {
  final ancestors = HashSet<Object>.identity();

  dynamic copy(dynamic value, {bool structured = false}) {
    if (value is bool || value is String || value is num || value is DateTime) {
      return value;
    }
    if (value == null && structured) return null;
    if (value is Map || value is List) {
      if (!ancestors.add(value as Object)) {
        throw ArgumentError('Evaluation context structures must be acyclic.');
      }
      try {
        if (value is Map) {
          final result = <String, dynamic>{};
          for (final entry in value.entries) {
            if (entry.key is! String) {
              throw ArgumentError(
                'Evaluation context map keys must be strings.',
              );
            }
            result[entry.key as String] = copy(entry.value, structured: true);
          }
          return Map<String, dynamic>.unmodifiable(result);
        }
        return List<dynamic>.unmodifiable(
          (value as List).map((item) => copy(item, structured: true)),
        );
      } finally {
        ancestors.remove(value);
      }
    }
    throw ArgumentError(
      'Unsupported evaluation context value type: '
      '${value.runtimeType}.',
    );
  }

  final result = <String, dynamic>{};
  for (final entry in attributes.entries) {
    if (validateTargetingKey &&
        entry.key == 'targetingKey' &&
        entry.value is! String) {
      throw ArgumentError('The targeting key must be a string.');
    }
    result[entry.key] = copy(entry.value);
  }
  return Map<String, dynamic>.unmodifiable(result);
}
