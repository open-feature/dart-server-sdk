# Dart Client SDK Architecture

## Status

Proposed architecture for maintainer and community review.

## Decision

Evolve the Dart SDK repository into a monorepo that publishes independent
server-side and client-side packages. The client package must implement the
OpenFeature static-context paradigm and must run in pure Dart web applications
without a Flutter dependency.

The existing server package and public API remain supported. A Flutter package
is not part of the initial SDK split. Flutter-specific lifecycle or widget
support may be added later as a thin adapter over the pure Dart client package.

## Goals

- Preserve the existing `openfeature_dart_server_sdk` package and public API.
- Publish a framework-neutral `openfeature_dart_client_sdk` package.
- Support pure Dart web, Flutter mobile, Flutter desktop, and Flutter web.
- Keep server, client, shared, and Flutter dependency graphs separate.
- Conform to the OpenFeature dynamic-context and static-context paradigms.
- Allow providers to reconcile cached flag state when client context changes.
- Give each published package independent versioning and release automation.
- Validate the client contract with at least two independent provider
  implementations before a stable release.

## Non-goals

- Moving vendor-specific providers into the core SDK repository.
- Embedding Flutter, platform-channel, or UI dependencies in the client SDK.
- Defining a generic conversation, voice, or customer-engagement abstraction.
- Using feature flags as a workflow engine or message transport.
- Requiring server and client packages to release at the same version.

## Package Boundaries

The first monorepo iteration should contain:

| Package | Responsibility | Runtime constraints |
| --- | --- | --- |
| `openfeature_dart_server_sdk` | Existing dynamic-context SDK | Server Dart; current API remains compatible |
| `openfeature_dart_client_sdk` | Static-context API, provider lifecycle, hooks, events, and evaluation | Pure Dart; web-compatible; no Flutter dependency |

During the incremental migration, the server package remains at the repository
root and the client package is added at
`packages/openfeature_dart_client_sdk/`. Repository-wide validation and release
automation must explicitly discover both locations until the server package is
moved in its own compatibility change.

Shared code should be extracted only when both packages require the same stable,
specification-neutral contract. Candidate types include flag values, provider
metadata, evaluation details, error codes, and event metadata. Server lifecycle,
transaction context, client context reconciliation, HTTP transports, and caches
must not be placed in a shared package.

Do not create a public shared package in the first change. Start the client
package with an explicit contract inventory, then extract shared types in a
separate reviewed change when the compatibility benefit is demonstrated.

## Core And Provider Boundary

The client SDK defines the portable OpenFeature contract. It owns static
evaluation context, provider registration and lifecycle, context
reconciliation, typed evaluation methods, hooks, events, tracking dispatch,
defaults, errors, and conformance behavior.

Provider packages remain external to the core repository and own
vendor-specific transport, client-safe authentication, assignment retrieval,
cache persistence and invalidation strategy, local evaluation details, and
telemetry mapping. Framework-specific integrations, including Flutter
lifecycle or observability adapters, must be optional layers over the pure Dart
client package.

An existing vendor SDK may implement the provider contract directly or be
wrapped by a thin OpenFeature provider. Its behavior must not become an
implicit requirement of the core SDK unless the behavior is first accepted as
part of the provider-neutral public contract.

## Client Contract

The client SDK must provide:

- One OpenFeature API entry point that owns providers, domains, hooks, handlers,
  and static evaluation context.
- Typed value and evaluation-details methods for boolean, string, integer,
  double, and structured values.
- Global and domain-scoped evaluation context.
- No client-level or invocation-level evaluation-context arguments.
- Provider initialization, shutdown, and context-change callbacks.
- Provider states including `NOT_READY`, `READY`, `RECONCILING`, `STALE`,
  `ERROR`, and `FATAL` where required by the specification.
- Client events for provider readiness, errors, configuration changes,
  reconciliation, and completed context changes.
- Hook execution and optional tracking without exposing provider internals.
- An in-memory provider suitable for conformance tests and application tests.

The client uses synchronous flag-evaluation methods. A provider resolver must
read only its current in-memory state and must not perform network, file, or
platform-channel I/O during flag evaluation. Synchronous evaluation preserves
predictable use in widget builds and other hot paths.

Provider initialization, context reconciliation, and shutdown are asynchronous
and return `Future<void>`. The API provides both non-awaiting mutators and
awaitable variants:

- `setProvider` starts initialization and reports completion through status and
  events; `setProviderAndWait` completes after initialization succeeds or fails.
- `setEvaluationContext` starts reconciliation and reports completion through
  status and events; `setEvaluationContextAndWait` completes after all affected
  providers finish reconciling.
- Domain-scoped provider and context mutators follow the same naming and waiting
  semantics.

Non-awaiting mutators must not surface asynchronous failures as uncaught zone
errors. Awaitable variants may complete with a lifecycle or configuration error
after the SDK has first updated provider status and run the required event
handlers. Hooks used during flag evaluation are synchronous. Tracking is a
non-blocking `void` operation; providers enqueue any I/O and flush or discard
pending work during asynchronous shutdown.

## Context Reconciliation

Client context represents one user or session and changes less frequently than
server request context. Updating global or domain-scoped context must:

1. Mark the affected provider as `RECONCILING`.
2. Invoke the provider's context-change callback with old and new context.
3. Prevent state from one targeting key from being served to another while the
   callback is running.
4. On normal completion, move the provider to `READY` and run
   `PROVIDER_CONTEXT_CHANGED` handlers.
5. On abnormal completion, move the provider to `ERROR`, or to `FATAL` when the
   lifecycle error code is `PROVIDER_FATAL`, and run `PROVIDER_ERROR` handlers.

`STALE` is not a direct reconciliation result. A provider may independently
signal `PROVIDER_STALE` when its cached state is no longer current, and the SDK
then reflects the corresponding status. During `RECONCILING`, evaluation may
return a value only when the provider can prove it belongs to the new context;
otherwise the resolver returns an error and the SDK returns the application
default. Values associated with the previous targeting identity must never be
served.

Concurrent context changes must be ordered or superseded deterministically.
Tests must cover sign-in, sign-out, account switching, refresh failure, and
late responses from a superseded context.

Each context mutation receives a monotonically increasing revision. A response
for an older revision cannot replace state prepared for a newer revision.
Awaitable context mutations share a reconciliation barrier: outstanding waits
complete only after all callbacks in flight have terminated, and their outcome
reflects the final current revision. Successful completion means the SDK is
stable on the latest context, not that an earlier superseded context remains
current.

Lifecycle status is tracked per provider instance, while provider and context
selection is tracked per domain binding. A provider instance is initialized
once and is shut down only after its final binding is removed. For the initial
client release, the SDK must reject binding one provider instance to domains
with divergent static contexts because the specification's context-change
callback has no domain parameter. Applications needing different domain
contexts must register separate provider instances.

## Remote Evaluation and Authentication

The client SDK owns no vendor authentication scheme. Providers may use OFREP or
another vendor protocol, but distributed applications must not contain OAuth
client secrets, service credentials, or administrative API tokens.

A remote-evaluation provider should prefer the OFREP static-context flow:

1. Obtain a short-lived, client-safe credential from an application-controlled
   backend or an approved public-client authorization flow.
2. Submit the current static context to the bulk-evaluation endpoint.
3. Cache the returned flag set for local typed evaluation.
4. Use ETags or equivalent revisions for conditional refresh.
5. Clear or partition cached data whenever the targeting identity changes.
6. Apply an explicit stale-data policy and always preserve application defaults.

Credential refresh and flag refresh are separate concerns. A provider must not
silently convert server-side client-credentials authentication into a mobile or
browser integration.

## Repository Migration

Migration should be incremental:

1. Add this architecture and an API conformance matrix.
2. Add the client package and its tests without moving the server package.
3. Add repository-wide CI that discovers and validates every package.
4. Configure independent publishing and changelog generation.
5. Move the server package under `packages/` only in a dedicated compatibility
   change, preserving its package name, imports, and published API.
6. Rename the repository only after package paths, publishing, and external
   links have been verified.

This sequence keeps client development moving without coupling it to a risky
server package relocation.

## Provider Validation

External providers should be developed concurrently after the client provider
interface and lifecycle skeleton merge. They act as independent contract tests,
not as dependencies of the core SDK.

Each validation provider must demonstrate:

- Static-context reconciliation and identity-safe cache replacement.
- Boolean, string, number, and structured flag evaluation.
- Evaluation details, errors, reasons, variants, and metadata.
- Startup, refresh, degraded-network, and shutdown behavior.
- Browser and Flutter compatibility without Flutter in its core dependency
  graph.
- Authentication that is safe for distributed clients.

Vendor-specific code, endpoints, credentials, and release ownership remain in
the provider's repository.

At least two independently maintained providers should pass the same provider
contract suite before the client SDK is declared stable. This reduces the risk
that one vendor's transport, cache, authentication, or telemetry model becomes
the de facto core architecture.

## Repository Workflow

The canonical OpenFeature repository uses public GitHub issues, feature
branches, and draft pull requests. During the client SDK beta, architecture and
implementation pull requests target the protected `development` branch. The
`main` branch remains the stable release line unless the OpenFeature maintainers
approve a different promotion policy.

Beta integration should use exact commit references from `development` or
published prerelease versions. Floating branch dependencies are not acceptable
for provider release validation. Provider repositories may use their own
development and promotion workflows as long as released integrations depend on
an immutable OpenFeature client version.

## Ownership

- Existing Dart maintainers retain repository-wide architecture, shared
  contracts, server package, compatibility, and release governance.
- Client contributors may become component owners for the client package
  through the normal OpenFeature contributor process.
- Provider maintainers own vendor implementations and provider releases.
- Application maintainers own downstream product and workflow orchestration.

Component ownership does not transfer repository-wide governance.

## Delivery Sequence

1. **Client API matrix:** Map every applicable static-context specification
   requirement to a Dart API and conformance test.
2. **Client skeleton:** Land provider interfaces, lifecycle state, context
   reconciliation, typed evaluation, hooks, events, and in-memory provider.
3. **Provider contract:** Define a client-safe remote-evaluation
   contract without reusing server credentials.
4. **Independent providers:** Build pure Dart providers in their respective
   repositories as external validation of the client interface.
5. **Platform validation:** Test the client SDK and validation providers on pure
   Dart web and the Flutter target matrix; add a Flutter adapter only for
   demonstrated lifecycle needs.
6. **Monorepo release:** Exercise independent package validation, versioning,
   changelog generation, and publishing.

## Release Gates

The client package is not ready for an initial stable release until:

- Static-context conformance tests pass.
- Browser builds contain no `dart:io` or Flutter-only dependency.
- Context changes cannot leak cached flags across targeting identities.
- Defaults are returned predictably during provider failure.
- No distributed-client example embeds a server credential.
- Independent versioning and publishing are exercised in CI.
- At least two independent providers pass the same contract tests against the
  merged client API.

## References

- [OpenFeature SDK paradigms](https://openfeature.dev/docs/reference/concepts/sdk-paradigms/)
- [OpenFeature evaluation context specification](https://openfeature.dev/specification/sections/evaluation-context/)
- [OpenFeature provider specification](https://openfeature.dev/specification/sections/providers/)
- [OpenFeature Remote Evaluation Protocol](https://openfeature.dev/docs/reference/other-technologies/ofrep/)
