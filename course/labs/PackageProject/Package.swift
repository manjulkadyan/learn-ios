// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PackageProject",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "WorkshopKit", targets: ["WorkshopKit"])],
    targets: [
        .target(name: "WorkshopKit", resources: [.process("Resources")]),
        .testTarget(name: "WorkshopKitTests", dependencies: ["WorkshopKit"])
    ]
)
