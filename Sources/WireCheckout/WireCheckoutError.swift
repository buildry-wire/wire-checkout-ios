import Foundation

/// Errors surfaced by ``WireCheckout``.
public enum WireCheckoutError: Error, Equatable, Sendable {
    /// The supplied checkout URL was malformed or did not match the expected
    /// `/c/{token}` shape.
    case invalidURL(String)

    /// The checkout URL host was not an allowed Wire checkout host.
    case invalidHost(String)

    /// A networking failure occurred while talking to the status API.
    case network(String)

    /// The status API returned a non-2xx HTTP status.
    case httpStatus(Int)

    /// The status API response body could not be decoded.
    case decoding(String)

    /// Polling exceeded the configured timeout before reaching a terminal state.
    case timeout

    /// The in-app browser presentation failed to start or returned an error.
    case presentation(String)

    /// The presentation is only available on platforms with an in-app browser
    /// (iOS). Logic + status polling remain available everywhere.
    case unsupportedPlatform
}

extension WireCheckoutError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let value):
            return "Invalid checkout URL: \(value)"
        case .invalidHost(let host):
            return "Checkout host is not allowed: \(host)"
        case .network(let message):
            return "Network error: \(message)"
        case .httpStatus(let code):
            return "Unexpected HTTP status: \(code)"
        case .decoding(let message):
            return "Failed to decode status response: \(message)"
        case .timeout:
            return "Timed out waiting for the checkout to reach a final state."
        case .presentation(let message):
            return "Could not present the checkout: \(message)"
        case .unsupportedPlatform:
            return "Presenting a hosted checkout requires iOS."
        }
    }
}
