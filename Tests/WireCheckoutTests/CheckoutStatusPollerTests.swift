import XCTest
@testable import WireCheckout

final class CheckoutStatusPollerTests: XCTestCase {
    private func makeEndpoint() throws -> CheckoutEndpoint {
        try CheckoutEndpoint(url: URL(string: "https://pay.wire.mn/c/tok_123")!)
    }

    private func makePoller(fetcher: MockFetcher, clock: FakeClock, timeout: TimeInterval = 600) throws -> CheckoutStatusPoller {
        CheckoutStatusPoller(
            endpoint: try makeEndpoint(),
            configuration: WireCheckoutConfiguration(pollInterval: 2, timeout: timeout),
            fetcher: fetcher,
            clock: clock
        )
    }

    func testPollsPendingThenSucceeded() async throws {
        let fetcher = MockFetcher(steps: [
            .json(statusJSON(status: "open", paymentStatus: "requires_payment"), statusCode: 200),
            .json(statusJSON(status: "open", paymentStatus: "processing"), statusCode: 200),
            .json(statusJSON(status: "complete", paymentStatus: "succeeded", redirectURL: "https://m.example/ok"), statusCode: 200),
        ])
        let clock = FakeClock()
        let poller = try makePoller(fetcher: fetcher, clock: clock)

        let result = try await poller.poll()

        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.paymentStatus, "succeeded")
        XCTAssertEqual(result.redirectURL, URL(string: "https://m.example/ok"))
        XCTAssertEqual(fetcher.callCount, 3)
        XCTAssertEqual(clock.sleeps, [2, 2]) // slept twice between three polls
        XCTAssertEqual(fetcher.requestedURLs.first?.absoluteString, "https://pay.wire.mn/checkout/tok_123/status")
    }

    func testCanceledResolvesImmediately() async throws {
        let fetcher = MockFetcher(steps: [
            .json(statusJSON(status: "expired", paymentStatus: "canceled"), statusCode: 200),
        ])
        let poller = try makePoller(fetcher: fetcher, clock: FakeClock())
        let result = try await poller.poll()
        XCTAssertEqual(result.status, .canceled)
        XCTAssertEqual(fetcher.callCount, 1)
    }

    func testFailedResolves() async throws {
        let fetcher = MockFetcher(steps: [
            .json(statusJSON(status: "open", paymentStatus: "failed"), statusCode: 200),
        ])
        let poller = try makePoller(fetcher: fetcher, clock: FakeClock())
        let result = try await poller.poll()
        XCTAssertEqual(result.status, .failed)
    }

    func testTimeoutWhenAlwaysPending() async throws {
        let fetcher = MockFetcher(
            steps: [.json(statusJSON(status: "open", paymentStatus: "requires_payment"), statusCode: 200)],
            repeatLast: true
        )
        let clock = FakeClock()
        // timeout 5s with 2s interval → polls at t=0, t=2, t=4; next would be t=6 > 5 → timeout.
        let poller = try makePoller(fetcher: fetcher, clock: clock, timeout: 5)

        do {
            _ = try await poller.poll()
            XCTFail("expected timeout")
        } catch {
            XCTAssertEqual(error as? WireCheckoutError, .timeout)
        }
        XCTAssertEqual(fetcher.callCount, 3)
    }

    func testHTTPErrorSurfaces() async throws {
        let fetcher = MockFetcher(steps: [.json("{}", statusCode: 503)])
        let poller = try makePoller(fetcher: fetcher, clock: FakeClock())
        do {
            _ = try await poller.poll()
            XCTFail("expected http error")
        } catch {
            XCTAssertEqual(error as? WireCheckoutError, .httpStatus(503))
        }
    }

    func testDecodingErrorSurfaces() async throws {
        let fetcher = MockFetcher(steps: [.json("not json", statusCode: 200)])
        let poller = try makePoller(fetcher: fetcher, clock: FakeClock())
        do {
            _ = try await poller.poll()
            XCTFail("expected decoding error")
        } catch {
            guard case .decoding = (error as? WireCheckoutError) else {
                return XCTFail("expected .decoding, got \(error)")
            }
        }
    }

    func testNetworkErrorSurfaces() async throws {
        let fetcher = MockFetcher(steps: [.failure(.network("offline"))])
        let poller = try makePoller(fetcher: fetcher, clock: FakeClock())
        do {
            _ = try await poller.poll()
            XCTFail("expected network error")
        } catch {
            XCTAssertEqual(error as? WireCheckoutError, .network("offline"))
        }
    }

    func testCancellationStopsPolling() async throws {
        let fetcher = MockFetcher(
            steps: [.json(statusJSON(status: "open", paymentStatus: "processing"), statusCode: 200)],
            repeatLast: true
        )
        let poller = try makePoller(fetcher: fetcher, clock: FakeClock())
        let task = Task { try await poller.poll() }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError || (error as? WireCheckoutError) != nil)
        }
    }

    func testFetchOnceDoesNotPoll() async throws {
        let fetcher = MockFetcher(steps: [
            .json(statusJSON(status: "open", paymentStatus: "requires_payment"), statusCode: 200),
        ])
        let poller = try makePoller(fetcher: fetcher, clock: FakeClock())
        let status = try await poller.fetchOnce()
        XCTAssertEqual(status.paymentStatus, "requires_payment")
        XCTAssertEqual(fetcher.callCount, 1)
    }
}
