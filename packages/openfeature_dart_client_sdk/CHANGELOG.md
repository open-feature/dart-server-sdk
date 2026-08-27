# Changelog

## 0.0.1-beta.1

- Add the initial static-context client API, provider contract, and hooks.
- Add immutable evaluation types and an in-memory test provider.
- Bound provider lifecycle and cleanup waits; quarantine timed-out instances so
  late asynchronous work cannot corrupt a later operation.
- Prevent unsafe provider reuse across APIs and independently scoped contexts.
- Roll back successful providers when a global context change partially fails.
- Preserve error and finally hooks when provider hook discovery fails.
- Add independent prerelease automation and Dart web compilation checks.
