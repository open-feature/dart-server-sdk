import 'dart:async';
import 'package:meta/meta.dart';

/// Transaction context holder
class TransactionContext {
  final String transactionId;
  final Map<String, dynamic> attributes;
  final TransactionContext? parent;
  final DateTime createdAt;
  Timer? _cleanupTimer;

  TransactionContext({
    required this.transactionId,
    required this.attributes,
    this.parent,
  }) : createdAt = DateTime.now();

  Map<String, dynamic> get effectiveAttributes {
    final parentAttrs = parent?.effectiveAttributes ?? {};
    return {...parentAttrs, ...attributes};
  }

  void scheduleCleanup(Duration timeout) {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer(timeout, cleanup);
  }

  @mustCallSuper
  void cleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }
}

/// Transaction context manager
class TransactionContextManager {
  static final TransactionContextManager _instance =
      TransactionContextManager._internal();
  final _contexts = <String, TransactionContext>{};
  final _contextStack = <String>[];

  TransactionContextManager._internal();

  factory TransactionContextManager() => _instance;

  TransactionContext? get currentContext {
    if (_contextStack.isEmpty) return null;
    return _contexts[_contextStack.last];
  }

  void pushContext(TransactionContext context, {Duration? timeout}) {
    _contexts[context.transactionId] = context;
    _contextStack.add(context.transactionId);
    context.scheduleCleanup(timeout ?? const Duration(minutes: 5));
  }

  TransactionContext? popContext() {
    if (_contextStack.isEmpty) return null;
    final contextId = _contextStack.removeLast();
    final context = _contexts.remove(contextId);
    context?.cleanup();
    return context;
  }

  void clearContext(String transactionId) {
    final context = _contexts.remove(transactionId);
    if (context != null) {
      _contextStack.remove(transactionId);
      context.cleanup();
    }
  }

  TransactionContext createChildContext(
    String transactionId,
    Map<String, dynamic> attributes,
  ) {
    final parent = currentContext;
    return TransactionContext(
      transactionId: transactionId,
      attributes: attributes,
      parent: parent,
    );
  }

  /// Run code with a specific transaction context
  Future<T> withContext<T>(
    String transactionId,
    Map<String, dynamic> attributes,
    Future<T> Function() operation,
  ) async {
    final context = TransactionContext(
      transactionId: transactionId,
      attributes: attributes,
    );

    pushContext(context);
    try {
      return await operation();
    } finally {
      popContext();
    }
  }

  void cleanup() {
    for (final context in _contexts.values) {
      context.cleanup();
    }
    _contexts.clear();
    _contextStack.clear();
  }
}
