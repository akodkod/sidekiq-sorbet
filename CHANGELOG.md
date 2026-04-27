## [Unreleased]

## [1.0.0] - 2026-04-27

### Fixed

- `run_async`, `run_at`, and `run_in` now correctly declare their return type
  as `T.nilable(String)`. Sidekiq's `perform_async`/`perform_at`/`perform_in`
  return `nil` when a client middleware halts enqueueing, which previously
  triggered a sig violation. Note: this is a breaking signature change for
  callers that relied on the non-nilable `String` return type.

## [0.2.0] - 2025-12-16

### Added

- `run_at` and `run_in` methods

## [0.1.0] - 2025-12-16

- Initial release
