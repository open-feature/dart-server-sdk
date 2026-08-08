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

The provider interface should be asynchronous where lifecycle or state
reconciliation can require I/O. Flag reads may be synchronous from a provider's
local cache, but the SDK API must not assume that all providers evaluate in the
same way.

## Context Reconciliation

Client context represents one user or session and changes less frequently than
server request context. Updating global or domain-scoped context must:

1. Mark the affected provider as `RECONCILING`.
2. Invoke the provider's context-change callback with old and new context.
3. Prevent state from one targeting key from being served to another.
4. Move the provider to `READY`, `STALE`, `ERROR`, or `FATAL` based on the
   reconciliation result.
5. Emit the corresponding lifecycle event.

Concurrent context changes must be ordered or superseded deterministically.
Tests must cover sign-in, sign-out, account switching, refresh failure, and
late responses from a superseded context.

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
branches, and draft pull requests. Architecture and implementation work should
target the repository's protected default branch through that workflow unless
the OpenFeature maintainers approve an additional long-lived branch.

During the beta phase, integration should use exact commit references or
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
