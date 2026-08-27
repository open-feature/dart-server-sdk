# Changelog

## 0.0.1-beta.1

- Add the initial static-context client API, provider contract, and hooks.
- Add immutable evaluation types and an in-memory test provider.
- Bound provider lifecycle waits and clean up failed initialization attempts.
- Prevent unsafe provider reuse across APIs and independently scoped contexts.
- Roll back successful providers when a global context change partially fails.
- Preserve error and finally hooks when provider hook discovery fails.
- Add independent prerelease automation and Dart web compilation checks.
