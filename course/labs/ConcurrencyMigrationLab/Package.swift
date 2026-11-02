// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ConcurrencyMigrationLab",
    platforms: [.macOS(.v15)],
    products: [.library(name: "ConcurrencyMigrationLab", targets: ["ConcurrencyMigrationLab"])],
    targets: [
        .target(name: "ConcurrencyMigrationLab", swiftSettings: [.defaultIsolation(nil)]),
        .testTarget(name: "ConcurrencyMigrationLabTests", dependencies: ["ConcurrencyMigrationLab"],
                    swiftSettings: [.defaultIsolation(nil)])
    ],
    swiftLanguageModes: [.v6]
)
