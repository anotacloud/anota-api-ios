// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AnotaApi",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(name: "AnotaApi", targets: ["AnotaApi"])
    ],
    targets: [
        .target(name: "AnotaApi"),
        .testTarget(name: "AnotaApiTests", dependencies: ["AnotaApi"])
    ]
)
