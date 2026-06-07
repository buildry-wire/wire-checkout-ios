import XCTest
@testable import WireCheckout

final class StatusDecodingTests: XCTestCase {
    private func decode(_ json: String) throws -> CheckoutSessionStatus {
        try JSONDecoder().decode(CheckoutSessionStatus.self, from: Data(json.utf8))
    }

    func testDecodesFullPayload() throws {
        let status = try decode(statusJSON(
            status: "complete",
            paymentStatus: "succeeded",
            redirectURL: "https://merchant.example/return"
        ))
        XCTAssertEqual(status.object, "checkout.session.status")
        XCTAssertEqual(status.status, "complete")
        XCTAssertEqual(status.paymentStatus, "succeeded")
        XCTAssertEqual(status.redirectURL, URL(string: "https://merchant.example/return"))
    }

    func testDecodesWithoutRedirect() throws {
        let status = try decode(statusJSON(status: "open", paymentStatus: "requires_payment"))
        XCTAssertNil(status.redirectURL)
        XCTAssertEqual(status.paymentStatus, "requires_payment")
    }

    func testResolveSucceededIsCompleted() {
        let result = CheckoutStatusPoller.resolve(
            CheckoutSessionStatus(object: "checkout.session.status", status: "complete", paymentStatus: "succeeded")
        )
        XCTAssertEqual(result?.status, .completed)
    }

    func testResolveCanceled() {
        let result = CheckoutStatusPoller.resolve(
            CheckoutSessionStatus(object: "checkout.session.status", status: "expired", paymentStatus: "canceled")
        )
        XCTAssertEqual(result?.status, .canceled)
    }

    func testResolveFailed() {
        let result = CheckoutStatusPoller.resolve(
            CheckoutSessionStatus(object: "checkout.session.status", status: "open", paymentStatus: "failed")
        )
        XCTAssertEqual(result?.status, .failed)
    }

    func testResolvePendingReturnsNil() {
        for pending in ["requires_payment", "processing"] {
            let result = CheckoutStatusPoller.resolve(
                CheckoutSessionStatus(object: "checkout.session.status", status: "open", paymentStatus: pending)
            )
            XCTAssertNil(result, "\(pending) should be non-terminal")
        }
    }
}
