// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Mono",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Mono",
            path: "Sources/Mono",
            linkerSettings: [.linkedFramework("ServiceManagement")]
        )
    ]
)
