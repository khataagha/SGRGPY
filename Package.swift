// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SGRGPY",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "SGRGPY", targets: ["SGRGPY"])
    ],
    targets: [
        .executableTarget(name: "SGRGPY", path: "Sources/SGRGPY")
    ]
)
