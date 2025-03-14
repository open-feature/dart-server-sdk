import 'package:logging/logging.dart';
import 'dart:convert';

/// Structured log entry
class StructuredLogEntry {
  final Level level;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic> context;
  final String? error;
  final StackTrace? stackTrace;

  StructuredLogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
    this.context = const {},
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() => {
        'level': level.name,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'context': context,
        if (error != null) 'error': error,
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
      };

  @override
  String toString() => jsonEncode(toJson());
}

/// OpenFeature logger interface
abstract class OpenFeatureLogger {
  void log(StructuredLogEntry entry);
  bool isLevelEnabled(Level level);
}

/// Default logger implementation using package:logging
class DefaultLogger implements OpenFeatureLogger {
  final Logger _logger;
  static final Map<String, DefaultLogger> _loggers = {};

  DefaultLogger._internal(String name) : _logger = Logger(name);

  factory DefaultLogger(String name) {
    return _loggers.putIfAbsent(name, () => DefaultLogger._internal(name));
  }

  @override
  void log(StructuredLogEntry entry) {
    _logger.log(entry.level, entry.message, entry.error, entry.stackTrace);
  }

  @override
  bool isLevelEnabled(Level level) => level >= _logger.level;
}

/// Logger configuration
class LoggerConfig {
  final Level level;
  final void Function(StructuredLogEntry)? customHandler;
  final bool includeStackTraces;

  const LoggerConfig({
    this.level = Level.INFO,
    this.customHandler,
    this.includeStackTraces = true,
  });
}

/// Logger factory
class LoggerFactory {
  static OpenFeatureLogger? _defaultLogger;
  static final Map<String, LoggerConfig> _configs = {};

  static void configure(String name, LoggerConfig config) {
    _configs[name] = config;

    if (_defaultLogger == null && name == 'default') {
      _defaultLogger = DefaultLogger(name);
    }
  }

  static OpenFeatureLogger getLogger(String name) {
    final config = _configs[name] ?? _configs['default'];
    if (config == null) {
      throw StateError('No logger configuration found');
    }

    final logger = DefaultLogger(name);
    hierarchicalLoggingEnabled = true;
    Logger.root.level = config.level;

    if (config.customHandler != null) {
      Logger.root.onRecord.listen((record) {
        final entry = StructuredLogEntry(
          level: record.level,
          message: record.message,
          timestamp: record.time,
          error: record.error?.toString(),
          stackTrace: config.includeStackTraces ? record.stackTrace : null,
          context: {
            'loggerName': record.loggerName,
            'sequenceNumber': record.sequenceNumber,
          },
        );
        config.customHandler!(entry);
      });
    }

    return logger;
  }
}
