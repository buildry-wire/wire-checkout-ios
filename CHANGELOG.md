# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] - 2026-10-12

### Changed
- README: amounts are whole tögrög (MNT integer, no fractional part — `50000` is 50,000 ₮, not 500.00). Examples no longer use the `sandbox` operator or test mode, which the production API does not offer; omitting `allowed_operators` routes to the operators enabled on your project.

## [1.0.0]

### Added
- Initial release of `WireCheckout`.
- `WireCheckout.present(url:callbackScheme:from:)` and
  `present(token:baseURL:callbackScheme:from:)` to show a hosted checkout in
  `ASWebAuthenticationSession` and resolve the outcome.
- Status-API polling state machine (`CheckoutStatusPoller`) treating the status
  endpoint as the source of truth, with cancellable, timeout-bounded polling.
- `CheckoutEndpoint` URL parsing + host validation (`/c/{token}`).
- Typed `WireCheckoutError`, `WireCheckoutResult`, and `CheckoutSessionStatus`.
- Injectable networking (`StatusFetching`) and clock (`CheckoutClock`) seams for
  testing; XCTest suite running on macOS via `swift test`.
