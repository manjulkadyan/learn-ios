// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RuntimeLab",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "runtime-lab", targets: ["RuntimeLab"])],
    dependencies: [],
    targets: [.executableTarget(name: "RuntimeLab")],
    swiftLanguageModes: [.v6]
)
