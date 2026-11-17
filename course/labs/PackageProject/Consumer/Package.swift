// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CatalogConsumer",
    platforms: [.macOS(.v13), .iOS(.v17)],
    dependencies: [.package(path: "..")],
    targets: [.executableTarget(
        name: "CatalogConsumer",
        dependencies: [.product(name: "WorkshopKit", package: "PackageProject")]
    )]
)
