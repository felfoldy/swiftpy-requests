// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swiftpy-requests",
    platforms: [.iOS(.v26), .macOS(.v26), .visionOS(.v26)],
    products: [
        .library(
            name: "SwiftPyRequests",
            targets: ["SwiftPyRequests"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/felfoldy/SwiftPy", from: "0.30.0"),
    ],
    targets: [
        .target(
            name: "SwiftPyRequests",
            dependencies: ["SwiftPy"],
            resources: [.copy("requests.exceptions.py")]
        ),
        .testTarget(
            name: "SwiftPyRequestsTests",
            dependencies: ["SwiftPyRequests"]
        ),
    ]
)
