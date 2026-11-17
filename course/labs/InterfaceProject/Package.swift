// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InterfaceProject",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "InterfaceCore", targets: ["InterfaceCore"])],
    targets: [
        .target(name: "InterfaceCore"),
        .testTarget(name: "InterfaceCoreTests", dependencies: ["InterfaceCore"])
    ]
)
