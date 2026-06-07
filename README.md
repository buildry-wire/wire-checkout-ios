# WireCheckout (iOS)

A lightweight, client-side Swift SDK that presents a **Wire hosted checkout** in
a secure in-app browser and resolves the outcome from the authoritative status
API. No secret key ever lives in your app.

- Presents the hosted checkout in `ASWebAuthenticationSession`.
- Treats the **status API as the source of truth** — not the browser redirect.
- `async`/`await`, typed errors, Swift Package Manager (and CocoaPods).
- iOS 14+. The polling state machine and URL parsing are platform-agnostic and
  test on macOS.

## How it fits together

1. Your backend creates a checkout session **server-side** (with its secret
   key) and gets back a hosted URL like `https://pay.wire.mn/c/{token}`.
2. Your app receives that URL (or a `{ token, baseURL }` pair).
3. This SDK presents it, then polls
   `GET {origin}/checkout/{token}/status` until the payment reaches a terminal
   state and returns a `WireCheckoutResult`.

> The app never creates the session and never holds a secret key.

## Install

### Swift Package Manager

In Xcode: **File → Add Package Dependencies…** and enter:

```
https://github.com/buildry-wire/wire-checkout-ios
```

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/buildry-wire/wire-checkout-ios", from: "0.1.0")
]
```

### CocoaPods

```ruby
pod 'WireCheckout', '~> 0.1'
```

## Quickstart

Register a custom URL scheme for the return deeplink (e.g. `myapp`) in your
app's Info settings, then:

```swift
import WireCheckout

let checkout = WireCheckout()

// `url` and the matching scheme come from your backend / app config.
let result = try await checkout.present(
    url: url,                 // https://pay.wire.mn/c/{token}
    callbackScheme: "myapp",
    from: view.window!        // any ASPresentationAnchor
)

switch result.status {
case .completed:
    // result.paymentStatus == "succeeded"
case .canceled:
    break
case .failed:
    break
}
```

You can also start from a token + origin:

```swift
let result = try await checkout.present(
    token: token,
    baseURL: URL(string: "https://pay.wire.mn")!,
    callbackScheme: "myapp",
    from: anchor
)
```

### Configuration

```swift
let checkout = WireCheckout(
    configuration: WireCheckoutConfiguration(
        pollInterval: 2,   // seconds between status polls
        timeout: 600       // give up after 10 minutes
    )
)
```

### Errors

All failures surface as `WireCheckoutError` (`.invalidURL`, `.invalidHost`,
`.network`, `.httpStatus`, `.decoding`, `.timeout`, `.presentation`).

## Notes on operators

Which payment operators a buyer sees is determined by **the operators enabled on
your account**. In test/sandbox flows, operators appear as `["sandbox"]`.

## Documentation

Full guides at [docs.wire.mn](https://docs.wire.mn).

## License

MIT — see [LICENSE](LICENSE).
