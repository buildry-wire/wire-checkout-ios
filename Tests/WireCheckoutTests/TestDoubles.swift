import Foundation
import XCTest
@testable import WireCheckout

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A scripted fetcher: returns queued responses in order, recording every URL
/// it was asked to fetch. When the script is exhausted it repeats the last
/// response (useful for "stay pending forever" timeout tests).
final class MockFetcher: StatusFetching, @unchecked Sendable {
    enum Step {
        case json(String, statusCode: Int)
        case failure(WireCheckoutError)
    }

    private let lock = NSLock()
    private var steps: [Step]
    private var index = 0
    private(set) var requestedURLs: [URL] = []
    let repeatLast: Bool

    init(steps: [Step], repeatLast: Bool = false) {
        self.steps = steps
        self.repeatLast = repeatLast
    }

    var callCount: Int {
        lock.lock(); defer { lock.unlock() }
        return requestedURLs.count
    }

    func fetch(_ url: URL) async throws -> (Data, URLResponse) {
        lock.lock()
        requestedURLs.append(url)
        let step: Step
        if index < steps.count {
            step = steps[index]
            index += 1
        } else if repeatLast, let last = steps.last {
            step = last
        } else if let last = steps.last {
            step = last
        } else {
            lock.unlock()
            throw WireCheckoutError.network("no scripted response")
        }
        lock.unlock()

        switch step {
        case .failure(let error):
            throw error
        case .json(let body, let statusCode):
            let data = Data(body.utf8)
            let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (data, response)
        }
    }
}

/// A clock that never actually waits and advances a virtual `now` on each sleep.
/// This lets timeout logic be tested deterministically and instantly.
final class FakeClock: CheckoutClock, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date
    private(set) var sleeps: [TimeInterval] = []

    init(start: Date = Date(timeIntervalSince1970: 0)) {
        self.current = start
    }

    func now() -> Date {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    func sleep(seconds: TimeInterval) async throws {
        try Task.checkCancellation()
        lock.lock()
        sleeps.append(seconds)
        current = current.addingTimeInterval(seconds)
        lock.unlock()
    }
}

func statusJSON(status: String, paymentStatus: String, redirectURL: String? = nil) -> String {
    var fields = """
    "object":"checkout.session.status","status":"\(status)","payment_status":"\(paymentStatus)"
    """
    if let redirectURL {
        fields += ",\"redirect_url\":\"\(redirectURL)\""
    }
    return "{\(fields)}"
}
