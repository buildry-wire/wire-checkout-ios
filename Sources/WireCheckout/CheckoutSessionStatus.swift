import Foundation

/// The raw `checkout.session.status` resource returned by
/// `GET {origin}/checkout/{token}/status`.
///
/// ```json
/// {
///   "object": "checkout.session.status",
///   "status": "open",
///   "payment_status": "requires_payment",
///   "redirect_url": "https://merchant.example/return"
/// }
/// ```
public struct CheckoutSessionStatus: Decodable, Equatable, Sendable {
    /// Always `"checkout.session.status"`.
    public let object: String

    /// Lifecycle of the session itself (e.g. `open`, `complete`, `expired`).
    public let status: String

    /// Payment progress. The state machine keys off this field.
    public let paymentStatus: String

    /// Where the hosted page redirected the buyer once the flow finished.
    public let redirectURL: URL?

    enum CodingKeys: String, CodingKey {
        case object
        case status
        case paymentStatus = "payment_status"
        case redirectURL = "redirect_url"
    }

    public init(object: String, status: String, paymentStatus: String, redirectURL: URL? = nil) {
        self.object = object
        self.status = status
        self.paymentStatus = paymentStatus
        self.redirectURL = redirectURL
    }
}
