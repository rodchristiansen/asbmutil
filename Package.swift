// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "asbmutil",
    platforms: [ .macOS(.v14) ],
    products: [
        .executable(name: "asbmutil", targets: ["asbmutil"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "asbmutil",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/asbmutil"
        )
    ],
    swiftLanguageModes: [.v6]
)