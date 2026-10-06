// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeyFind",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "KeyFindCore", targets: ["KeyFindCore"]),
        .executable(name: "KeyFindApp", targets: ["KeyFindApp"])
    ],
    targets: [
        .target(
            name: "KeyFindCore",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "KeyFindApp",
            dependencies: ["KeyFindCore"]
        ),
        .testTarget(
            name: "KeyFindCoreTests",
            dependencies: ["KeyFindCore"]
        )
    ]
)
