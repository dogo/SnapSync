import ProjectDescription

let project = Project(
    name: "SnapCompanion",
    options: .options(disableSynthesizedResourceAccessors: true),
    packages: [
        .local(path: "."),
        .remote(
            url: "https://github.com/onevcat/Kingfisher.git",
            requirement: .exact("8.11.0")
        ),
    ],
    targets: [
        .target(
            name: "SnapCompanionApp",
            destinations: .macOS,
            product: .app,
            bundleId: "br.com.anykey.SnapSync",
            deploymentTargets: .macOS("13.0"),
            infoPlist: .file(path: "Packaging/Info.plist"),
            sources: ["Sources/SnapCompanionApp/**"],
            resources: ["Sources/SnapCompanionApp/Resources/**"],
            dependencies: [
                .package(product: "SnapSyncCore"),
                .package(product: "Kingfisher"),
            ],
            settings: .settings(base: [
                "PRODUCT_NAME": "SnapCompanion",
                "STRING_CATALOG_GENERATE_SYMBOLS": "YES",
                "SWIFT_VERSION": "6.0",
            ])
        ),
    ]
)
