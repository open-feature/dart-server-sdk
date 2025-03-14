// Evaluation context definition and merging logic.
// Implementation of the evaluation context for feature flag decisions
// Extends the existing basic context to support hierarchical contexts and targeting rules

import 'dart:collection';

/// Represents a targeting rule operator
enum TargetingOperator {
  EQUALS,
  NOT_EQUALS,
  CONTAINS,
  NOT_CONTAINS,
  STARTS_WITH,
  ENDS_WITH,
  GREATER_THAN,
  LESS_THAN,
  IN_LIST,
  NOT_IN_LIST,
  MATCHES_REGEX,
  VERSION_GREATER_THAN,
  VERSION_LESS_THAN,
  SEMANTIC_VERSION_MATCH
}

/// Cache entry for evaluation results
class EvaluationCacheEntry {
  final dynamic result;
  final DateTime expiresAt;
  final String contextHash;

  EvaluationCacheEntry({
    required this.result,
    required this.expiresAt,
    required this.contextHash,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Represents a targeting rule for feature flag evaluation
class TargetingRule {
  final String attribute;
  final TargetingOperator operator;
  final dynamic value;
  final Map<String, dynamic>? metadata;
  final List<TargetingRule> subRules;

  const TargetingRule(
    this.attribute,
    this.operator,
    this.value, {
    this.metadata,
    this.subRules = const [],
  });

  /// Evaluate the rule against a context
  bool evaluate(Map<String, dynamic> context) {
    final attributeValue = context[attribute];
    if (attributeValue == null) return false;

    bool result = _evaluateCore(attributeValue);

    // Evaluate sub-rules if they exist
    if (result && subRules.isNotEmpty) {
      return subRules.every((rule) => rule.evaluate(context));
    }

    return result;
  }

  bool _evaluateCore(dynamic attributeValue) {
    switch (operator) {
      case TargetingOperator.EQUALS:
        return attributeValue == value;
      case TargetingOperator.NOT_EQUALS:
        return attributeValue != value;
      case TargetingOperator.CONTAINS:
        return attributeValue.toString().contains(value.toString());
      case TargetingOperator.NOT_CONTAINS:
        return !attributeValue.toString().contains(value.toString());
      case TargetingOperator.STARTS_WITH:
        return attributeValue.toString().startsWith(value.toString());
      case TargetingOperator.ENDS_WITH:
        return attributeValue.toString().endsWith(value.toString());
      case TargetingOperator.GREATER_THAN:
        return (attributeValue as num) > (value as num);
      case TargetingOperator.LESS_THAN:
        return (attributeValue as num) < (value as num);
      case TargetingOperator.IN_LIST:
        return (value as List).contains(attributeValue);
      case TargetingOperator.NOT_IN_LIST:
        return !(value as List).contains(attributeValue);
      case TargetingOperator.MATCHES_REGEX:
        return RegExp(value.toString()).hasMatch(attributeValue.toString());
      case TargetingOperator.VERSION_GREATER_THAN:
        return _compareVersions(attributeValue.toString(), value.toString()) >
            0;
      case TargetingOperator.VERSION_LESS_THAN:
        return _compareVersions(attributeValue.toString(), value.toString()) <
            0;
      case TargetingOperator.SEMANTIC_VERSION_MATCH:
        return _matchSemanticVersion(
            attributeValue.toString(), value.toString());
    }
  }

  int _compareVersions(String v1, String v2) {
    var v1Parts = v1.split('.');
    var v2Parts = v2.split('.');

    for (var i = 0; i < v1Parts.length && i < v2Parts.length; i++) {
      var v1Part = int.parse(v1Parts[i]);
      var v2Part = int.parse(v2Parts[i]);
      if (v1Part != v2Part) return v1Part.compareTo(v2Part);
    }
    return v1Parts.length.compareTo(v2Parts.length);
  }

  bool _matchSemanticVersion(String version, String pattern) {
    return RegExp(pattern).hasMatch(version);
  }
}

/// Cache manager for evaluation results
class _EvaluationCache {
  static const maxSize = 1000;
  final _cache = LinkedHashMap<String, EvaluationCacheEntry>();

  dynamic get(String key) {
    final entry = _cache[key];
    if (entry == null || entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    return entry.result;
  }

  void set(String key, dynamic value, Duration ttl) {
    if (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first);
    }

    _cache[key] = EvaluationCacheEntry(
      result: value,
      expiresAt: DateTime.now().add(ttl),
      contextHash: key,
    );
  }

  void clear() => _cache.clear();
}

/// Evaluation context with enhanced targeting capabilities
class EvaluationContext {
  final Map<String, dynamic> attributes;
  final EvaluationContext? parent;
  final List<TargetingRule> rules;
  final Duration cacheDuration;
  static final _cache = _EvaluationCache();

  const EvaluationContext({
    required this.attributes,
    this.parent,
    this.rules = const [],
    this.cacheDuration = const Duration(minutes: 5),
  });

  /// Get an attribute value, checking parent context if not found
  dynamic getAttribute(String key) {
    return attributes[key] ?? parent?.getAttribute(key);
  }

  /// Create a new context by merging with another
  EvaluationContext merge(EvaluationContext other) {
    return EvaluationContext(
      attributes: {
        ...parent?.attributes ?? {},
        ...attributes,
        ...other.attributes,
      },
      rules: [...rules, ...other.rules],
      cacheDuration: cacheDuration,
    );
  }

  /// Generate cache key for current context
  String _generateCacheKey() {
    final buffer = StringBuffer();
    void addToKey(EvaluationContext? context) {
      if (context == null) return;
      addToKey(context.parent);
      buffer.write(context.attributes.toString());
      buffer.write(context.rules.toString());
    }

    addToKey(this);
    return buffer.toString();
  }

  /// Evaluate all targeting rules with caching
  Future<bool> evaluateRules() async {
    final cacheKey = _generateCacheKey();

    // Check cache
    final cachedResult = _cache.get(cacheKey);
    if (cachedResult != null) return cachedResult as bool;

    // Evaluate parent rules
    if (parent != null && !await parent!.evaluateRules()) {
      _cache.set(cacheKey, false, cacheDuration);
      return false;
    }

    // Evaluate current rules
    bool result = rules.every((rule) => rule.evaluate(attributes));
    _cache.set(cacheKey, result, cacheDuration);
    return result;
  }

  /// Create a child context
  EvaluationContext createChild(
    Map<String, dynamic> childAttributes, {
    List<TargetingRule>? childRules,
    Duration? childCacheDuration,
  }) {
    return EvaluationContext(
      attributes: childAttributes,
      parent: this,
      rules: childRules ?? [],
      cacheDuration: childCacheDuration ?? cacheDuration,
    );
  }
}
