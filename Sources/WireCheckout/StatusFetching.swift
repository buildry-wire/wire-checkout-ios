import Foundation

/// A minimal, injectable networking seam so the poller can be tested without
/// touching the network. `URLSession` conforms via an extension below.
public protocol StatusFetching: Sendable {
    /// Fetch the bytes + response for a `GET` of `url`.
    func fetch(_ url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: StatusFetching {
    public func fetch(_ url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        #if canImport(FoundationNetworking)
        // Linux: data(for:) is available on recent toolchains; fall through.
        #endif
        return try await data(for: request)
    }
}

/// Abstraction over "sleep for N seconds" so polling can use a controllable
/// clock in tests instead of real wall-clock waits.
public protocol CheckoutClock: Sendable {
    func sleep(seconds: TimeInterval) async throws
    func now() -> Date
}

/// Real clock backed by `Task.sleep` and `Date()`.
public struct SystemCheckoutClock: CheckoutClock {
    public init() {}

    public func sleep(seconds: TimeInterval) async throws {
        let nanos = UInt64((seconds * 1_000_000_000).rounded())
        try await Task.sleep(nanoseconds: nanos)
    }

    public func now() -> Date { Date() }
}
