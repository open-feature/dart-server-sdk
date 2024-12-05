// Evaluation context definition and merging logic.
// Implementation of the evaluation context for feature flag decisions
// Extends the existing basic context to support hierarchical contexts and targeting rules

/// Represents a structure for holding targeting attributes and rules
class TargetingRule {
  final String attribute; // The attribute to evaluate
  final String operator; // The comparison operator (equals, contains,)
  final dynamic value; // Value to compare against

  TargetingRule(this.attribute, this.operator, this.value);

  ///Evaluates if the rule matches given context
  bool evaluate(Map<String, dynamic> context) {
    final attributeValue = context[attribute];
    switch (operator) {
      case 'equals':
        return attributeValue == value;
      case 'contains':
        return attributeValue?.contains(value) ?? false;
      case 'startsWith':
        return attributeValue?.startsWith(value) ?? false;
      default:
        return false;
    }
  }
}

/// Enhanced evaluation context with support for hierarchical relationships
/// and targeting rule evaluation
class EvaluationContext {
  final Map<String, dynamic> attributes;
  final EvaluationContext? parent; // Support for hierarchical contexts
  final List<TargetingRule> rules; // Targeting rules for this context

  EvaluationContext({
    required this.attributes,
    this.parent,
    this.rules = const [],
  });

  //Get an attribute value, checking parent context if not found
  dynamic getAttribute(String Key) {
    return attributes[Key] ?? parent?.getAttribute(Key);
  }

  /// Merge this context with another, creating a new context
  EvaluationContext merge(EvaluationContext other) {
    return EvaluationContext(
      attributes: {...attributes, ...other.attributes},
      parent: parent,
      rules: [...rules, ...other.rules],
    );
  }

  /// Evaluate all targeting rules against this context
  bool evaluateRules() {
    for (var rule in rules) {
      if (!rule.evaluate(attributes)) {
        return false;
      }
    }
    return true;
  }

  /// Create a child context with additional attributes
  EvaluationContext createChild(Map<String, dynamic> childAttributes) {
    return EvaluationContext(
      attributes: childAttributes,
      parent: this,
      rules: rules,
    );
  }
}

/// Factory for creating common targeting rules
class TargetRuleFactory {
  static TargetingRule equalTo(String attribute, dynamic value) {
    return TargetingRule(attribute, 'equals', value);
  }

  static TargetingRule contains(String attribute, dynamic value) {
    return TargetingRule(attribute, 'contains', value);
  }
}
