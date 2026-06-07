import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

/// Presents a Wire **hosted checkout** in a secure in-app browser and resolves
/// the outcome from the authoritative status API.
///
/// The merchant's backend creates the checkout session server-side (with its
/// secret key) and hands the resulting hosted URL to the app. This SDK is
/// purely client-side and never handles a secret key.
///
/// ```swift
/// let checkout = WireCheckout()
/// let result = try await checkout.present(
///     url: url,
///     callbackScheme: "myapp",
///     from: anchor
/// )
/// switch result.status {
/// case .completed: // payment succeeded
/// case .canceled:  // buyer canceled
/// case .failed:    // payment failed
/// }
/// ```
public final class WireCheckout: @unchecked Sendable {
    private let configuration: WireCheckoutConfiguration
    private let fetcher: StatusFetching
    private let clock: CheckoutClock

    /// Create a checkout client.
    /// - Parameters:
    ///   - configuration: poll interval, timeout, transport security.
    ///   - fetcher: networking seam (defaults to a shared `URLSession`).
    ///   - clock: polling clock (defaults to the system clock).
    public init(
        configuration: WireCheckoutConfiguration = .default,
        fetcher: StatusFetching = URLSession(configuration: .ephemeral),
        clock: CheckoutClock = SystemCheckoutClock()
    ) {
        self.configuration = configuration
        self.fetcher = fetcher
        self.clock = clock
    }

    /// Build a poller for a parsed endpoint. Exposed so the polling state
    /// machine can be exercised independently of any UI.
    public func poller(for endpoint: CheckoutEndpoint) -> CheckoutStatusPoller {
        CheckoutStatusPoller(
            endpoint: endpoint,
            configuration: configuration,
            fetcher: fetcher,
            clock: clock
        )
    }
}

#if canImport(AuthenticationServices) && canImport(UIKit)
@available(iOS 14.0, *)
extension WireCheckout {
    /// Present the hosted checkout located at `url`.
    /// - Parameters:
    ///   - url: hosted checkout URL of the form `{origin}/c/{token}`.
    ///   - callbackScheme: the custom URL scheme your app registers for the
    ///     return deeplink (without `://`).
    ///   - anchor: the presentation anchor (typically a window).
    @MainActor
    public func present(
        url: URL,
        callbackScheme: String,
        from anchor: ASPresentationAnchor
    ) async throws -> WireCheckoutResult {
        let endpoint = try CheckoutEndpoint(url: url, allowInsecureLocalhost: configuration.allowInsecureLocalhost)
        return try await present(endpoint: endpoint, callbackScheme: callbackScheme, from: anchor)
    }

    /// Present using a `{ token, baseURL }` pair instead of a full URL.
    @MainActor
    public func present(
        token: String,
        baseURL: URL,
        callbackScheme: String,
        from anchor: ASPresentationAnchor
    ) async throws -> WireCheckoutResult {
        let endpoint = try CheckoutEndpoint(token: token, baseURL: baseURL, allowInsecureLocalhost: configuration.allowInsecureLocalhost)
        return try await present(endpoint: endpoint, callbackScheme: callbackScheme, from: anchor)
    }

    @MainActor
    private func present(
        endpoint: CheckoutEndpoint,
        callbackScheme: String,
        from anchor: ASPresentationAnchor
    ) async throws -> WireCheckoutResult {
        // Drive the in-app browser. We do NOT trust its return payload — once it
        // returns (callback scheme) or the user dismisses it, we do a final
        // authoritative status poll. We also race a background poller so a
        // payment that completes while the sheet is open resolves promptly.
        let presenter = WebAuthPresenter(anchor: anchor)
        let poller = poller(for: endpoint)

        return try await withThrowingTaskGroup(of: WireCheckoutResult?.self) { group in
            // Background poll: resolves if the status reaches terminal while the
            // browser is open.
            group.addTask {
                do {
                    return try await poller.poll()
                } catch is CancellationError {
                    return nil
                }
            }

            // Browser session: resolves (or is dismissed) → final status poll.
            group.addTask { @MainActor in
                _ = try? await presenter.start(url: endpoint.checkoutURL, callbackScheme: callbackScheme)
                // Authoritative final poll regardless of how the sheet closed.
                let status = try await poller.fetchOnce()
                return CheckoutStatusPoller.resolve(status)
                    ?? WireCheckoutResult(status: .canceled, paymentStatus: status.paymentStatus, redirectURL: status.redirectURL)
            }

            // Take the first non-nil result, cancel the rest.
            for try await value in group {
                if let result = value {
                    group.cancelAll()
                    return result
                }
            }
            group.cancelAll()
            throw WireCheckoutError.timeout
        }
    }
}

/// Thin wrapper around `ASWebAuthenticationSession`. Isolated here so the rest
/// of the SDK stays platform-agnostic.
@available(iOS 14.0, *)
@MainActor
final class WebAuthPresenter: NSObject, ASWebAuthenticationSessionPresentationContextProviding {
    private let anchor: ASPresentationAnchor
    private var session: ASWebAuthenticationSession?

    init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
        super.init()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor
    }

    /// Start the session and resume when the callback fires or the user
    /// dismisses. Returns the callback URL, if any.
    func start(url: URL, callbackScheme: String) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    // User dismissed; treat as a normal close so the caller can
                    // run a final status poll.
                    continuation.resume(returning: nil)
                    return
                }
                if let error = error {
                    continuation.resume(throwing: WireCheckoutError.presentation(String(describing: error)))
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            if !session.start() {
                continuation.resume(throwing: WireCheckoutError.presentation("ASWebAuthenticationSession failed to start"))
            }
        }
    }
}
#endif
