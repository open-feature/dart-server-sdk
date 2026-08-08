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
| Typed evaluation | Flag Evaluation API, evaluation methods and details | `getBooleanValue`, `getStringValue`, `getIntegerValue`, `getDoubleValue`, `getObjectValue`, and matching details methods | Correct type; default on abnormal execution; details include key, value, reason, variant, error, and metadata |
| Provider registration | Flag Evaluation API, setting a provider | `setProvider`, `setProviderAndWait`, domain-scoped equivalents | Initialize once; old provider shutdown; async wait; failed initialize returns defaults and error details |
| Provider status | Requirements 1.7.1 through 1.7.4 and static-context requirement 1.7.2.1 | `ProviderStatus` and client status accessor | `NOT_READY`, `READY`, `RECONCILING`, `STALE`, `ERROR`, and `FATAL` transitions |
| Provider resolution | Provider section | Typed resolver methods returning `ResolutionDetails<T>` | Context reaches provider; provider exception maps to error details; normal results omit error message |
| Provider metadata and hooks | Provider requirements 2.1.1, 2.2.10, and 2.3.1 | Immutable `ProviderMetadata`, typed flag metadata, optional provider hooks | Metadata survives evaluation; invalid metadata values rejected; provider hooks join lifecycle order |
| Provider lifecycle | Provider initialization and shutdown | `initialize`, idempotent `shutdown` | Normal and failed initialization; repeated shutdown; cleanup after replacement |
| Context reconciliation | Provider requirement 2.6.1 | `onContextChanged(previous, current)` | Old/new context supplied; sync and async providers; failure state; no call for unaffected domain |
| Evaluation context values | Evaluation Context requirements 3.1.2 through 3.1.4 | Immutable `EvaluationContext` with targeting key and typed attributes | Boolean, string, number, datetime, and structure values; unique keys; full map and keyed access |
| Global static context | Static-context requirement 3.2.2.1 | `setEvaluationContext` and awaited variant | Every registered default-context provider reconciles before awaited call returns |
| No invocation context | Static-context requirement 3.2.2.2 | Evaluation methods intentionally omit context arguments | Public API compile-time surface has no client or invocation context parameter |
| Domain context | Static-context requirements 3.2.2.3 and 3.2.2.4 | `setEvaluationContextForDomain`, `clearEvaluationContextForDomain` | Domain override; global fallback; clear; only associated provider reconciles |
| Context change dispatch | Static-context requirements 3.2.4.1 and 3.2.4.2 | Internal reconciliation coordinator | Global change reaches all applicable providers; domain change reaches one provider |
| Concurrent reconciliation | Events requirement 5.3.4.2 | Monotonic context revision and ordered/superseded completion | Late old response never replaces new context; changed event fires only after final successful completion |
| Hook context | Hook requirements 4.1.1 through 4.2.2.3 | Immutable invocation fields, mutable per-hook data, immutable hints | Required fields; metadata; hook-data isolation; immutable hints and invocation data |
| Static before hook | Static-context requirement 4.3.3.1 | `before` returns no context | Hook cannot mutate static context; provider receives API/domain context unchanged |
| Hook registration and order | Hook requirements 4.4.1 and 4.4.2 | API, client, invocation options, and provider hooks | Before order API/client/invocation/provider; after/error/finally reverse order |
| Provider events | Event requirements 5.1.1 and 5.1.2 | Provider event stream and API/client handlers | Ready, error, stale, fatal, and configuration events reach only associated handlers |
| Handler isolation | Event requirements 5.2.5 through 5.2.7 | Handler subscription/removal | One failing handler does not block others; handlers survive provider change; removal works |
| Initialization events | Event requirements 5.3.1 through 5.3.3 | SDK-generated ready/error events | Correct event after initialize; late handler runs immediately for current state |
| Reconciliation events | Static-context requirements 5.3.4.1 and 5.3.4.2 | SDK-generated reconciling/context-changed events | Async reconciliation announces both states; sync may omit reconciling; provider cannot emit SDK-owned context events |
| Tracking | Tracking section and provider condition 2.7.1 | `track(name, details)` using current static context | Provider receives current context and details; unsupported tracking is non-fatal; pending work flushes or stops on shutdown |
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
| Public API and specification mapping | Existing Dart maintainers/Aortem | OpenFeature maintainer review |
| Client lifecycle and context coordinator | Client-package contributors | Existing Dart maintainer approval |
| Events, hooks, and in-memory provider | Shared implementation | Conformance tests required |
| Monorepo CI and independent releases | Existing Dart maintainers/Aortem | No server release regression |
| Independent remote providers | External provider maintainers, including Aortem/IntelliToggle | Kept outside core; shared contract suite passes for at least two providers before stable release |
| Pure Dart and Flutter validation | Aortem and client contributors | Core package remains Flutter-free |

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
