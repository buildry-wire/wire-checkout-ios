// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WireCheckout",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "WireCheckout",
            targets: ["WireCheckout"]
        )
    ],
    targets: [
        .target(
            name: "WireCheckout"
        ),
        .testTarget(
            name: "WireCheckoutTests",
            dependencies: ["WireCheckout"]
        )
    ]
)
