# Dart server SDK OpenFeature v0.9 conformance matrix

Status: maintainer proposal  
Tracks: [#121](https://github.com/open-feature/dart-server-sdk/issues/121)  
Specification baseline: [OpenFeature v0.9.0](https://github.com/open-feature/spec/releases/tag/v0.9.0)  
Implementation baseline: `origin/development` at `af6bd95`

## Purpose and scope

This document maps the existing `openfeature_dart_server_sdk` package to the
OpenFeature v0.9 contract. It is an implementation plan and review aid, not a
claim of conformance.

The server SDK continues to use the dynamic-context paradigm. Flag evaluation
remains asynchronous, and API, transaction, client, invocation, and before-hook
contexts participate in evaluation. Static-context reconciliation belongs to
the separately proposed client SDK in #117 and is not imported into this
package.

The conformance work must preserve:

- the `openfeature_dart_server_sdk` package name and existing import paths;
- pure Dart operation with no Flutter dependencies;
- asynchronous server-side evaluation;
- invocation-scoped dynamic context;
- public compatibility through adapters and deprecations where practical.

Moving the server package under a future monorepo `packages/` directory and
renaming this repository to `dart-sdk` remain later compatibility changes. They
must not be bundled into the v0.9 behavioral implementation.

## Legend

| Mark | Meaning |
| --- | --- |
| Conformant | Implemented with relevant evidence; requirement-indexed tests may still be needed. |
| Partial | Partially represented, but the current behavior or public contract is not conformant. |
| Missing | Missing or materially incompatible. |
| N/A | Not applicable to the dynamic-context server paradigm. |

## P0: lifecycle and evaluation safety

These corrections establish safe provider replacement and deterministic
evaluation behavior before wider API cleanup.

| Area | v0.9 requirements | Current state and evidence | Required correction | Test gate | Compatibility approach |
| --- | --- | --- | --- | --- | --- |
| Provider-owned lifecycle events | 1.1.2.4; 1.7.1-1.7.6; 2.8.1-2.8.5; 5.3.1-5.3.3 | Missing: `OpenFeatureAPI.setProvider` and `setProviderAndWait` synthesize ready/error events from lifecycle return values. `FeatureProvider` has no provider event source or v0.9 capability marker. | Add a provider event contract and derive status from provider events. Require ready/error emission before lifecycle termination. Keep the deprecated SDK-synthesized path only for providers that explicitly use the legacy lifecycle contract. | Event-before-return, abnormal initialization, fatal error, no-initialize provider, and legacy-adapter tests. | Additive provider event interface plus a named legacy adapter/deprecation period. Do not silently infer events for v0.9-capable providers. |
| Provider status | 1.7.1-1.7.6; 2.8; 5.1.4-5.1.5 | Partial: internal provider status exists, but clients expose no conformant status accessor and status is not consistently driven by provider events before handlers run. | Maintain status per provider instance, expose it through bound clients, update it before invoking associated handlers, and infer `NOT_READY` after shutdown. | Full status transition table, handler-observed status, and fatal-provider short-circuit tests. | Preserve existing status names where equivalent; deprecate incompatible accessors rather than maintaining two sources of truth. |
| Instance-aware provider binding | 1.1.2.1-1.1.2.3; 1.1.3; 1.1.8.1; 1.8.4 | Missing: registry behavior is keyed by provider metadata name, so distinct same-name instances cannot be isolated. Replacing a binding does not shut down the old provider after its final use. | Track provider identity separately from metadata. Reference-count default/domain bindings, initialize an instance once, and shut it down only after its last binding is removed. Enforce the domain-scoped marker. | Same-name instance isolation, multi-domain reuse, final-binding shutdown, replacement race, and domain-scoped rejection tests. | Retain provider names as metadata only; do not expose them as registry identity. Existing set-provider overloads can delegate to the new binding coordinator. |
| Dynamic client rebinding | 1.1.3; 1.1.6-1.1.8; 1.2.2; 5.1.2-5.1.3 | Missing: `Client` captures a final provider at construction, so an existing client does not follow later default or domain provider changes. Client identity also conflates client ID and domain. | Resolve the current provider binding at evaluation/event/status access time. Add immutable client metadata whose domain corresponds to client creation, with a compatibility alias only where useful. | Existing-client default replacement, domain replacement, fallback-to-default, metadata immutability, and concurrent replacement tests. | Keep current client factory signatures temporarily; map legacy client IDs deliberately instead of changing their meaning silently. |
| Evaluation defaults and failure contract | 1.3.1.1-1.3.4; 1.4.1.1-1.4.15.1; 2.2.1-2.2.10 | Partial: typed and detailed methods exist, but defaults are optional and have implicit false/empty values. SDK-side behavior does not consistently prevent provider, hook, not-ready, or fatal failures from escaping. Flag metadata can be null. | Require an application default on every evaluation. Return it with the correct error code/reason for provider, hook, type-mismatch, parse, not-ready, and fatal failures. Make flag metadata an immutable empty record when absent. | Per-type simple/detailed success tests plus every specified error/default path; assert no evaluation exception escapes. | Introduce required-default signatures through a staged API or new conformant methods, then deprecate implicit-default overloads. |
| Evaluation context integrity | 3.1.1-3.1.4; 3.2.1.1; 3.2.3 | Partial: `OpenFeatureEvaluationContext` and `EvaluationContext` overlap. API context is snapshotted when a client is created, and some provider calls pass only `attributes`, dropping the targeting key. Allowed value types and defensive immutability are incomplete. | Establish one canonical immutable context/value model, retain the targeting key, and merge at evaluation time in global -> transaction -> client -> invocation -> before-hook order. Later API and client context changes must affect existing clients. | Targeting-key, allowed-type, deep immutability, all-level precedence, late context mutation, and transaction isolation tests. | Adapt/deprecate the duplicate context type and preserve source-compatible constructors where possible. |

## P1: complete the public contract

| Area | v0.9 requirements | Current state and evidence | Required correction | Test gate | Compatibility approach |
| --- | --- | --- | --- | --- | --- |
| Provider surface | 2.1.1; 2.2; 2.3; 2.4; 2.5; 2.7 | Partial: metadata and typed resolvers exist. `connect()` is a mandatory non-spec burden, lifecycle methods are mandatory instead of optional capabilities, provider hooks are absent, and tracking is mandatory. | Model initialization, shutdown, provider hooks, and tracking as optional capabilities. Supply the initial global context and optional first-bound domain to initialization. Require idempotent shutdown behavior where implemented. | Minimal resolver-only provider, lifecycle provider, provider-hooks provider, tracking provider, and domain-scoped provider contract tests. | Keep `connect()` and mandatory legacy members behind an adapter while providers migrate to capability interfaces. |
| Hooks and evaluation options | 1.5.1; 2.3.1-2.3.3; 4.1-4.6 | Partial: API/client hooks and stages exist, but evaluation options, invocation hooks, provider hooks, supported-stage declarations, and fully immutable hints are missing. Custom priority ordering can conflict with specified registration order. | Add evaluation options and invocation hooks/hints. Add provider hooks. Implement before ordering API -> transaction -> client -> invocation -> provider and reverse after/error/finally order, limited by supported stages. Keep hook data immutable. | Stage signature, merge contribution, ordering, short-circuit/error, supported-stage, hint immutability, and late registration tests. | Deprecate custom priority semantics if they cannot be mapped without violating specification order. |
| Event API and isolation | 5.1.1-5.1.5; 5.2.1-5.2.7; 5.3.1-5.3.5 | Missing: `open_feature_event.dart` and `event_system.dart` define competing event types. Handler registration consumes an untyped stream, and association relies on provider names rather than instances/domains. | Publish one canonical event model. Register/remove handlers by event type at API and client scope. Isolate delivery by provider instance and dynamic domain binding, include required event metadata, and prevent handler failures from disrupting others. | Typed registration/removal, API/client scope, same-name instance isolation, rebinding, metadata, status-before-handler, and handler-failure tests. | Adapt legacy streams to the canonical dispatcher during a deprecation window; do not keep two independent event buses. |
| API shutdown and reset | 1.6.1-1.6.2; 1.7.6; 2.5 | Missing: `shutdownProvider` handles only the current provider, emits `STALE`, and installs a default provider. `dispose` mainly closes controllers; reset paths do not await complete cleanup. | Add API shutdown that shuts down every registered provider once, resets providers, contexts, hooks, event handlers, and transaction propagators, and leaves the API reusable in its initial state. | Multi-provider shutdown-once, idempotency, in-flight initialization cancellation, complete state reset, and reuse-after-shutdown tests. | Keep `shutdownProvider` as a deprecated focused helper if needed, implemented through the lifecycle coordinator. |
| Independent API instances | 1.8.1-1.8.4 | Missing: only the global singleton is publicly available. | Add a deliberately separate factory/module for independent API instances with isolated providers, contexts, hooks, handlers, and transaction propagation. | Cross-instance state, event, provider, hook, and shutdown isolation tests. | Preserve the default singleton as the normal entry point. |
| Tracking | 2.7.1; 6.1.1.1-6.1.4; 6.2.1-6.2.2 | Partial: client and provider tracking exist, but every provider must implement it; tracking value is `double?` rather than `num?`; context integrity and custom detail types are not fully enforced. | Make tracking a provider capability, merge the conformant context, accept the specified numeric value shape, validate allowed custom fields, and define behavior for providers without tracking support. | Tracking/no-tracking provider, context merge, targeting-key, integer/double value, custom-field type, and shutdown/flush tests. | Supply a legacy tracking adapter and deprecate the mandatory provider method. |
| Transaction context | 3.3.1.1-3.3.2.1 (experimental) | Partial: a transaction context manager exists, but it needs requirement-indexed evidence, explicit propagator lifecycle, and isolation validation. | Verify idiomatic async-zone propagation, API registration/removal, merge precedence, and reset on shutdown. Document experimental status. | Nested async zone, concurrent request isolation, precedence, missing propagator, and shutdown reset tests. | Preserve existing transaction APIs when their behavior is conformant; adapt names separately from semantics. |

## P2: conformance and migration evidence

| Deliverable | Required result | Merge gate |
| --- | --- | --- |
| Requirement-indexed test suite | Each applicable v0.9 MUST has a passing test or a documented language/paradigm exception. SHOULD requirements have tests or recorded rationale. | CI publishes a matrix report tied to the v0.9 requirement identifiers. |
| Public API migration guide | Provider authors and SDK users can identify replacements, adapters, deprecations, and removal targets. | Examples cover provider events, provider replacement, contexts, hooks, events, tracking, and shutdown. |
| Package compatibility check | Existing package/import identity remains usable throughout the conformance stream. | A fixture using the last pre-conformance public API compiles against the compatibility layer. |
| External provider validation | At least one server provider passes lifecycle, evaluation, hook/event, and tracking integration scenarios without vendor logic entering core. | Validation runs in the provider's canonical repository and records the exact SDK prerelease/commit. A read-only mirror is not used as release or CI authority. |
| Documentation accuracy | README and API docs stop claiming v0.8 once the v0.9 gates pass and do not claim conformance earlier. | Published conformance statement links the tested matrix and specification release. |

## Explicitly non-applicable static-context requirements

The server package uses dynamic invocation context. The following v0.9
requirements are therefore not implementation targets for this package:

- 3.2.2.1-3.2.2.4: static-context API/domain context management;
- 3.2.4.1-3.2.4.2: automatic provider reconciliation after static context
  mutation;
- lifecycle behavior that exists only to reconcile a client-side evaluated flag
  cache after a static identity change.

The optional provider `on context changed` capability in 2.6.1 may still be
represented by a shared provider abstraction, but the dynamic server API must
not invoke it as a substitute for passing merged invocation context to every
evaluation.

## Implementation sequence

1. Land this matrix and agree on the legacy-provider compatibility boundary.
2. Add focused lifecycle/status tests, then implement provider events and the
   instance-aware binding coordinator.
3. Correct client rebinding, evaluation defaults, and canonical context.
4. Normalize hooks, events, tracking, shutdown, and independent API instances.
5. Add the complete requirement-indexed suite and migration guide.
6. Publish a server SDK prerelease for external provider validation.
7. Treat monorepo relocation and repository renaming as later, independently
   reversible changes.

Each implementation PR should reference #121, identify the matrix rows it
closes, and avoid mixing client-SDK or repository-migration changes into the
server conformance diff.
