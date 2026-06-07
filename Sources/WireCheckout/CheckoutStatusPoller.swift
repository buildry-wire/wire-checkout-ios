import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The platform-agnostic polling state machine. Given a status endpoint, it
/// repeatedly fetches the `checkout.session.status` resource and resolves a
/// ``WireCheckoutResult`` once `payment_status` reaches a terminal value.
///
/// This type contains no UIKit / AuthenticationServices dependency so it builds
/// and is fully testable on macOS and Linux.
public struct CheckoutStatusPoller: Sendable {
    private let endpoint: CheckoutEndpoint
    private let configuration: WireCheckoutConfiguration
    private let fetcher: StatusFetching
    private let clock: CheckoutClock
    private let decoder: JSONDecoder

    public init(
        endpoint: CheckoutEndpoint,
        configuration: WireCheckoutConfiguration = .default,
        fetcher: StatusFetching,
        clock: CheckoutClock = SystemCheckoutClock()
    ) {
        self.endpoint = endpoint
        self.configuration = configuration
        self.fetcher = fetcher
        self.clock = clock
        self.decoder = JSONDecoder()
    }

    /// Payment statuses that are still in flight; keep polling.
    static let nonTerminalPaymentStatuses: Set<String> = ["requires_payment", "processing"]

    /// Fetch the status once, with no polling. Used for the final poll after the
    /// browser session returns or is dismissed.
    public func fetchOnce() async throws -> CheckoutSessionStatus {
        let (data, response) = try await fetcher.fetch(endpoint.statusURL)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw WireCheckoutError.httpStatus(http.statusCode)
        }
        do {
            return try decoder.decode(CheckoutSessionStatus.self, from: data)
        } catch {
            throw WireCheckoutError.decoding(String(describing: error))
        }
    }

    /// Map a status payload to a terminal result, or `nil` if still pending.
    public static func resolve(_ status: CheckoutSessionStatus) -> WireCheckoutResult? {
        if nonTerminalPaymentStatuses.contains(status.paymentStatus) {
            return nil
        }
        let outcome: WireCheckoutResult.Status
        switch status.paymentStatus {
        case "succeeded":
            outcome = .completed
        case "canceled", "cancelled":
            outcome = .canceled
        default:
            // failed, requires_action that can't proceed, expired, etc.
            outcome = .failed
        }
        return WireCheckoutResult(
            status: outcome,
            paymentStatus: status.paymentStatus,
            redirectURL: status.redirectURL
        )
    }

    /// Poll until a terminal result is reached or the timeout elapses. Honors
    /// task cancellation between polls.
    public func poll() async throws -> WireCheckoutResult {
        let deadline = clock.now().addingTimeInterval(configuration.timeout)

        while true {
            try Task.checkCancellation()

            let status = try await fetchOnce()
            if let result = CheckoutStatusPoller.resolve(status) {
                return result
            }

            // Non-terminal: ensure we still have time for another poll.
            let next = clock.now().addingTimeInterval(configuration.pollInterval)
            if next > deadline {
                throw WireCheckoutError.timeout
            }
            try await clock.sleep(seconds: configuration.pollInterval)
        }
    }
}
