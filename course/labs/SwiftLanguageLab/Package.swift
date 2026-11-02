// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftLanguageLab",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SwiftLanguageLab", targets: ["SwiftLanguageLab"]),
        .executable(name: "swift-workbench", targets: ["SwiftWorkbench"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "SwiftLanguageLab"),
        .executableTarget(name: "SwiftWorkbench", dependencies: ["SwiftLanguageLab"]),
        .testTarget(name: "SwiftLanguageLabTests", dependencies: ["SwiftLanguageLab"]),
    ],
    swiftLanguageModes: [.v6]
)
