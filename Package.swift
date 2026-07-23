// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SnapSync",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SnapSyncCore", targets: ["SnapSyncCore"]),
        .executable(name: "snapsync", targets: ["SnapSyncCLI"])
    ],
    targets: [
        .target(name: "SnapSyncCore"),
        .executableTarget(name: "SnapSyncCLI", dependencies: ["SnapSyncCore"]),
        .testTarget(
            name: "SnapSyncCoreTests",
            dependencies: ["SnapSyncCore"],
            resources: [.copy("Fixtures")]
        )
    ]
)
