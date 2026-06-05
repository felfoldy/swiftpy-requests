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

        .library(
            name: "SwiftPyGit",
            targets: ["SwiftPyGit"]
        ),

        .library(
            name: "SwiftPyPackages",
            targets: [
                "SwiftPyPackages",
                "SwiftPyRequests",
                "SwiftPyGit"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/felfoldy/SwiftPy", from: "0.22.1"),
        .package(url: "https://github.com/ibrahimcetin/libgit2.git", exact: "1.9.2"),
        // .package(url: "https://github.com/ibrahimcetin/SwiftGitX", branch: "main"),
    ],
    targets: [
        .target(
            name: "SwiftPyRequests",
            dependencies: ["SwiftPy"],
        ),
        .target(
            name: "SwiftPyGit",
            dependencies: ["SwiftPy", "libgit2"]
        ),
        .target(
            name: "SwiftPyPackages",
            dependencies: ["SwiftPy", "SwiftPyGit", "SwiftPyRequests"],
            resources: [.copy("packages.py")]
        ),
    ]
)
