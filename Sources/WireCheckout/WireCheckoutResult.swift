import Foundation

/// The terminal outcome of a hosted checkout, derived from the status API —
/// never from the redirect alone.
public struct WireCheckoutResult: Equatable, Sendable {
    /// High-level outcome.
    public enum Status: String, Equatable, Sendable {
        case completed
        case canceled
        case failed
    }

    /// Resolved outcome.
    public let status: Status

    /// The raw `payment_status` from the status API (e.g. `succeeded`,
    /// `canceled`, `requires_payment`).
    public let paymentStatus: String

    /// The redirect target reported by the hosted page, if any.
    public let redirectURL: URL?

    public init(status: Status, paymentStatus: String, redirectURL: URL? = nil) {
        self.status = status
        self.paymentStatus = paymentStatus
        self.redirectURL = redirectURL
    }
}
