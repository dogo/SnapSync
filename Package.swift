// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SnapSync",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "snapsync", targets: ["SnapSyncCLI"]),
        .executable(name: "SnapSyncApp", targets: ["SnapSyncApp"])
    ],
    targets: [
        .target(name: "SnapSyncCore"),
        .executableTarget(name: "SnapSyncCLI", dependencies: ["SnapSyncCore"]),
        .executableTarget(
            name: "SnapSyncApp",
            dependencies: ["SnapSyncCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "SnapSyncCoreTests",
            dependencies: ["SnapSyncCore"],
            resources: [.copy("Fixtures")]
        )
    ]
)
