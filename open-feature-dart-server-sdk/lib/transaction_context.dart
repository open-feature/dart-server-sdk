class TransactionContext {
  final String id; // Unique identifier for the transaction context
  final Map<String, dynamic> attributes;

  TransactionContext(this.id, this.attributes);

  /// Merge this context with another context
  TransactionContext merge(TransactionContext other) {
    return TransactionContext(id, {...attributes, ...other.attributes});
  }

  /// Get a specific attribute from the context
  dynamic get(String key) {
    return attributes[key];
  }

  /// Set an attribute in the context
  void set(String key, dynamic value) {
    attributes[key] = value;
  }

  /// Clear all attributes (for transaction completion)
  void clear() {
    attributes.clear();
  }
}
