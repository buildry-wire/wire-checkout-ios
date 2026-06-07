import XCTest
@testable import WireCheckout

final class CheckoutEndpointTests: XCTestCase {
    func testParsesValidHostedURL() throws {
        let endpoint = try CheckoutEndpoint(url: URL(string: "https://pay.wire.mn/c/cs_test_abc123")!)
        XCTAssertEqual(endpoint.token, "cs_test_abc123")
        XCTAssertEqual(endpoint.origin.absoluteString, "https://pay.wire.mn")
        XCTAssertEqual(endpoint.statusURL.absoluteString, "https://pay.wire.mn/checkout/cs_test_abc123/status")
    }

    func testParsesURLWithPort() throws {
        let endpoint = try CheckoutEndpoint(
            url: URL(string: "http://localhost:8080/c/tok_1")!,
            allowInsecureLocalhost: true
        )
        XCTAssertEqual(endpoint.token, "tok_1")
        XCTAssertEqual(endpoint.statusURL.absoluteString, "http://localhost:8080/checkout/tok_1/status")
    }

    func testRejectsNonWireHost() {
        XCTAssertThrowsError(try CheckoutEndpoint(url: URL(string: "https://evil.example.com/c/tok")!)) { error in
            XCTAssertEqual(error as? WireCheckoutError, .invalidHost("evil.example.com"))
        }
    }

    func testRejectsLookAlikeHost() {
        // wire.mn.evil.com must not match the wire.mn suffix.
        XCTAssertThrowsError(try CheckoutEndpoint(url: URL(string: "https://wire.mn.evil.com/c/tok")!)) { error in
            XCTAssertEqual(error as? WireCheckoutError, .invalidHost("wire.mn.evil.com"))
        }
    }

    func testRejectsHTTPForProductionHost() {
        XCTAssertThrowsError(try CheckoutEndpoint(url: URL(string: "http://pay.wire.mn/c/tok")!)) { error in
            XCTAssertEqual(error as? WireCheckoutError, .invalidHost("pay.wire.mn"))
        }
    }

    func testRejectsMissingToken() {
        XCTAssertThrowsError(try CheckoutEndpoint(url: URL(string: "https://pay.wire.mn/c/")!)) { error in
            XCTAssertEqual(error as? WireCheckoutError, .invalidURL("https://pay.wire.mn/c/"))
        }
    }

    func testRejectsWrongPathShape() {
        XCTAssertThrowsError(try CheckoutEndpoint(url: URL(string: "https://pay.wire.mn/checkout/tok")!))
    }

    func testRejectsInsecureLocalhostWhenDisallowed() {
        XCTAssertThrowsError(
            try CheckoutEndpoint(url: URL(string: "http://localhost/c/tok")!, allowInsecureLocalhost: false)
        ) { error in
            XCTAssertEqual(error as? WireCheckoutError, .invalidHost("localhost"))
        }
    }

    func testBuildsFromTokenAndBaseURL() throws {
        let endpoint = try CheckoutEndpoint(token: "cs_live_xyz", baseURL: URL(string: "https://pay.wire.mn")!)
        XCTAssertEqual(endpoint.checkoutURL.absoluteString, "https://pay.wire.mn/c/cs_live_xyz")
        XCTAssertEqual(endpoint.statusURL.absoluteString, "https://pay.wire.mn/checkout/cs_live_xyz/status")
    }

    func testRejectsEmptyToken() {
        XCTAssertThrowsError(try CheckoutEndpoint(token: "  ", baseURL: URL(string: "https://pay.wire.mn")!))
    }
}
