# Evaluation context snapshots

This is the context-integrity implementation for
[#159](https://github.com/open-feature/dart-sdk/issues/159), based on
[OpenFeature v0.9.0 section 3](https://github.com/open-feature/spec/blob/v0.9.0/specification/sections/03-evaluation-context.md).
It is not a full SDK conformance claim.

## Canonical construction

Use `EvaluationContext.immutable` for new code. It captures a defensive copy at
construction, including every nested map/list and the entire parent chain:

```dart
import 'package:openfeature_dart_server_sdk/evaluation_context.dart';
import 'package:openfeature_dart_server_sdk/open_feature_api.dart';

final attributes = <String, dynamic>{
  'account': {'plan': 'standard'},
  'groups': ['riders'],
  'joinedAt': DateTime.utc(2026, 9, 15),
};
final context = EvaluationContext.immutable(
  targetingKey: 'rider-123',
  attributes: attributes,
);
final api = OpenFeatureAPI();
api.setEvaluationContext(context);
final client = api.getClient('matching');
final enabled = await client.getBooleanFlag(
  'matching-enabled', defaultValue: false, context: context,
);
```

`attributes` provides all local custom fields; `getAttribute` also searches
parents. `toProviderContext()` returns the complete immutable provider map,
including the effective `targetingKey`. The reserved map key is accepted as a
legacy input alias and normalized to the canonical string field. An explicit
`targetingKey` constructor argument wins at the same level. When merging
levels, the later level wins, including a key inherited from its parent chain.

Supported custom values are Dart `bool`, `String`, `num`, `DateTime`, string-keyed
maps, and lists. Structures may contain these values recursively and JSON-style
nested nulls. Top-level null fields, arbitrary objects, functions, sets,
non-string map keys, and cyclic structures throw `ArgumentError`; callers must
convert them deliberately. Dates retain their Dart instant/timezone and are
not implicitly serialized. Provider-specific serialization stays in providers.
This is the SDK's Dart representation of the specification's structure type.

## Existing callers

The existing `const EvaluationContext(attributes: ...)` constructor remains
source-compatible. It does **not** snapshot caller-owned data at construction;
the SDK captures it at these boundaries:

- Client construction: API/default client context.
- `setEvaluationContext` or legacy `setGlobalContext`: global context.
- Transaction construction: request-local context.
- Evaluation entry, before the first hook awaits: invocation context.
- Each before-hook return: fields visible to later hooks and the provider.

For immediate isolation, replace `const EvaluationContext(...)` with
`EvaluationContext.immutable(...)`, or call `.snapshot()` on a legacy value.
Both use the same public context type. SDK-supplied context maps are deeply
read-only: hooks contribute by returning new fields, and providers must copy a
map if they need a mutable working buffer.

`OpenFeatureEvaluationContext(map, targetingKey: ...)` remains a positional-map
adapter backed by the canonical immutable context. Its `merge` and
`toEvaluationContext` methods use the canonical implementation. Its `attributes`
contains custom fields; access the reserved key through `targetingKey`.
`setGlobalContext` remains available. New code can pass the canonical value to
`setEvaluationContext` and read it through `evaluationContext`.

No analyzer deprecation or removal date is introduced in this additive stage.
A later, separately reviewed release can deprecate the legacy constructor and
adapter after downstream migration. Legacy local targeting-rule objects and
directly constructed diagnostic `HookContext` values are outside this snapshot
contract; this change freezes evaluation fields at SDK boundaries, not every
arbitrary object accepted by older helper APIs.

Invalid legacy invocation data or invalid before-hook contributions follow the
existing evaluation-error path: the application default is returned with an
error, without calling the provider. Invalid data supplied to context/client/
transaction construction or global setters throws before changing stored state.

## Runtime checks

`test/context_regression_test.dart` reproduces nested global/transaction aliases
and lost parent fields from the previous implementation.
`test/context_contract_test.dart` covers 3.1.1-3.1.4, 3.2.1.1 and 3.2.3: allowed
and rejected types, deep copies, immutable accessors, complete parent merging,
all five precedence levels including targeting keys, late global replacement,
and caller mutation while a hook is suspended. Controlled overlapping requests
verify Dart-zone transaction isolation without timing-based sleeps.

The experimental propagator registration/lifecycle requirements in section 3.3,
complete hook registration/order semantics (#161), and shutdown/independent API
isolation (#163) remain separate work. Keeping the legacy constructor means this
release does not claim every publicly constructed legacy object is immutable.
