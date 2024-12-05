# dart-server-sdk

![Status](https://img.shields.io/badge/status-experimental-red?style=flat&logo=warning)

:warning: This repository is a work in progress repository for an implementation of the `dart-server-sdk`.
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
  <!-- Specification Badge -->
  <a href="https://github.com/open-feature/spec/releases/tag/v0.8.0">
    <img alt="Specification" src="https://img.shields.io/static/v1?label=specification&message=v0.8.0&color=yellow&style=for-the-badge" />
  </a>
  <!-- Release Badge -->
  <a href="https://github.com/open-feature/dart-server-sdk/releases/tag/v0.0.1-pre">
    <img alt="Release" src="https://img.shields.io/static/v1?label=release&message=v0.0.1-pre&color=blue&style=for-the-badge" />
  </a>
  <br/>
  <!-- Dart-Specific Badges -->
  <a href="https://pub.dev/packages/open_feature">
    <img alt="Pub Version" src="https://img.shields.io/pub/v/open_feature.svg?style=for-the-badge" />
  </a>
  <a href="https://pub.dev/documentation/open_feature/latest/">
    <img alt="API Reference" src="https://img.shields.io/badge/API-reference-blue.svg?style=for-the-badge" />
  </a>
  <a href="https://codecov.io/gh/open-feature/dart-server-sdk">
    <img alt="Code Coverage" src="https://codecov.io/gh/open-feature/dart-server-sdk/branch/main/graph/badge.svg?token=FZ17BHNSU5" />
  </a>
  <a href="https://github.com/open-feature/dart-server-sdk/actions/workflows/ci.yml">
    <img alt="GitHub CI Status" src="https://github.com/open-feature/dart-server-sdk/actions/workflows/ci.yml/badge.svg?style=for-the-badge" />
  </a>
  <a href="https://bestpractices.coreinfrastructure.org/projects/6601">
    <img alt="CII Best Practices" src="https://bestpractices.coreinfrastructure.org/projects/6601/badge?style=for-the-badge" />
  </a>
  <a href="https://dart.dev/">
    <img alt="Built with Dart" src="https://img.shields.io/badge/Built%20with-Dart-blue.svg?style=for-the-badge" />
  </a>
</p>
<!-- x-hide-in-docs-start -->

[OpenFeature](https://openfeature.dev) is an open specification that provides a vendor-agnostic, community-driven API for feature flagging that works with your favorite feature flag management tool.

<!-- x-hide-in-docs-end -->

## 🚀 Quick start

### Requirements

Dart language version: [3.54](https://dart.dev/get-dart/archive)

> [!NOTE]
> The OpenFeature DartServer SDK only supports the latest currently maintained Dart language versions.

### Install

TBD

### API Reference

See [TBD](TBD) for the complete API documentation.

## 🌟 Features

| Status | Features                        | Description                                                                                                                       |
| ------ |---------------------------------| --------------------------------------------------------------------------------------------------------------------------------- |
| ❌      | [Providers](#providers)         | Integrate with a commercial, open source, or in-house feature management tool.                                                    |
| ❌      | [Targeting](#targeting)         | Contextually-aware flag evaluation using [evaluation context](https://openfeature.dev/docs/reference/concepts/evaluation-context). |
| ❌      | [Hooks](#hooks)                 | Add functionality to various stages of the flag evaluation life-cycle.                                                            |
| ❌      | [Logging](#logging)             | Integrate with popular logging packages.                                                                                          |
| ❌      | [Domains](#domains)             | Logically bind clients with providers.|
| ❌      | [Eventing](#eventing)           | React to state changes in the provider or flag management system.                                                                 |
| ❌      | [Shutdown](#shutdown)           | Gracefully clean up a provider during application shutdown.                                                                       |
| ❌      | [Transaction Context Propagation](#transaction-context-propagation) | Set a specific [evaluation context](https://openfeature.dev/docs/reference/concepts/evaluation-context) for a transaction (e.g. an HTTP request or a thread) |
| ❌      | [Extending](#extending)         | Extend OpenFeature with custom providers and hooks.                                                                               |

<sub>Implemented: ✅ | In-progress: ⚠️ | Not implemented yet: ❌</sub>

### Providers

[Providers](https://openfeature.dev/docs/reference/concepts/provider) are an abstraction between a flag management system and the OpenFeature SDK.
Look [here](https://openfeature.dev/ecosystem?instant_search%5BrefinementList%5D%5Btype%5D%5B0%5D=Provider&instant_search%5BrefinementList%5D%5Btechnology%5D%5B0%5D=Dart) for a complete list of available providers.
If the provider you're looking for hasn't been created yet, see the [develop a provider](#develop-a-provider) section to learn how to build it yourself.

Once you've added a provider as a dependency, it can be registered with OpenFeature like this:



### Targeting

Sometimes, the value of a flag must consider some dynamic criteria about the application or user, such as the user's location, IP, email address, or the server's location.
In OpenFeature, we refer to this as [targeting](https://openfeature.dev/specification/glossary#targeting).
If the flag management system you're using supports targeting, you can provide the input data using the [evaluation context](https://openfeature.dev/docs/reference/concepts/evaluation-context).


### Hooks

[Hooks](https://openfeature.dev/docs/reference/concepts/hooks) allow for custom logic to be added at well-defined points of the flag evaluation life-cycle
Look [here](https://openfeature.dev/ecosystem/?instant_search%5BrefinementList%5D%5Btype%5D%5B0%5D=Hook&instant_search%5BrefinementList%5D%5Btechnology%5D%5B0%5D=Dart) for a complete list of available hooks.
If the hook you're looking for hasn't been created yet, see the [develop a hook](#develop-a-hook) section to learn how to build it yourself.

Once you've added a hook as a dependency, it can be registered at the global, client, or flag invocation level.

### Tracking

The [tracking API](https://openfeature.dev/specification/sections/tracking/) allows you to use OpenFeature abstractions and objects to associate user actions with feature flag evaluations.
This is essential for robust experimentation powered by feature flags.
For example, a flag enhancing the appearance of a UI component might drive user engagement to a new feature; to test this hypothesis, telemetry collected by a [hook](#hooks) or [provider](#providers) can be associated with telemetry reported in the client's `track` function.


Note that some providers may not support tracking; check the documentation for your provider for more information.

### Logging

Note that in accordance with the OpenFeature specification, the SDK doesn't generally log messages during flag evaluation.

#### Logging Hook

The Dart SDK includes a `LoggingHook`, which logs detailed information at key points during flag evaluation, using [TBD](TBD) structured logging API.
This hook can be particularly helpful for troubleshooting and debugging; simply attach it at the global, client or invocation level and ensure your log level is set to "debug".

##### Usage example


###### Output

```sh
{"time":"2024-10-23T13:33:09.8870867+03:00","level":"DEBUG","msg":"Before stage","domain":"test-client","provider_name":"InMemoryProvider","flag_key":"not-exist","default_value":true}  
{"time":"2024-10-23T13:33:09.8968242+03:00","level":"ERROR","msg":"Error stage","domain":"test-client","provider_name":"InMemoryProvider","flag_key":"not-exist","default_value":true,"error_message":"error code: FLAG_NOT_FOUND: flag for key not-exist not found"}
```

See [hooks](#hooks) for more information on configuring hooks.

### Domains

Clients can be assigned to a domain. A domain is a logical identifier that can be used to associate clients with a particular provider. If a domain has no associated provider, the default provider is used.


### Eventing

Events allow you to react to state changes in the provider or underlying flag management system, such as flag definition changes, provider readiness, or error conditions.
Initialization events (`PROVIDER_READY` on success, `PROVIDER_ERROR` on failure) are dispatched for every provider.
Some providers support additional events, such as `PROVIDER_CONFIGURATION_CHANGED`.

Please refer to the documentation of the provider you're using to see what events are supported.


### Shutdown


### Transaction Context Propagation

Transaction context is a container for transaction-specific evaluation context (e.g. user id, user agent, IP).
Transaction context can be set where specific data is available (e.g. an auth service or request handler), and by using the transaction context propagator, it will automatically be applied to all flag evaluations within a transaction (e.g. a request or thread).


## Extending

### Develop a provider

To develop a provider, you need to create a new project and include the OpenFeature SDK as a dependency.
This can be a new repository or included in [the existing contrib repository](https://github.com/open-feature/dart-server-sdk-contrib) available under the OpenFeature organization.
You’ll then need to write the provider by implementing the `FeatureProvider` interface exported by the OpenFeature SDK.


> Built a new provider? [Let us know](https://github.com/open-feature/openfeature.dev/issues/new?assignees=&labels=provider&projects=&template=document-provider.yaml&title=%5BProvider%5D%3A+) so we can add it to the docs!

### Develop a hook

To develop a hook, you need to create a new project and include the OpenFeature SDK as a dependency.
This can be a new repository or included in [the existing contrib repository](https://github.com/open-feature/dart-server-sdk-contrib) available under the OpenFeature organization.
Implement your own hook by conforming to the [Hook interface](./pkg/openfeature/hooks.dart).
To satisfy the interface, all methods (`Before`/`After`/`Finally`/`Error`) need to be defined.
To avoid defining empty functions make use of the `UnimplementedHook` struct (which already implements all the empty functions).


> Built a new hook? [Let us know](https://github.com/open-feature/openfeature.dev/issues/new?assignees=&labels=hook&projects=&template=document-hook.yaml&title=%5BHook%5D%3A+) so we can add it to the docs!

## Testing

The SDK provides a `NewTestProvider` which allows you to set flags for the scope of a test.
The `TestProvider` is thread-safe and can be used in tests that run in parallel.

Call `testProvider.UsingFlags(t, tt.flags)` to set flags for a test, and clean them up with `testProvider.Cleanup()`


<!-- x-hide-in-docs-start -->
## ⭐️ Support the project

- Give this repo a ⭐️!
- Follow us on social media:
  - Twitter: [@openfeature](https://twitter.com/openfeature)
  - LinkedIn: [OpenFeature](https://www.linkedin.com/company/openfeature/)
- Join us on [Slack](https://cloud-native.slack.com/archives/C0344AANLA1)
- For more, check out our [community page](https://openfeature.dev/community/)

## 🤝 Contributing

Interested in contributing? Great, we'd love your help! To get started, take a look at the [CONTRIBUTING](CONTRIBUTING.md) guide.

### Thanks to everyone that has already contributed

<a href="https://github.com/open-feature/dart-server-sdk/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=open-feature/dart-server-sdk" alt="Pictures of the folks who have contributed to the project" />
</a>

Made with [contrib.rocks](https://contrib.rocks).
<!-- x-hide-in-docs-end -->