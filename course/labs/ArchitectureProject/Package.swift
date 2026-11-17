// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ArchitectureProject",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ArchitectureKit", targets: ["AppShell", "NoteData"])
    ],
    targets: [
        .target(name: "NoteDomain"),
        .target(name: "NoteData", dependencies: ["NoteDomain"]),
        .target(name: "BrowseFeature", dependencies: ["NoteDomain"]),
        .target(name: "SavedFeature", dependencies: ["NoteDomain"]),
        .target(name: "AppShell", dependencies: ["NoteDomain", "NoteData", "BrowseFeature", "SavedFeature"]),
        .testTarget(name: "ArchitectureTests", dependencies: ["AppShell", "NoteData", "BrowseFeature", "SavedFeature", "NoteDomain"])
    ],
    swiftLanguageModes: [.v6]
)
