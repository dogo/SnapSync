// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SnapSync",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "snapsync", targets: ["SnapSyncCLI"]),
        .executable(name: "SnapSyncApp", targets: ["SnapSyncApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.11.0")
    ],
    targets: [
        .target(name: "SnapSyncCore"),
        .executableTarget(name: "SnapSyncCLI", dependencies: ["SnapSyncCore"]),
        .executableTarget(
            name: "SnapSyncApp",
            dependencies: [
                "SnapSyncCore",
                .product(name: "Kingfisher", package: "Kingfisher"),
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "SnapSyncCoreTests",
            dependencies: ["SnapSyncCore"],
            resources: [.copy("Fixtures")]
        )
    ]
)
