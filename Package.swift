// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "asbmutil",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "asbmutil", targets: ["ASBMUtilCLI"]),
        .executable(name: "ASBMUtilApp", targets: ["ASBMUtilApp"]),
        .library(name: "ASBMUtilCore", targets: ["ASBMUtilCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "ASBMUtilCore",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto",
                         condition: .when(platforms: [.linux])),
            ],
            path: "Sources/core"
        ),
        .executableTarget(
            name: "ASBMUtilCLI",
            dependencies: [
                "ASBMUtilCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/cli"
        ),
        .executableTarget(
            name: "ASBMUtilApp",
            dependencies: ["ASBMUtilCore"],
            path: "Sources/app"
        ),
    ],
    swiftLanguageModes: [.v6]
)
