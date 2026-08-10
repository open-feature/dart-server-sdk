# Dart Client SDK Conformance Matrix

## Purpose

This matrix converts the OpenFeature static-context requirements into the first
Dart client SDK implementation and test backlog. It is a planning aid, not a
replacement for the normative specification. Requirement identifiers and tests
must be rechecked against the specification revision selected for the release.

## Target

- Package: `openfeature_dart_client_sdk`
- Paradigm: static context
- Initial platforms: Dart web and Flutter's supported target matrix
- Initial specification target: current OpenFeature specification at the time
  the implementation branch is created
- Status: proposed; not implemented

## Conformance Areas

| Area | Normative reference | Proposed Dart surface | Required first tests |
| --- | --- | --- | --- |
| API ownership | Flag Evaluation API, API and Client | `OpenFeatureAPI.instance`, `getClient`, `shutdown`, test reset | One active API state; clients bind predictably; shutdown clears state |
| Typed evaluation | Requirements 1.3.2.1, 1.3.3.1, 1.3.4, 1.4.2.1, and 1.4.3 through 1.4.15.1 | Synchronous `getBooleanValue`, `getStringValue`, `getIntegerValue`, `getDoubleValue`, `getObjectValue`, and matching details methods | Correct type; no provider I/O; default on abnormal execution; details include key, value, reason, variant, error, and metadata |
| Provider registration | Requirements 1.1.2.1 through 1.1.2.4 | `setProvider`, `setProviderAndWait`, and domain-scoped equivalents | Initialize once; non-awaiting completion uses status/events; awaited failure is observable; old provider shuts down only after its final binding is removed |
| Provider status | Requirements 1.7.1 through 1.7.9 and static-context requirement 1.7.2.1 | `ProviderStatus` and client status accessor | All six status transitions; lifecycle error-code propagation; shutdown returns to `NOT_READY` |
| Lifecycle short-circuiting | Requirements 1.7.6 and 1.7.7 | Internal evaluation guard | `NOT_READY` returns default with `PROVIDER_NOT_READY`; `FATAL` returns default with `PROVIDER_FATAL`; provider resolver is not invoked; error and finally hooks run |
| Provider resolution | Provider requirements 2.2.1 through 2.2.10 | Synchronous typed resolver methods returning `ResolutionDetails<T>` | Current static context reaches provider; resolver performs no I/O; provider exception maps to error details; normal results omit error message |
| Provider metadata and hooks | Provider requirements 2.1.1, 2.2.10, and 2.3.1 | Immutable `ProviderMetadata`, typed flag metadata, optional provider hooks | Metadata survives evaluation; invalid metadata values rejected; provider hooks join lifecycle order |
| Provider lifecycle | Provider requirements 2.4.1, 2.4.2.1, and 2.5.1 through 2.5.3 | Asynchronous `initialize` and idempotent `shutdown` returning `Future<void>` | Normal, error, and fatal initialization; repeated shutdown; final-binding cleanup; pending tracking work flushed or discarded |
| Context reconciliation | Provider requirement 2.6.1 | Asynchronous `onContextChanged(previous, current)` returning `Future<void>` | Old/new context supplied; normal completion becomes `READY`; abnormal completion becomes `ERROR` or `FATAL`; no previous-identity values; no call for unaffected domain |
| Evaluation context values | Evaluation Context requirements 3.1.2 through 3.1.4 | Immutable `EvaluationContext` with targeting key and typed attributes | Boolean, string, number, datetime, and structure values; unique keys; full map and keyed access |
| Global static context | Static-context requirement 3.2.2.1 | `setEvaluationContext` and `setEvaluationContextAndWait` | Non-awaiting completion is observable through status/events; every registered default-context provider reconciles before awaited call returns |
| No invocation context | Static-context requirement 3.2.2.2 | Evaluation methods intentionally omit context arguments | Public API compile-time surface has no client or invocation context parameter |
| Domain context | Static-context requirements 3.2.2.3 and 3.2.2.4 | Domain set, clear, and corresponding `AndWait` mutators | Domain override; global fallback; clear; only associated provider reconciles; divergent contexts require separate provider instances |
| Context change dispatch | Static-context requirements 3.2.4.1 and 3.2.4.2 | Internal reconciliation coordinator | Global change reaches all applicable providers; domain change reaches one provider |
| Concurrent reconciliation | Events requirements 5.3.4.2 and 5.3.4.3 | Monotonic context revision and shared reconciliation barrier | Late old response never replaces new context; outstanding waits reflect the final current revision; one final changed or error event runs after all callbacks terminate |
| Hook context | Hook requirements 4.1.1 through 4.2.2.3 | Immutable invocation fields, mutable per-hook data, immutable hints | Required fields; metadata; hook-data isolation; immutable hints and invocation data |
| Static before hook | Static-context requirement 4.3.3.1 | `before` returns no context | Hook cannot mutate static context; provider receives API/domain context unchanged |
| Hook registration and order | Hook requirements 4.4.1 and 4.4.2 | API, client, invocation options, and provider hooks | Before order API/client/invocation/provider; after/error/finally reverse order |
| Provider events | Event requirements 5.1.1 and 5.1.2 | Provider event stream and API/client handlers | Ready, error, stale, fatal, and configuration events reach only associated handlers |
| Handler isolation | Event requirements 5.2.5 through 5.2.7 | Handler subscription/removal | One failing handler does not block others; handlers survive provider change; removal works |
| Initialization events | Event requirements 5.3.1 through 5.3.3 | SDK-generated ready/error events | Correct event after initialize; late handler runs immediately for current state |
| Reconciliation events | Static-context requirements 5.3.4.1 through 5.3.4.3 and requirement 5.3.5 | SDK-generated reconciling, context-changed, and error events | Async reconciliation announces `RECONCILING`; final success runs context-changed handlers; final failure runs error handlers; provider cannot emit SDK-owned context events |
| Tracking | Static-context requirement 6.1.2.1, requirements 6.1.3, 6.1.4, 6.2.1, and 6.2.2, and provider condition 2.7.1 | Non-blocking `void track(name, details)` using current static context | Provider receives current context and typed details; unsupported tracking no-ops; call does not await I/O; pending work flushes or stops on shutdown |
| In-memory provider | Appendix A | Public testing provider | Typed flags; callback targeting; mutation emits configuration-changed with expected keys |

## Client-Specific Race Tests

The following tests are release blockers even when they are not represented by a
single specification requirement:

1. Context changes from anonymous to user A and then user B cannot expose user
   A's cached values after user B becomes current.
2. A sign-out clears identity-specific values before anonymous values are made
   visible.
3. Two rapid domain-context updates emit one final successful context-changed
   state for the latest revision.
4. Provider replacement during reconciliation cannot mutate the replacement
   provider's state.
5. Shutdown during reconciliation cancels or ignores late completion.
6. A stale provider may return its documented cache policy; `NOT_READY` and
   `FATAL` return application defaults without invoking resolution.
7. Reconciliation failure runs `PROVIDER_ERROR` handlers only after all
   outstanding invocations finish and the last completion is unsuccessful.
8. Binding one provider instance to domains with divergent static contexts is
   rejected before either binding can leak values into the other.

## Platform Matrix

| Platform | Compile gate | Runtime gate |
| --- | --- | --- |
| Dart VM | `dart analyze` and tests | Lifecycle, hooks, events, and in-memory conformance |
| Dart web | `dart compile js` or equivalent web test | No `dart:io`; context reconciliation and provider events in browser |
| Flutter Android | Example build | App pause/resume and network transition integration tests |
| Flutter iOS | Example build | App pause/resume and network transition integration tests |
| Flutter web | Example build | Same client package as pure Dart web; no conditional Flutter API |
| Flutter desktop | Example builds | Initialization, shutdown, and local cache behavior |

The core package should not import Flutter. Flutter validation belongs in an
example or downstream integration test project.

## First Merge Scope

The first implementation merge should contain only:

- Package scaffold and public library entry point.
- Flag values, evaluation context, metadata, resolution details, and errors.
- Client provider interface, provider status, and lifecycle method signatures.
- API/client method signatures for static context and typed evaluation.
- In-memory provider contract skeleton.
- Unit tests proving the public static-context shape, especially the absence of
  invocation-level context.

It should not include an HTTP transport, OFREP provider, vendor provider,
Flutter dependency, persistent cache, or server package relocation.

## Candidate Work Split

| Workstream | Candidate lead | Review requirement |
| --- | --- | --- |
| Public API and specification mapping | OpenFeature Dart maintainers | OpenFeature maintainer review |
| Client lifecycle and context coordinator | Client-package contributors | Existing Dart maintainer approval |
| Events, hooks, and in-memory provider | Shared implementation | Conformance tests required |
| Monorepo CI and independent releases | OpenFeature Dart maintainers | No server release regression |
| Independent remote providers | Independent provider maintainers | Kept outside core; shared contract suite passes for at least two providers before stable release |
| Pure Dart and Flutter validation | Client-package contributors and provider maintainers | Core package remains Flutter-free |

## Completion Rule

An item is complete only when its public API, normative behavior, error behavior,
race behavior, and platform constraints are covered by automated tests. A code
path demonstrated only by the reference provider is not core SDK conformance.

## References

- [OpenFeature specification](https://openfeature.dev/specification/)
- [Flag Evaluation API](https://openfeature.dev/specification/sections/flag-evaluation/)
- [Providers](https://openfeature.dev/specification/sections/providers/)
- [Evaluation Context](https://openfeature.dev/specification/sections/evaluation-context/)
- [Hooks](https://openfeature.dev/specification/sections/hooks/)
- [Events](https://openfeature.dev/specification/sections/events/)
- [Tracking](https://openfeature.dev/specification/sections/tracking/)
- [Included Utilities](https://openfeature.dev/specification/appendix-a/)
