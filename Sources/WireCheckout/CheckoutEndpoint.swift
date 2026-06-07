import Foundation

/// A parsed and validated hosted-checkout location.
///
/// A hosted checkout URL looks like `https://pay.wire.mn/c/{token}`. From it we
/// derive the `origin` (scheme + host + optional port) and the `token`, which
/// together build the status endpoint `{origin}/checkout/{token}/status`.
public struct CheckoutEndpoint: Equatable, Sendable {
    /// Scheme + host (+ port) — e.g. `https://pay.wire.mn`.
    public let origin: URL

    /// The opaque checkout token from the `/c/{token}` path.
    public let token: String

    /// The full hosted checkout URL to present in the browser.
    public let checkoutURL: URL

    /// `GET` this to learn the authoritative status.
    public var statusURL: URL {
        origin.appendingPathComponent("checkout")
            .appendingPathComponent(token)
            .appendingPathComponent("status")
    }

    /// Hosts permitted for a hosted checkout. `https` is required for any host
    /// other than `localhost` (used in tests / local development).
    static let allowedHostSuffixes = ["wire.mn"]

    /// Parse a full hosted-checkout URL of the form `{origin}/c/{token}`.
    public init(url: URL, allowInsecureLocalhost: Bool = true) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased() else {
            throw WireCheckoutError.invalidURL(url.absoluteString)
        }

        let isLocalhost = host == "localhost" || host == "127.0.0.1"
        try CheckoutEndpoint.validate(scheme: scheme, host: host, isLocalhost: isLocalhost, allowInsecureLocalhost: allowInsecureLocalhost, raw: url.absoluteString)

        // Path must be /c/{token} with a non-empty token.
        let segments = components.percentEncodedPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        guard segments.count == 2, segments[0] == "c", !segments[1].isEmpty else {
            throw WireCheckoutError.invalidURL(url.absoluteString)
        }
        guard let token = segments[1].removingPercentEncoding, !token.isEmpty else {
            throw WireCheckoutError.invalidURL(url.absoluteString)
        }

        var originComponents = URLComponents()
        originComponents.scheme = scheme
        originComponents.host = host
        originComponents.port = components.port
        guard let origin = originComponents.url else {
            throw WireCheckoutError.invalidURL(url.absoluteString)
        }

        self.origin = origin
        self.token = token
        self.checkoutURL = url
    }

    /// Build an endpoint from a `{ token, baseURL }` pair. `baseURL` is the
    /// origin (e.g. `https://pay.wire.mn`).
    public init(token: String, baseURL: URL, allowInsecureLocalhost: Bool = true) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw WireCheckoutError.invalidURL("empty token")
        }
        guard let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased() else {
            throw WireCheckoutError.invalidURL(baseURL.absoluteString)
        }

        let isLocalhost = host == "localhost" || host == "127.0.0.1"
        try CheckoutEndpoint.validate(scheme: scheme, host: host, isLocalhost: isLocalhost, allowInsecureLocalhost: allowInsecureLocalhost, raw: baseURL.absoluteString)

        var originComponents = URLComponents()
        originComponents.scheme = scheme
        originComponents.host = host
        originComponents.port = components.port
        guard let origin = originComponents.url else {
            throw WireCheckoutError.invalidURL(baseURL.absoluteString)
        }

        guard let checkoutURL = origin.appendingPathComponent("c").appendingPathComponent(trimmed) as URL? else {
            throw WireCheckoutError.invalidURL(baseURL.absoluteString)
        }

        self.origin = origin
        self.token = trimmed
        self.checkoutURL = checkoutURL
    }

    private static func validate(scheme: String, host: String, isLocalhost: Bool, allowInsecureLocalhost: Bool, raw: String) throws {
        if isLocalhost {
            if !allowInsecureLocalhost && scheme != "https" {
                throw WireCheckoutError.invalidHost(host)
            }
            return
        }

        guard scheme == "https" else {
            throw WireCheckoutError.invalidHost(host)
        }
        let allowed = allowedHostSuffixes.contains { suffix in
            host == suffix || host.hasSuffix("." + suffix)
        }
        guard allowed else {
            throw WireCheckoutError.invalidHost(host)
        }
    }
}
