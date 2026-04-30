// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Horus",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "Horus", targets: ["Horus"]),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Horus",
            dependencies: [],
            path: "Sources/Horus"
        ),
    ]
)
