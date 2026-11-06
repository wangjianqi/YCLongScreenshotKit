// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YCLongScreenshotKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "YCLongScreenshotKit", targets: ["YCLongScreenshotKit"])
    ],
    targets: [
        .target(name: "YCLongScreenshotKit"),
        .testTarget(name: "YCLongScreenshotKitTests", dependencies: ["YCLongScreenshotKit"])
    ]
)
