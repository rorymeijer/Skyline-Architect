// swift-tools-version: 6.0
// SkylineKit — platform-independent engine code for Skyline Architect.
// Rule: targets here import Foundation only (no SpriteKit/SwiftUI/CoreGraphics) so they
// build and test on macOS, iPadOS and Linux. See Documentation/ARCHITECTURE.md.
import PackageDescription

let package = Package(
    name: "SkylineKit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "SkylineCore", targets: ["SkylineCore"]),
        .library(name: "SkylineContent", targets: ["SkylineContent"]),
        .library(name: "SkylinePresentation", targets: ["SkylinePresentation"]),
        .executable(name: "skyline-snapshot", targets: ["SkylineSnapshot"]),
    ],
    targets: [
        .target(name: "SkylineCore"),
        .target(
            name: "SkylineContent",
            dependencies: ["SkylineCore"],
            resources: [.copy("Resources/Base")]
        ),
        .target(name: "SkylinePresentation", dependencies: ["SkylineCore"]),
        .executableTarget(
            name: "SkylineSnapshot",
            dependencies: ["SkylineCore", "SkylineContent", "SkylinePresentation"]
        ),
        .testTarget(name: "SkylineCoreTests", dependencies: ["SkylineCore"]),
        .testTarget(name: "SkylineContentTests", dependencies: ["SkylineContent"]),
        .testTarget(
            name: "SkylinePresentationTests",
            dependencies: ["SkylinePresentation", "SkylineContent"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
