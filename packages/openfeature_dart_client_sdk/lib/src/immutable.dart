Object? immutableValue(Object? value, {String path = 'value'}) {
  if (value == null ||
      value is bool ||
      value is String ||
      value is num ||
      value is DateTime) {
    return value;
  }

  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(
      value.indexed.map(
        (entry) => immutableValue(entry.$2, path: '$path[${entry.$1}]'),
      ),
    );
  }

  if (value is Map) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw ArgumentError.value(key, path, 'Map keys must be strings');
      }
      result[key] = immutableValue(entry.value, path: '$path.$key');
    }
    return Map<String, Object?>.unmodifiable(result);
  }

  throw ArgumentError.value(
    value,
    path,
    'Expected null, bool, String, num, DateTime, List, or Map',
  );
}

Map<String, Object?> immutableStructure(
  Map<String, Object?> value, {
  String path = 'value',
}) {
  return immutableValue(value, path: path)! as Map<String, Object?>;
}

Map<String, Object> immutableMetadata(
  Map<String, Object> value, {
  String path = 'metadata',
}) {
  final result = <String, Object>{};
  for (final entry in value.entries) {
    final metadataValue = entry.value;
    if (metadataValue is! bool &&
        metadataValue is! String &&
        metadataValue is! num) {
      throw ArgumentError.value(
        metadataValue,
        '$path.${entry.key}',
        'Metadata values must be bool, String, or num',
      );
    }
    result[entry.key] = metadataValue;
  }
  return Map<String, Object>.unmodifiable(result);
}
