import Foundation

/// Tunables for ``WireCheckout``.
public struct WireCheckoutConfiguration: Sendable {
    /// Interval between status polls. Defaults to 2 seconds.
    public var pollInterval: TimeInterval

    /// Maximum total time to keep polling before raising
    /// ``WireCheckoutError/timeout``. Defaults to 10 minutes.
    public var timeout: TimeInterval

    /// Whether to allow plain-`http` localhost origins. Useful for local
    /// development and tests; should stay `false` in production. Production
    /// (non-localhost) hosts always require `https`.
    public var allowInsecureLocalhost: Bool

    public init(
        pollInterval: TimeInterval = 2,
        timeout: TimeInterval = 600,
        allowInsecureLocalhost: Bool = false
    ) {
        self.pollInterval = pollInterval
        self.timeout = timeout
        self.allowInsecureLocalhost = allowInsecureLocalhost
    }

    public static let `default` = WireCheckoutConfiguration()
}
