// Evaluation context definition and merging logic.
// Implementation of the evaluation context for feature flag decisions
// Extends the existing basic context to support hierarchical contexts and targeting rules

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
}

/// Represents a targeting rule for feature flag evaluation
class TargetingRule {
  final String attribute;
  final TargetingOperator operator;
  final dynamic value;
  final Map<String, dynamic>? metadata;

  const TargetingRule(
    this.attribute,
    this.operator,
    this.value, {
    this.metadata,
  });

  /// Evaluate the rule against a context
  bool evaluate(Map<String, dynamic> context) {
    final attributeValue = context[attribute];
    if (attributeValue == null) return false;

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
    }
  }
}

/// Evaluation context with enhanced targeting capabilities
class EvaluationContext {
  final Map<String, dynamic> attributes;
  final EvaluationContext? parent;
  final List<TargetingRule> rules;

  const EvaluationContext({
    required this.attributes,
    this.parent,
    this.rules = const [],
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
    );
  }

  /// Evaluate all targeting rules
  bool evaluateRules() {
    // First evaluate parent rules if they exist
    if (parent != null && !parent!.evaluateRules()) {
      return false;
    }

    // Then evaluate this context's rules
    for (final rule in rules) {
      if (!rule.evaluate(attributes)) {
        return false;
      }
    }
    return true;
  }

  /// Create a child context
  EvaluationContext createChild(
    Map<String, dynamic> childAttributes, {
    List<TargetingRule>? childRules,
  }) {
    return EvaluationContext(
      attributes: childAttributes,
      parent: this,
      rules: childRules ?? [],
    );
  }
}

/// Factory for creating common targeting rules
class TargetingRuleBuilder {
  static TargetingRule equals(String attribute, dynamic value) {
    return TargetingRule(attribute, TargetingOperator.EQUALS, value);
  }

  static TargetingRule notEquals(String attribute, dynamic value) {
    return TargetingRule(attribute, TargetingOperator.NOT_EQUALS, value);
  }

  static TargetingRule contains(String attribute, String value) {
    return TargetingRule(attribute, TargetingOperator.CONTAINS, value);
  }

  static TargetingRule inList(String attribute, List<dynamic> values) {
    return TargetingRule(attribute, TargetingOperator.IN_LIST, values);
  }
}
