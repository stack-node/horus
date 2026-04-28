// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Horus",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "Horus",
            path: "Sources/Horus"
        ),
    ]
)
