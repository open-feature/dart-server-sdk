import 'dart:async';
import 'package:logging/logging.dart';

enum ShutdownPhase {
  PRE_SHUTDOWN,
  PROVIDER_SHUTDOWN,
  CACHE_CLEANUP,
  RESOURCE_CLEANUP,
  CONTEXT_CLEANUP,
  EVENT_CLEANUP,
  FINAL_CLEANUP
}

class ShutdownHook {
  final String name;
  final ShutdownPhase phase;
  final Future<void> Function() execute;
  final Duration timeout;
  final bool critical;

  const ShutdownHook({
    required this.name,
    required this.phase,
    required this.execute,
    this.timeout = const Duration(seconds: 5),
    this.critical = false,
  });
}

class ShutdownError implements Exception {
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  ShutdownError(this.message, [this.error, this.stackTrace]);

  @override
  String toString() =>
      'ShutdownError: $message${error != null ? ' - $error' : ''}';
}

class ShutdownManager {
  static final Logger _logger = Logger('ShutdownManager');
  final Map<ShutdownPhase, List<ShutdownHook>> _hooks = {};
  final _shutdownController = StreamController<ShutdownPhase>.broadcast();
  bool _isShuttingDown = false;
  bool _isShutdown = false;

  ShutdownManager() {
    for (var phase in ShutdownPhase.values) {
      _hooks[phase] = [];
    }
  }

  Stream<ShutdownPhase> get shutdownEvents => _shutdownController.stream;

  void registerHook(ShutdownHook hook) {
    if (_isShuttingDown || _isShutdown) {
      throw StateError('Cannot register hooks during shutdown');
    }
    _hooks[hook.phase]!.add(hook);
    _hooks[hook.phase]!.sort((a, b) => b.critical ? 1 : -1);
  }

  Future<void> _executePhase(ShutdownPhase phase) async {
    _logger.info('Executing shutdown phase: ${phase.name}');
    _shutdownController.add(phase);

    final hooks = _hooks[phase]!;
    final errors = <ShutdownError>[];

    for (final hook in hooks) {
      try {
        await hook.execute().timeout(
          hook.timeout,
          onTimeout: () {
            throw TimeoutException(
                'Hook ${hook.name} timed out after ${hook.timeout.inSeconds}s');
          },
        );
      } catch (e, stack) {
        _logger.severe('Error executing shutdown hook ${hook.name}', e, stack);
        errors.add(ShutdownError('Hook ${hook.name} failed', e, stack));

        if (hook.critical) {
          rethrow;
        }
      }
    }

    if (errors.isNotEmpty) {
      throw ShutdownError(
          'Phase $phase completed with ${errors.length} errors', errors);
    }
  }

  Future<void> shutdown() async {
    if (_isShutdown) return;
    if (_isShuttingDown) {
      throw StateError('Shutdown already in progress');
    }

    _isShuttingDown = true;
    _logger.info('Starting shutdown sequence');

    try {
      for (var phase in ShutdownPhase.values) {
        await _executePhase(phase);
      }

      _isShutdown = true;
      _logger.info('Shutdown complete');
    } catch (e, stack) {
      _logger.severe('Shutdown failed', e, stack);
      rethrow;
    } finally {
      await _shutdownController.close();
    }
  }

  Future<void> emergencyShutdown() async {
    _logger.warning('Emergency shutdown initiated');
    _isShuttingDown = true;

    try {
      for (var phase in ShutdownPhase.values) {
        final criticalHooks = _hooks[phase]!.where((h) => h.critical);
        for (final hook in criticalHooks) {
          try {
            await hook.execute().timeout(const Duration(seconds: 1));
          } catch (e) {
            _logger.severe(
                'Critical hook ${hook.name} failed during emergency shutdown',
                e);
          }
        }
      }
    } finally {
      _isShutdown = true;
      await _shutdownController.close();
    }
  }
}
