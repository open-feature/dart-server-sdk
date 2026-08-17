# OpenFeature Dart Client SDK

This package is the vendor-neutral OpenFeature SDK for Dart client
applications. It uses the static-context paradigm. It has no Flutter or
`dart:io` dependency.

The package is in beta. The first beta defines the public client and provider
contracts. It provides synchronous typed evaluation, hooks, ordered context
changes, and an in-memory provider. Later beta changes will complete event
handlers and the remaining conformance work before the first stable release.

## Use the client

```dart
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';

Future<void> main() async {
  final provider = InMemoryProvider({
    'new-checkout': true,
    'welcome-message': 'Hello',
  });

  await OpenFeatureAPI.instance.setProviderAndWait(provider);
  await OpenFeatureAPI.instance.setEvaluationContextAndWait(
    EvaluationContext(targetingKey: 'user-123'),
  );

  final client = OpenFeatureAPI.instance.getClient('checkout');
  final enabled = client.getBooleanValue('new-checkout', false);
  final message = client.getStringValue('welcome-message', 'Welcome');

  print('$enabled: $message');
  await OpenFeatureAPI.instance.shutdown();
}
```

## Implement a provider

Implement `FeatureProvider` with synchronous resolvers. A resolver must use
local state. It must not perform network, file, or platform-channel I/O.

Implement only the optional capabilities that the provider needs:

- `InitializableProvider` for asynchronous initialization.
- `ContextReconciliationProvider` for static-context changes.
- `ShutdownProvider` for resource cleanup.
- `ProviderEventSource` for provider lifecycle events.
- `DomainScopedProvider` when one provider instance supports one domain.
- `TrackingProvider` for non-blocking tracking.

An initializable or reconciling provider must also implement
`ProviderEventSource`. It must emit the terminal lifecycle event before its
method terminates.

## Scope

This package does not include an HTTP transport, an OFREP provider, a vendor
provider, persistent storage, or Flutter APIs.

## Validate the package archive

The repository root uses `.pubignore` to keep client source out of the server
package. Pub also applies that parent rule to nested publication commands. Run
the repository staging command to validate the client archive outside the
parent package:

```text
dart tool/stage_client_package.dart --dry-run
```
