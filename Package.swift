// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Acroromi",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Acroromi",
            path: "Sources/Acroromi"
        )
    ]
)
