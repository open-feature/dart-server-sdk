<!-- markdownlint-disable MD033 -->
<!-- x-hide-in-docs-start -->
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/open-feature/community/0e23508c163a6a1ac8c0ced3e4bd78faafe627c7/assets/logo/horizontal/white/openfeature-horizontal-white.svg" />
    <img align="center" alt="OpenFeature Logo" src="https://raw.githubusercontent.com/open-feature/community/0e23508c163a6a1ac8c0ced3e4bd78faafe627c7/assets/logo/horizontal/black/openfeature-horizontal-black.svg" />
  </picture>
</p>

<h2 align="center">OpenFeature Dart Server SDK</h2>

<!-- x-hide-in-docs-end -->
<p align="center" class="github-badges">
  <a href="https://github.com/open-feature/spec/releases/tag/v0.8.0">
    <img alt="Specification" src="https://img.shields.io/static/v1?label=specification&message=v0.8.0&color=yellow&style=for-the-badge" />
  </a>
  <!-- x-release-please-start-version -->
  <a href="https://github.com/open-feature/dart-server-sdk/releases/tag/v0.0.17">
    <img alt="Release" src="https://img.shields.io/static/v1?label=release&message=v0.0.17&color=blue&style=for-the-badge" />
  </a>
  <!-- x-release-please-end -->
  <a href="https://dart.dev/">
    <img alt="Built with Dart" src="https://img.shields.io/badge/Built%20with-Dart-blue.svg?style=for-the-badge" />
  </a>

  <br/>

  <a href="https://pub.dev/packages/openfeature_dart_server_sdk">
    <img alt="Pub Version" src="https://img.shields.io/pub/v/openfeature_dart_server_sdk.svg?style=for-the-badge" />
  </a>
  <a href="https://pub.dev/documentation/openfeature_dart_server_sdk/latest/">
    <img alt="API Reference" src="https://img.shields.io/badge/API-reference-blue.svg?style=for-the-badge" />
  </a>
  <a href="https://codecov.io/gh/open-feature/dart-server-sdk">
    <img alt="Code Coverage" src="https://codecov.io/gh/open-feature/dart-server-sdk/branch/main/graph/badge.svg?token=FZ17BHNSU5" />
  </a>
  <a href="https://github.com/open-feature/dart-server-sdk/actions/workflows/validation-workflow.yml">
    <img alt="GitHub CI Status" src="https://github.com/open-feature/dart-server-sdk/actions/workflows/validation-workflow.yml/badge.svg?style=for-the-badge" />
  </a>
</p>

<!-- x-hide-in-docs-start -->

Warning: this repository is still a work in progress.

[OpenFeature](https://openfeature.dev) is an open specification that provides a vendor-neutral API for feature flagging.

<!-- x-hide-in-docs-end -->

## Quick start

### Requirements

Dart SDK: `>=3.10.7 <4.0.0`

> [!NOTE]
> Use the Dart SDK range declared in `pubspec.yaml` as the source of truth.

### Install

<!-- x-release-please-start-version -->
```yaml
dependencies:
  openfeature_dart_server_sdk: ^0.0.17
```
<!-- x-release-please-end -->

Then run:

```sh
dart pub get
```

### Usage

```dart
import 'package:openfeature_dart_server_sdk/evaluation_context.dart';
import 'package:openfeature_dart_server_sdk/feature_provider.dart';
import 'package:openfeature_dart_server_sdk/open_feature_api.dart';

Future<void> main() async {
  final api = OpenFeatureAPI();

  await api.setProviderAndWait(
    InMemoryProvider({
      'new-feature': true,
      'welcome-message': 'Hello, OpenFeature!',
    }),
  );

  api.setGlobalContext(
    OpenFeatureEvaluationContext({
      'region': 'us-east-1',
    }),
  );

  final client = api.getClient('my-app');

  final enabled = await client.getBooleanFlag(
    'new-feature',
    defaultValue: false,
    context: const EvaluationContext(
      attributes: {'userId': 'user-123'},
    ),
  );

  final details = await client.getBooleanDetails(
    'new-feature',
    defaultValue: false,
  );

  print('enabled=$enabled');
  print('reason=${details.reason}');

  final welcomeMessage = await client.getStringFlag(
    'welcome-message',
    defaultValue: 'Welcome!',
  );

  print(welcomeMessage);
}
```

### API reference

See the generated API docs on [pub.dev](https://pub.dev/documentation/openfeature_dart_server_sdk/latest/).

## Current surface area

The package currently exposes:

- `OpenFeatureAPI` for provider registration, global context, hooks, and lifecycle events
- `FeatureClient` for typed flag evaluation and tracking
- `InMemoryProvider` and the `FeatureProvider` / `CachedFeatureProvider` abstractions
- `EvaluationContext` and `TransactionContextManager`
- `OpenFeatureHook` for simple API-level hooks
- `HookManager`, `Hook`, `BaseHook`, and `OpenTelemetryHook` for client-level lifecycle hooks
- `ShutdownManager` for controlled shutdown ordering

## Evaluation context

Global context is set on `OpenFeatureAPI`. Per-call context is passed with `EvaluationContext`.

```dart
import 'package:openfeature_dart_server_sdk/evaluation_context.dart';
import 'package:openfeature_dart_server_sdk/open_feature_api.dart';

final api = OpenFeatureAPI();

api.setGlobalContext(
  OpenFeatureEvaluationContext({
    'region': 'us-east-1',
    'service': 'checkout',
  }),
);

final client = api.getClient('my-app');

final enabled = await client.getBooleanFlag(
  'feature-flag',
  defaultValue: false,
  context: const EvaluationContext(
    attributes: {
      'userId': 'user-123',
      'plan': 'pro',
    },
  ),
);

print(enabled);
```

## Hooks

The current codebase exposes two hook models.

### API-level hooks with `OpenFeatureHook`

Use `OpenFeatureHook` with `OpenFeatureAPI.addHooks(...)` when you need simple before/after callbacks for every client created by the API singleton.

```dart
import 'package:openfeature_dart_server_sdk/open_feature_api.dart';

class AuditHook extends OpenFeatureHook {
  @override
  void beforeEvaluation(String flagKey, Map<String, dynamic>? context) {
    print('before $flagKey $context');
  }

  @override
  void afterEvaluation(
    String flagKey,
    dynamic result,
    Map<String, dynamic>? context,
  ) {
    print('after $flagKey -> $result');
  }
}

final api = OpenFeatureAPI();
api.addHooks([AuditHook()]);
```

### Client-level lifecycle hooks with `HookManager`

Use `HookManager` and `BaseHook` when you need the full before/after/error/finally lifecycle or want to use the built-in `OpenTelemetryHook`.

```dart
import 'package:openfeature_dart_server_sdk/client.dart';
import 'package:openfeature_dart_server_sdk/evaluation_context.dart';
import 'package:openfeature_dart_server_sdk/feature_provider.dart';
import 'package:openfeature_dart_server_sdk/hooks.dart';

class DebugHook extends BaseHook {
  DebugHook() : super(metadata: const HookMetadata(name: 'DebugHook'));

  @override
  Future<void> before(HookContext context) async {
    print('before ${context.flagKey}');
  }
}

Future<void> main() async {
  final provider = InMemoryProvider({'my-flag': true});
  await provider.initialize();

  final hookManager = HookManager()..addHook(DebugHook());

  final client = FeatureClient(
    metadata: ClientMetadata(name: 'my-app'),
    hookManager: hookManager,
    defaultContext: const EvaluationContext(attributes: {}),
    provider: provider,
  );

  final value = await client.getBooleanFlag(
    'my-flag',
    defaultValue: false,
  );

  print(value);
}
```

## Tracking

Use `FeatureClient.track(...)` to associate an application event with the current evaluation context.

```dart
import 'package:openfeature_dart_server_sdk/evaluation_context.dart';
import 'package:openfeature_dart_server_sdk/feature_provider.dart';
import 'package:openfeature_dart_server_sdk/open_feature_api.dart';

final api = OpenFeatureAPI();
final client = api.getClient('my-app');

await client.track(
  'checkout-completed',
  context: const EvaluationContext(
    attributes: {'userId': 'user-123'},
  ),
  trackingDetails: const TrackingEventDetails(
    value: 99.99,
    attributes: {'currency': 'USD'},
  ),
);
```

## Events

`OpenFeatureAPI.events` currently emits provider lifecycle, provider configuration, and global context events.

```dart
import 'package:openfeature_dart_server_sdk/open_feature_api.dart';
import 'package:openfeature_dart_server_sdk/open_feature_event.dart';

final api = OpenFeatureAPI();

api.events.listen((event) {
  switch (event.type) {
    case OpenFeatureEventType.PROVIDER_READY:
      print('provider ready: ${event.message}');
      break;
    case OpenFeatureEventType.PROVIDER_ERROR:
      print('provider error: ${event.message}');
      break;
    case OpenFeatureEventType.PROVIDER_CONFIGURATION_CHANGED:
      print('provider configuration changed: ${event.message}');
      break;
    case OpenFeatureEventType.PROVIDER_CONTEXT_CHANGED:
      print('global context changed: ${event.message}');
      break;
    case OpenFeatureEventType.PROVIDER_STALE:
      print('provider stale: ${event.message}');
      break;
    case OpenFeatureEventType.PROVIDER_RECONCILING:
      print('provider reconciling: ${event.message}');
      break;
  }
});
```

## Domains

`OpenFeatureAPI.bindClientToProvider(...)` currently records domain bindings and emits a configuration-change event, but `OpenFeatureAPI.getClient(...)` still evaluates against the API's active provider. Treat domain bindings as configuration metadata until per-domain provider routing is implemented.

## Shutdown

Use `shutdownProvider()` to stop the active provider and `dispose()` to close the API streams. If you need ordered shutdown, register those calls with `ShutdownManager`.

```dart
import 'package:openfeature_dart_server_sdk/open_feature_api.dart';
import 'package:openfeature_dart_server_sdk/shutdown_manager.dart';

final api = OpenFeatureAPI();
final shutdownManager = ShutdownManager();

shutdownManager.registerHook(
  ShutdownHook(
    name: 'provider-shutdown',
    phase: ShutdownPhase.PROVIDER_SHUTDOWN,
    execute: () async {
      await api.shutdownProvider();
    },
  ),
);

shutdownManager.registerHook(
  ShutdownHook(
    name: 'api-dispose',
    phase: ShutdownPhase.FINAL_CLEANUP,
    execute: () async {
      await api.dispose();
    },
  ),
);

await shutdownManager.shutdown();
```

## Transaction context propagation

`TransactionContextManager` lets you attach request-scoped attributes that are merged into flag evaluations performed during that transaction.

```dart
import 'package:openfeature_dart_server_sdk/open_feature_api.dart';
import 'package:openfeature_dart_server_sdk/transaction_context.dart';

final api = OpenFeatureAPI();
final client = api.getClient('my-app');
final transactionManager = TransactionContextManager();

await transactionManager.withContext(
  'request-123',
  {'userId': 'user-456', 'region': 'us-west-2'},
  () async {
    final enabled = await client.getBooleanFlag(
      'my-flag',
      defaultValue: false,
    );

    print(enabled);
  },
);
```

## Building a provider

To build a provider, implement `FeatureProvider` directly or extend `CachedFeatureProvider`.

`CachedFeatureProvider` already handles:

- provider metadata and configuration
- provider state transitions via `setState(...)`
- typed cache lookups
- a default no-op `track(...)` implementation

`InMemoryProvider` in [`lib/feature_provider.dart`](./lib/feature_provider.dart) is the reference implementation in this repository.

At a minimum, a provider needs to supply:

- `metadata`, `config`, and `state`
- `initialize()`, `connect()`, and `shutdown()`
- typed evaluation methods for boolean, string, integer, double, and object flags
- optional tracking support through `track(...)`

## Testing

For unit tests, the simplest setup is an `InMemoryProvider` plus a `FeatureClient`.

```dart
import 'package:openfeature_dart_server_sdk/client.dart';
import 'package:openfeature_dart_server_sdk/evaluation_context.dart';
import 'package:openfeature_dart_server_sdk/feature_provider.dart';
import 'package:openfeature_dart_server_sdk/hooks.dart';
import 'package:test/test.dart';

void main() {
  late FeatureClient client;

  setUp(() async {
    final provider = InMemoryProvider({
      'test-flag': true,
      'message': 'hello',
    });

    await provider.initialize();

    client = FeatureClient(
      metadata: ClientMetadata(name: 'test-client'),
      hookManager: HookManager(),
      defaultContext: const EvaluationContext(attributes: {}),
      provider: provider,
    );
  });

  test('evaluates a boolean flag', () async {
    final value = await client.getBooleanFlag(
      'test-flag',
      defaultValue: false,
    );

    expect(value, isTrue);
  });

  test('evaluates a string flag', () async {
    final value = await client.getStringFlag(
      'message',
      defaultValue: 'default',
    );

    expect(value, equals('hello'));
  });
}
```

<!-- x-hide-in-docs-start -->

## Support the project

- Star the repository
- Join the OpenFeature community on [Slack](https://cloud-native.slack.com/archives/C0344AANLA1)
- Visit the [community page](https://openfeature.dev/community/)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for local development and contribution guidelines.

<!-- x-hide-in-docs-end -->
