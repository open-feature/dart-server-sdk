import 'dart:async';
import 'package:logging/logging.dart';

/// Extension configuration
class ExtensionConfig {
  final String id;
  final String version;
  final bool enabled;
  final Map<String, dynamic> settings;
  final List<String> dependencies;
  final Duration? timeout;

  const ExtensionConfig({
    required this.id,
    required this.version,
    this.enabled = true,
    this.settings = const {},
    this.dependencies = const [],
    this.timeout,
  });
}

/// Extension lifecycle states
enum ExtensionState {
  REGISTERED,
  LOADING,
  ACTIVE,
  ERROR,
  DISABLED,
  UNREGISTERED
}

/// Extension metadata
class ExtensionMetadata {
  final String id;
  final String version;
  final String author;
  final String description;
  final List<String> tags;
  final Map<String, String> links;

  const ExtensionMetadata({
    required this.id,
    required this.version,
    required this.author,
    required this.description,
    this.tags = const [],
    this.links = const {},
  });
}

/// Extension event
class ExtensionEvent {
  final String extensionId;
  final ExtensionState state;
  final DateTime timestamp;
  final String? message;
  final Object? error;

  ExtensionEvent({
    required this.extensionId,
    required this.state,
    String? message,
    this.error,
  })  : timestamp = DateTime.now(),
        message = message ?? 'Extension state changed to ${state.name}';
}

/// Abstract extension interface
abstract class Extension {
  ExtensionMetadata get metadata;
  Future<void> initialize(ExtensionConfig config);
  Future<void> start();
  Future<void> stop();
}

/// Extension registry
class ExtensionRegistry {
  final Logger _logger = Logger('ExtensionRegistry');
  final Map<String, Extension> _extensions = {};
  final Map<String, ExtensionConfig> _configs = {};
  final Map<String, ExtensionState> _states = {};

  final StreamController<ExtensionEvent> _eventController =
      StreamController<ExtensionEvent>.broadcast();

  Stream<ExtensionEvent> get events => _eventController.stream;

  Future<void> register(Extension extension, ExtensionConfig config) async {
    final id = extension.metadata.id;

    if (_extensions.containsKey(id)) {
      throw Exception('Extension $id already registered');
    }

    // Validate dependencies
    for (final dep in config.dependencies) {
      if (!_extensions.containsKey(dep)) {
        throw Exception('Dependency $dep not found for extension $id');
      }
    }

    _extensions[id] = extension;
    _configs[id] = config;
    _states[id] = ExtensionState.REGISTERED;
    _emitEvent(id, ExtensionState.REGISTERED);

    if (config.enabled) {
      await _initializeExtension(id);
    }
  }

  Future<void> _initializeExtension(String id) async {
    final extension = _extensions[id]!;
    final config = _configs[id]!;

    try {
      _states[id] = ExtensionState.LOADING;
      _emitEvent(id, ExtensionState.LOADING);

      await extension.initialize(config);
      await extension.start();

      _states[id] = ExtensionState.ACTIVE;
      _emitEvent(id, ExtensionState.ACTIVE);
    } catch (e) {
      _logger.severe('Failed to initialize extension $id', e);
      _states[id] = ExtensionState.ERROR;
      _emitEvent(id, ExtensionState.ERROR, error: e);
      rethrow;
    }
  }

  Future<void> unregister(String id) async {
    final extension = _extensions[id];
    if (extension == null) return;

    try {
      if (_states[id] == ExtensionState.ACTIVE) {
        await extension.stop();
      }

      _extensions.remove(id);
      _configs.remove(id);
      _states.remove(id);
      _emitEvent(id, ExtensionState.UNREGISTERED);
    } catch (e) {
      _logger.severe('Error unregistering extension $id', e);
      rethrow;
    }
  }

  Future<void> enableExtension(String id) async {
    final config = _configs[id];
    if (config == null) return;

    _configs[id] = ExtensionConfig(
      id: config.id,
      version: config.version,
      enabled: true,
      settings: config.settings,
      dependencies: config.dependencies,
      timeout: config.timeout,
    );

    await _initializeExtension(id);
  }

  Future<void> disableExtension(String id) async {
    final extension = _extensions[id];
    if (extension == null) return;

    try {
      await extension.stop();
      _states[id] = ExtensionState.DISABLED;
      _emitEvent(id, ExtensionState.DISABLED);
    } catch (e) {
      _logger.severe('Error disabling extension $id', e);
      rethrow;
    }
  }

  Future<void> updateConfig(String id, Map<String, dynamic> settings) async {
    final config = _configs[id];
    if (config == null) return;

    final newConfig = ExtensionConfig(
      id: config.id,
      version: config.version,
      enabled: config.enabled,
      settings: {...config.settings, ...settings},
      dependencies: config.dependencies,
      timeout: config.timeout,
    );

    _configs[id] = newConfig;

    if (config.enabled) {
      await _initializeExtension(id);
    }
  }

  Extension? getExtension(String id) => _extensions[id];
  ExtensionConfig? getConfig(String id) => _configs[id];
  ExtensionState? getState(String id) => _states[id];
  List<String> getRegisteredExtensions() => List.unmodifiable(_extensions.keys);

  void _emitEvent(String id, ExtensionState state, {Object? error}) {
    _eventController.add(ExtensionEvent(
      extensionId: id,
      state: state,
      error: error,
    ));
  }

  Future<void> dispose() async {
    for (final id in _extensions.keys) {
      await unregister(id);
    }
    await _eventController.close();
  }
}
