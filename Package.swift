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
        .package(url: "https://github.com/felfoldy/SwiftPy", from: "0.14.0"),
        .package(url: "https://github.com/felfoldy/SwiftPyConsole", branch: "main")
    ],
    targets: [
        .target(
            name: "SwiftPyRequests",
            dependencies: ["SwiftPy", "SwiftPyConsole"],
        ),
    ]
)
